import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class SQLiteSpendStorage: SpendStoring, SpendMaintenance {
    private let databaseURL: URL
    private var database: OpaquePointer?
    private let dateFormatter = ISO8601DateFormatter()
    private let accessLock = NSRecursiveLock()

    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try open()
        try prepare()
    }

    deinit {
        sqlite3_close(database)
    }

    public static func defaultDatabaseURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return directory
            .appendingPathComponent("TokenScope", isDirectory: true)
            .appendingPathComponent("TokenScope.sqlite3")
    }

    public func prepare() throws {
        try withAccessLock {
            try execute("""
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                applied_at TEXT NOT NULL
            );
            """)

            for migration in StorageSchemaMigrations.all {
                guard try !migrationApplied(version: migration.version) else {
                    continue
                }

                try transaction {
                    for statement in migration.statements {
                        try execute(statement)
                    }
                    try markMigrationApplied(migration)
                }
            }

            try ensureCompatibilityColumns()
        }
    }

    public func upsert(_ batch: NormalizedUsageBatch) throws {
        guard !batch.isEmpty else {
            return
        }

        try withAccessLock {
            try transaction {
                for session in batch.sessions {
                    try upsertProvider(session.provider)
                    try upsertModel(provider: session.provider, modelName: session.model)
                    try upsertProject(name: session.projectName, path: session.projectPath)
                    try upsertSession(session)
                }

                for usageEvent in batch.usageEvents {
                    try upsertUsageEvent(usageEvent)
                }

                for toolEvent in batch.toolEvents {
                    try upsertToolEvent(toolEvent)
                }
            }
        }
    }

    public func clearAllData() throws {
        try withAccessLock {
            try transaction {
                try execute("DELETE FROM tool_events;")
                try execute("DELETE FROM usage_events;")
                try execute("DELETE FROM sessions;")
                try execute("DELETE FROM source_files;")
                try execute("DELETE FROM models;")
                try execute("DELETE FROM projects;")
                try execute("DELETE FROM providers;")
            }
        }
    }

    public func storedSessions() throws -> [NormalizedSession] {
        try withAccessLock {
            let sql = """
            SELECT
                sessions.id,
                sessions.provider_id,
                COALESCE(models.name, 'unknown') AS model_name,
                projects.path,
                COALESCE(projects.name, 'unknown') AS project_name,
                sessions.session_id,
                sessions.start_time,
                sessions.end_time,
                sessions.duration_seconds,
                sessions.input_tokens,
                sessions.cache_creation_input_tokens,
                sessions.cache_read_input_tokens,
                sessions.output_tokens,
                sessions.total_tokens,
                sessions.estimated_cost,
                sessions.raw_source_path
            FROM sessions
            LEFT JOIN models ON models.id = sessions.model_id
            LEFT JOIN projects ON projects.id = sessions.project_id
            ORDER BY sessions.id ASC;
            """

            return try query(sql) { statement in
                guard let provider = Provider(rawValue: Self.columnText(statement, 1) ?? "") else {
                    throw SQLiteSpendStorageError.invalidProvider
                }

                return NormalizedSession(
                    id: Self.columnText(statement, 0) ?? "",
                    provider: provider,
                    model: Self.columnText(statement, 2) ?? "unknown",
                    projectPath: Self.columnText(statement, 3),
                    projectName: Self.columnText(statement, 4) ?? "unknown",
                    sessionId: Self.columnText(statement, 5) ?? "",
                    startTime: try date(from: Self.columnText(statement, 6)),
                    endTime: try optionalDate(from: Self.columnText(statement, 7)),
                    durationSeconds: Self.columnInt(statement, 8),
                    inputTokens: Self.columnInt(statement, 9),
                    cacheCreationInputTokens: Self.columnInt(statement, 10),
                    cacheReadInputTokens: Self.columnInt(statement, 11),
                    outputTokens: Self.columnInt(statement, 12),
                    totalTokens: Self.columnInt(statement, 13),
                    estimatedCost: Self.columnDecimal(statement, 14),
                    rawSourcePath: Self.columnText(statement, 15) ?? ""
                )
            }
        }
    }

    public func storedUsageEvents() throws -> [UsageEvent] {
        try withAccessLock {
            let sql = """
            SELECT id, session_id, timestamp, input_tokens, output_tokens, total_tokens, estimated_cost, raw_source_path
            FROM usage_events
            ORDER BY id ASC;
            """

            return try query(sql) { statement in
                UsageEvent(
                    id: Self.columnText(statement, 0) ?? "",
                    sessionId: Self.columnText(statement, 1) ?? "",
                    timestamp: try date(from: Self.columnText(statement, 2)),
                    inputTokens: Self.columnInt(statement, 3),
                    outputTokens: Self.columnInt(statement, 4),
                    totalTokens: Self.columnInt(statement, 5),
                    estimatedCost: Self.columnDecimal(statement, 6),
                    rawSourcePath: Self.columnText(statement, 7) ?? ""
                )
            }
        }
    }

    public func storedToolEvents() throws -> [ToolEvent] {
        try withAccessLock {
            let sql = """
            SELECT
                id,
                provider_id,
                session_id,
                timestamp,
                tool_name,
                target_path,
                command,
                working_directory,
                tool_call_id,
                exit_code,
                error_summary,
                raw_source_path
            FROM tool_events
            ORDER BY id ASC;
            """

            return try query(sql) { statement in
                guard let provider = Provider(rawValue: Self.columnText(statement, 1) ?? "") else {
                    throw SQLiteSpendStorageError.invalidProvider
                }

                return ToolEvent(
                    id: Self.columnText(statement, 0) ?? "",
                    provider: provider,
                    sessionId: Self.columnText(statement, 2) ?? "",
                    timestamp: try date(from: Self.columnText(statement, 3)),
                    toolName: Self.columnText(statement, 4) ?? "",
                    targetPath: Self.columnText(statement, 5),
                    command: Self.columnText(statement, 6),
                    workingDirectory: Self.columnText(statement, 7),
                    toolCallId: Self.columnText(statement, 8),
                    exitCode: Self.columnInt(statement, 9),
                    errorSummary: Self.columnText(statement, 10),
                    rawSourcePath: Self.columnText(statement, 11) ?? ""
                )
            }
        }
    }

    public func sourceFileState(provider: Provider, path: String) throws -> SourceFileIngestionState? {
        try withAccessLock {
            try query(
                """
                SELECT provider_id, path, modified_at, byte_size, content_hash, last_ingested_at
                FROM source_files
                WHERE provider_id = ? AND path = ?
                LIMIT 1;
                """,
                bindings: [.text(provider.rawValue), .text(path)],
                row: sourceFileState(from:)
            ).first
        }
    }

    public func upsertSourceFileState(_ state: SourceFileIngestionState) throws {
        try withAccessLock {
            try execute(
                """
                INSERT INTO source_files (
                    provider_id,
                    path,
                    modified_at,
                    byte_size,
                    content_hash,
                    last_ingested_at
                )
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(provider_id, path) DO UPDATE SET
                    modified_at = excluded.modified_at,
                    byte_size = excluded.byte_size,
                    content_hash = excluded.content_hash,
                    last_ingested_at = excluded.last_ingested_at;
                """,
                bindings: [
                    .text(state.provider.rawValue),
                    .text(state.path),
                    .optionalText(state.metadata.modifiedAt.map(dateFormatter.string)),
                    .optionalInt(state.metadata.byteSize),
                    .text(state.contentHash),
                    .text(dateFormatter.string(from: state.lastIngestedAt))
                ]
            )
        }
    }

    public func storedSourceFileStates() throws -> [SourceFileIngestionState] {
        try withAccessLock {
            try query(
                """
                SELECT provider_id, path, modified_at, byte_size, content_hash, last_ingested_at
                FROM source_files
                ORDER BY provider_id ASC, path ASC;
                """,
                row: sourceFileState(from:)
            )
        }
    }

    private func withAccessLock<Value>(_ body: () throws -> Value) rethrows -> Value {
        accessLock.lock()
        defer { accessLock.unlock() }
        return try body()
    }

    private func open() throws {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &database, flags, nil) == SQLITE_OK else {
            throw SQLiteSpendStorageError.openFailed(message: lastErrorMessage)
        }
    }

    private func migrationApplied(version: Int) throws -> Bool {
        let sql = "SELECT 1 FROM schema_migrations WHERE version = ? LIMIT 1;"
        return try query(sql, bindings: [.int(version)]) { _ in true }.first ?? false
    }

    private func markMigrationApplied(_ migration: StorageSchemaMigration) throws {
        try execute(
            "INSERT INTO schema_migrations (version, name, applied_at) VALUES (?, ?, ?);",
            bindings: [
                .int(migration.version),
                .text(migration.name),
                .text(dateFormatter.string(from: Date()))
            ]
        )
    }

    private func ensureCompatibilityColumns() throws {
        try ensureColumn(
            tableName: "sessions",
            columnName: "cache_creation_input_tokens",
            definition: "cache_creation_input_tokens INTEGER"
        )
        try ensureColumn(
            tableName: "sessions",
            columnName: "cache_read_input_tokens",
            definition: "cache_read_input_tokens INTEGER"
        )
    }

    private func ensureColumn(tableName: String, columnName: String, definition: String) throws {
        guard try !columns(in: tableName).contains(columnName) else {
            return
        }

        try execute("ALTER TABLE \(tableName) ADD COLUMN \(definition);")
    }

    private func columns(in tableName: String) throws -> Set<String> {
        let rows = try query("PRAGMA table_info(\(tableName));") { statement in
            Self.columnText(statement, 1) ?? ""
        }

        return Set(rows)
    }

    private func upsertProvider(_ provider: Provider) throws {
        try execute(
            """
            INSERT INTO providers (id, name)
            VALUES (?, ?)
            ON CONFLICT(id) DO UPDATE SET name = excluded.name;
            """,
            bindings: [.text(provider.rawValue), .text(provider.displayName)]
        )
    }

    private func upsertModel(provider: Provider, modelName: String) throws {
        try execute(
            """
            INSERT INTO models (id, provider_id, name)
            VALUES (?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                provider_id = excluded.provider_id,
                name = excluded.name;
            """,
            bindings: [.text(modelID(provider: provider, modelName: modelName)), .text(provider.rawValue), .text(modelName)]
        )
    }

    private func upsertProject(name: String, path: String?) throws {
        try execute(
            """
            INSERT INTO projects (id, name, path)
            VALUES (?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                path = excluded.path;
            """,
            bindings: [.text(projectID(name: name, path: path)), .text(name), .optionalText(path)]
        )
    }

    private func upsertSession(_ session: NormalizedSession) throws {
        try execute(
            """
            INSERT INTO sessions (
                id,
                provider_id,
                model_id,
                project_id,
                session_id,
                start_time,
                end_time,
                duration_seconds,
                input_tokens,
                cache_creation_input_tokens,
                cache_read_input_tokens,
                output_tokens,
                total_tokens,
                estimated_cost,
                raw_source_path
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                provider_id = excluded.provider_id,
                model_id = excluded.model_id,
                project_id = excluded.project_id,
                session_id = excluded.session_id,
                start_time = excluded.start_time,
                end_time = excluded.end_time,
                duration_seconds = excluded.duration_seconds,
                input_tokens = excluded.input_tokens,
                cache_creation_input_tokens = excluded.cache_creation_input_tokens,
                cache_read_input_tokens = excluded.cache_read_input_tokens,
                output_tokens = excluded.output_tokens,
                total_tokens = excluded.total_tokens,
                estimated_cost = excluded.estimated_cost,
                raw_source_path = excluded.raw_source_path;
            """,
            bindings: [
                .text(session.id),
                .text(session.provider.rawValue),
                .text(modelID(provider: session.provider, modelName: session.model)),
                .text(projectID(name: session.projectName, path: session.projectPath)),
                .text(session.sessionId),
                .text(dateFormatter.string(from: session.startTime)),
                .optionalText(session.endTime.map(dateFormatter.string)),
                .optionalInt(session.durationSeconds),
                .optionalInt(session.inputTokens),
                .optionalInt(session.cacheCreationInputTokens),
                .optionalInt(session.cacheReadInputTokens),
                .optionalInt(session.outputTokens),
                .optionalInt(session.totalTokens),
                .optionalDecimal(session.estimatedCost),
                .text(session.rawSourcePath)
            ]
        )
    }

    private func upsertUsageEvent(_ usageEvent: UsageEvent) throws {
        try execute(
            """
            INSERT INTO usage_events (
                id,
                session_id,
                timestamp,
                input_tokens,
                output_tokens,
                total_tokens,
                estimated_cost,
                raw_source_path
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                session_id = excluded.session_id,
                timestamp = excluded.timestamp,
                input_tokens = excluded.input_tokens,
                output_tokens = excluded.output_tokens,
                total_tokens = excluded.total_tokens,
                estimated_cost = excluded.estimated_cost,
                raw_source_path = excluded.raw_source_path;
            """,
            bindings: [
                .text(usageEvent.id),
                .text(usageEvent.sessionId),
                .text(dateFormatter.string(from: usageEvent.timestamp)),
                .optionalInt(usageEvent.inputTokens),
                .optionalInt(usageEvent.outputTokens),
                .optionalInt(usageEvent.totalTokens),
                .optionalDecimal(usageEvent.estimatedCost),
                .text(usageEvent.rawSourcePath)
            ]
        )
    }

    private func upsertToolEvent(_ toolEvent: ToolEvent) throws {
        try execute(
            """
            INSERT INTO tool_events (
                id,
                provider_id,
                session_id,
                timestamp,
                tool_name,
                target_path,
                command,
                working_directory,
                tool_call_id,
                exit_code,
                error_summary,
                raw_source_path
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                provider_id = excluded.provider_id,
                session_id = excluded.session_id,
                timestamp = excluded.timestamp,
                tool_name = excluded.tool_name,
                target_path = excluded.target_path,
                command = excluded.command,
                working_directory = excluded.working_directory,
                tool_call_id = excluded.tool_call_id,
                exit_code = excluded.exit_code,
                error_summary = excluded.error_summary,
                raw_source_path = excluded.raw_source_path;
            """,
            bindings: [
                .text(toolEvent.id),
                .text(toolEvent.provider.rawValue),
                .text(toolEvent.sessionId),
                .text(dateFormatter.string(from: toolEvent.timestamp)),
                .text(toolEvent.toolName),
                .optionalText(toolEvent.targetPath),
                .optionalText(toolEvent.command),
                .optionalText(toolEvent.workingDirectory),
                .optionalText(toolEvent.toolCallId),
                .optionalInt(toolEvent.exitCode),
                .optionalText(toolEvent.errorSummary),
                .text(toolEvent.rawSourcePath)
            ]
        )
    }

    private func sourceFileState(from statement: OpaquePointer?) throws -> SourceFileIngestionState {
        guard let provider = Provider(rawValue: Self.columnText(statement, 0) ?? "") else {
            throw SQLiteSpendStorageError.invalidProvider
        }

        return SourceFileIngestionState(
            provider: provider,
            path: Self.columnText(statement, 1) ?? "",
            metadata: SourceFileMetadata(
                modifiedAt: try optionalDate(from: Self.columnText(statement, 2)),
                byteSize: Self.columnInt(statement, 3)
            ),
            contentHash: Self.columnText(statement, 4) ?? "",
            lastIngestedAt: try date(from: Self.columnText(statement, 5))
        )
    }

    private func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE;")
        do {
            try body()
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    private func execute(_ sql: String, bindings: [SQLiteBinding] = []) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteSpendStorageError.prepareFailed(message: lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteSpendStorageError.stepFailed(message: lastErrorMessage)
        }
    }

    private func query<Value>(
        _ sql: String,
        bindings: [SQLiteBinding] = [],
        row: (OpaquePointer?) throws -> Value
    ) throws -> [Value] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteSpendStorageError.prepareFailed(message: lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement)

        var values: [Value] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                values.append(try row(statement))
            } else if result == SQLITE_DONE {
                return values
            } else {
                throw SQLiteSpendStorageError.stepFailed(message: lastErrorMessage)
            }
        }
    }

    private func bind(_ bindings: [SQLiteBinding], to statement: OpaquePointer?) throws {
        for (index, binding) in bindings.enumerated() {
            let position = Int32(index + 1)
            let result: Int32

            switch binding {
            case .null:
                result = sqlite3_bind_null(statement, position)
            case .int(let value):
                result = sqlite3_bind_int64(statement, position, sqlite3_int64(value))
            case .text(let value):
                result = sqlite3_bind_text(statement, position, value, -1, SQLITE_TRANSIENT)
            }

            guard result == SQLITE_OK else {
                throw SQLiteSpendStorageError.bindFailed(message: lastErrorMessage)
            }
        }
    }

    private func modelID(provider: Provider, modelName: String) -> String {
        "\(provider.rawValue):\(modelName)"
    }

    private func projectID(name: String, path: String?) -> String {
        path ?? "project:\(name)"
    }

    private func date(from value: String?) throws -> Date {
        guard let date = try optionalDate(from: value) else {
            throw SQLiteSpendStorageError.invalidDate
        }

        return date
    }

    private func optionalDate(from value: String?) throws -> Date? {
        guard let value else {
            return nil
        }

        if let date = dateFormatter.date(from: value) {
            return date
        }

        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        guard let date = fallbackFormatter.date(from: value) else {
            throw SQLiteSpendStorageError.invalidDate
        }

        return date
    }

    private var lastErrorMessage: String {
        guard let message = sqlite3_errmsg(database) else {
            return "Unknown SQLite error"
        }

        return String(cString: message)
    }

    private static func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let text = sqlite3_column_text(statement, index) else {
            return nil
        }

        return String(cString: text)
    }

    private static func columnInt(_ statement: OpaquePointer?, _ index: Int32) -> Int? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }

        return Int(sqlite3_column_int64(statement, index))
    }

    private static func columnDecimal(_ statement: OpaquePointer?, _ index: Int32) -> Decimal? {
        guard let text = columnText(statement, index) else {
            return nil
        }

        return Decimal(string: text)
    }
}

extension SQLiteSpendStorage: SourceFileIngestionIndex {}

extension SQLiteSpendStorage: MenuBarSessionReading {
    func menuBarSessions() throws -> [NormalizedSession] {
        try storedSessions()
    }
}

extension SQLiteSpendStorage: PopoverSessionReading {
    func popoverSessions() throws -> [NormalizedSession] {
        try storedSessions()
    }
}

extension SQLiteSpendStorage: PopoverToolEventReading {
    func popoverToolEvents() throws -> [ToolEvent] {
        try storedToolEvents()
    }
}

private enum SQLiteBinding {
    case null
    case int(Int)
    case text(String)

    static func optionalInt(_ value: Int?) -> SQLiteBinding {
        value.map(SQLiteBinding.int) ?? .null
    }

    static func optionalText(_ value: String?) -> SQLiteBinding {
        value.map(SQLiteBinding.text) ?? .null
    }

    static func optionalDecimal(_ value: Decimal?) -> SQLiteBinding {
        guard let value else {
            return .null
        }

        return .text(NSDecimalNumber(decimal: value).stringValue)
    }
}

private enum SQLiteSpendStorageError: Error {
    case openFailed(message: String)
    case prepareFailed(message: String)
    case bindFailed(message: String)
    case stepFailed(message: String)
    case invalidDate
    case invalidProvider
}
