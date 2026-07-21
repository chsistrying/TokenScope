import XCTest
import SQLite3
@testable import TokenScope

final class StorageTests: XCTestCase {
    func testInMemoryStorageAcceptsEmptyInput() throws {
        let storage = InMemorySpendStorage()

        XCTAssertNoThrow(try storage.prepare())
        XCTAssertNoThrow(try storage.save(sessions: [], usageEvents: []))
    }

    func testInMemoryStorageUpsertsNormalizedRecordsByID() throws {
        let storage = InMemorySpendStorage()
        try storage.prepare()

        let originalSession = makeSession(id: "session-1", totalTokens: 100)
        let replacementSession = makeSession(id: "session-1", totalTokens: 125)
        let otherSession = makeSession(id: "session-2", totalTokens: 20)
        let originalEvent = makeUsageEvent(id: "event-1", totalTokens: 75)
        let replacementEvent = makeUsageEvent(id: "event-1", totalTokens: 90)
        let originalToolEvent = makeToolEvent(id: "tool-1", targetPath: "/tmp/original.swift")
        let replacementToolEvent = makeToolEvent(
            id: "tool-1",
            targetPath: "/tmp/replacement.swift",
            command: "npm test",
            exitCode: 1,
            errorSummary: "No tests found"
        )

        try storage.upsert(NormalizedUsageBatch(
            sessions: [originalSession, otherSession],
            usageEvents: [originalEvent],
            toolEvents: [originalToolEvent]
        ))
        try storage.upsert(NormalizedUsageBatch(
            sessions: [replacementSession],
            usageEvents: [replacementEvent],
            toolEvents: [replacementToolEvent]
        ))

        XCTAssertEqual(storage.storedSessions(), [replacementSession, otherSession])
        XCTAssertEqual(storage.storedUsageEvents(), [replacementEvent])
        XCTAssertEqual(storage.storedToolEvents(), [replacementToolEvent])
    }

    func testPrepareClearsInMemoryStorage() throws {
        let storage = InMemorySpendStorage()

        try storage.upsert(NormalizedUsageBatch(
            sessions: [makeSession(id: "session-1")],
            usageEvents: [makeUsageEvent(id: "event-1")],
            toolEvents: [makeToolEvent(id: "tool-1")]
        ))
        try storage.prepare()

        XCTAssertEqual(storage.storedSessions(), [])
        XCTAssertEqual(storage.storedUsageEvents(), [])
        XCTAssertEqual(storage.storedToolEvents(), [])
    }

    func testSQLiteStorageUpsertsAndReadsNormalizedRecordsByID() throws {
        let storage = try SQLiteSpendStorage(databaseURL: temporaryDatabaseURL())
        let originalSession = makeSession(id: "session-1", totalTokens: 100)
        let replacementSession = makeSession(
            id: "session-1",
            totalTokens: 125,
            cacheCreationInputTokens: 20,
            cacheReadInputTokens: 30,
            estimatedCost: Decimal(string: "0.1234")
        )
        let otherSession = makeSession(id: "session-2", totalTokens: 20)
        let originalEvent = makeUsageEvent(id: "event-1", totalTokens: 75)
        let replacementEvent = makeUsageEvent(id: "event-1", totalTokens: 90)
        let originalToolEvent = makeToolEvent(id: "tool-1", targetPath: "/tmp/original.swift")
        let replacementToolEvent = makeToolEvent(
            id: "tool-1",
            targetPath: "/tmp/replacement.swift",
            command: "npm test",
            exitCode: 1,
            errorSummary: "No tests found"
        )

        try storage.upsert(NormalizedUsageBatch(
            sessions: [originalSession, otherSession],
            usageEvents: [originalEvent],
            toolEvents: [originalToolEvent]
        ))
        try storage.upsert(NormalizedUsageBatch(
            sessions: [replacementSession],
            usageEvents: [replacementEvent],
            toolEvents: [replacementToolEvent]
        ))

        XCTAssertEqual(try storage.storedSessions(), [replacementSession, otherSession])
        XCTAssertEqual(try storage.storedUsageEvents(), [replacementEvent])
        XCTAssertEqual(try storage.storedToolEvents(), [replacementToolEvent])
    }

    func testSQLiteStoragePersistsAcrossInstances() throws {
        let databaseURL = temporaryDatabaseURL()
        let session = makeSession(id: "session-1", totalTokens: 100)

        do {
            let storage = try SQLiteSpendStorage(databaseURL: databaseURL)
            try storage.upsert(NormalizedUsageBatch(sessions: [session]))
        }

        let reopenedStorage = try SQLiteSpendStorage(databaseURL: databaseURL)

        XCTAssertEqual(try reopenedStorage.storedSessions(), [session])
    }

    func testSQLiteStoragePersistsSourceFileIngestionState() throws {
        let databaseURL = temporaryDatabaseURL()
        let state = SourceFileIngestionState(
            provider: .claude,
            path: "/Users/example/.claude/projects/session.jsonl",
            metadata: SourceFileMetadata(
                modifiedAt: Date(timeIntervalSince1970: 1_800_000_000),
                byteSize: 123
            ),
            contentHash: "abc123",
            lastIngestedAt: Date(timeIntervalSince1970: 1_800_000_060)
        )

        do {
            let storage = try SQLiteSpendStorage(databaseURL: databaseURL)
            try storage.upsertSourceFileState(state)
        }

        let reopenedStorage = try SQLiteSpendStorage(databaseURL: databaseURL)

        XCTAssertEqual(
            try reopenedStorage.sourceFileState(provider: state.provider, path: state.path),
            state
        )
        XCTAssertEqual(try reopenedStorage.storedSourceFileStates(), [state])
    }

    func testSQLiteStorageRepairsLegacySessionCacheColumns() throws {
        let databaseURL = temporaryDatabaseURL()
        try createLegacyDatabaseWithoutCacheColumns(at: databaseURL)

        let reopenedStorage = try SQLiteSpendStorage(databaseURL: databaseURL)
        let session = makeSession(
            id: "session-1",
            totalTokens: 100,
            cacheCreationInputTokens: 20,
            cacheReadInputTokens: 30
        )

        try reopenedStorage.upsert(NormalizedUsageBatch(sessions: [session]))

        XCTAssertEqual(try reopenedStorage.storedSessions(), [session])
    }

    func testToolEventMigrationClearsSourceFileIndexForReingestion() throws {
        let databaseURL = temporaryDatabaseURL()
        try createVersionTwoDatabaseWithSourceFileIndex(at: databaseURL)

        let reopenedStorage = try SQLiteSpendStorage(databaseURL: databaseURL)

        XCTAssertEqual(try reopenedStorage.storedSourceFileStates(), [])
        XCTAssertEqual(try reopenedStorage.storedToolEvents(), [])
    }

    func testToolEventWorkingDirectoryMigrationClearsOldToolEventsForReingestion() throws {
        let databaseURL = temporaryDatabaseURL()
        try createVersionThreeDatabaseWithToolEvents(at: databaseURL)

        let reopenedStorage = try SQLiteSpendStorage(databaseURL: databaseURL)

        XCTAssertEqual(try reopenedStorage.storedToolEvents(), [])
        XCTAssertEqual(try reopenedStorage.storedSourceFileStates(), [])
    }

    func testToolEventFailureMigrationClearsOldToolEventsForReingestion() throws {
        let databaseURL = temporaryDatabaseURL()
        try createVersionFourDatabaseWithToolEvents(at: databaseURL)

        let reopenedStorage = try SQLiteSpendStorage(databaseURL: databaseURL)

        XCTAssertEqual(try reopenedStorage.storedToolEvents(), [])
        XCTAssertEqual(try reopenedStorage.storedSourceFileStates(), [])
    }

    func testSQLiteStorageClearsLocalDataAndKeepsSchemaUsable() throws {
        let storage = try SQLiteSpendStorage(databaseURL: temporaryDatabaseURL())
        let session = makeSession(id: "session-1", totalTokens: 100)
        let event = makeUsageEvent(id: "event-1", totalTokens: 75)
        let toolEvent = makeToolEvent(id: "tool-1")
        let state = SourceFileIngestionState(
            provider: .claude,
            path: "/Users/example/.claude/projects/session.jsonl",
            metadata: SourceFileMetadata(
                modifiedAt: Date(timeIntervalSince1970: 1_800_000_000),
                byteSize: 123
            ),
            contentHash: "abc123",
            lastIngestedAt: Date(timeIntervalSince1970: 1_800_000_060)
        )

        try storage.upsert(NormalizedUsageBatch(sessions: [session], usageEvents: [event], toolEvents: [toolEvent]))
        try storage.upsertSourceFileState(state)
        try storage.clearAllData()

        XCTAssertEqual(try storage.storedSessions(), [])
        XCTAssertEqual(try storage.storedUsageEvents(), [])
        XCTAssertEqual(try storage.storedToolEvents(), [])
        XCTAssertEqual(try storage.storedSourceFileStates(), [])

        try storage.upsert(NormalizedUsageBatch(sessions: [session]))

        XCTAssertEqual(try storage.storedSessions(), [session])
    }

    func testInitialSchemaMigrationIsDiscoverableAndAlignedWithNormalizedTables() {
        XCTAssertEqual(StorageSchemaMigrations.all.map(\.version), [1, 2, 3, 4, 5])

        let migration = StorageSchemaMigrations.initialSchema
        let sql = migration.statements.joined(separator: "\n")

        XCTAssertEqual(migration.name, "initial_normalized_usage_schema")
        XCTAssertTrue(sql.contains("CREATE TABLE IF NOT EXISTS providers"))
        XCTAssertTrue(sql.contains("CREATE TABLE IF NOT EXISTS models"))
        XCTAssertTrue(sql.contains("CREATE TABLE IF NOT EXISTS projects"))
        XCTAssertTrue(sql.contains("CREATE TABLE IF NOT EXISTS sessions"))
        XCTAssertTrue(sql.contains("CREATE TABLE IF NOT EXISTS usage_events"))
        XCTAssertTrue(sql.contains("provider_id TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("cache_creation_input_tokens INTEGER"))
        XCTAssertTrue(sql.contains("cache_read_input_tokens INTEGER"))
        XCTAssertTrue(sql.contains("raw_source_path TEXT NOT NULL"))

        let sourceFileSQL = StorageSchemaMigrations.sourceFileIngestionIndex.statements.joined(separator: "\n")
        XCTAssertTrue(sourceFileSQL.contains("CREATE TABLE IF NOT EXISTS source_files"))
        XCTAssertTrue(sourceFileSQL.contains("content_hash TEXT NOT NULL"))
        XCTAssertTrue(sourceFileSQL.contains("PRIMARY KEY (provider_id, path)"))

        let toolEventSQL = StorageSchemaMigrations.toolEvents.statements.joined(separator: "\n")
        XCTAssertTrue(toolEventSQL.contains("CREATE TABLE IF NOT EXISTS tool_events"))
        XCTAssertTrue(toolEventSQL.contains("tool_name TEXT NOT NULL"))
        XCTAssertTrue(toolEventSQL.contains("target_path TEXT"))
        XCTAssertTrue(toolEventSQL.contains("command TEXT"))
        XCTAssertTrue(toolEventSQL.contains("DELETE FROM source_files"))

        let toolEventWorkingDirectorySQL = StorageSchemaMigrations.toolEventWorkingDirectory.statements.joined(separator: "\n")
        XCTAssertTrue(toolEventWorkingDirectorySQL.contains("ALTER TABLE tool_events ADD COLUMN working_directory TEXT"))
        XCTAssertTrue(toolEventWorkingDirectorySQL.contains("DELETE FROM tool_events"))
        XCTAssertTrue(toolEventWorkingDirectorySQL.contains("DELETE FROM source_files"))

        let toolEventFailureSQL = StorageSchemaMigrations.toolEventFailures.statements.joined(separator: "\n")
        XCTAssertTrue(toolEventFailureSQL.contains("ALTER TABLE tool_events ADD COLUMN tool_call_id TEXT"))
        XCTAssertTrue(toolEventFailureSQL.contains("ALTER TABLE tool_events ADD COLUMN exit_code INTEGER"))
        XCTAssertTrue(toolEventFailureSQL.contains("ALTER TABLE tool_events ADD COLUMN error_summary TEXT"))
        XCTAssertTrue(toolEventFailureSQL.contains("DELETE FROM tool_events"))
        XCTAssertTrue(toolEventFailureSQL.contains("DELETE FROM source_files"))
    }

    func testUsageBatchReportsEmptyState() {
        XCTAssertTrue(NormalizedUsageBatch().isEmpty)
        XCTAssertFalse(NormalizedUsageBatch(sessions: [makeSession(id: "session-1")]).isEmpty)
        XCTAssertFalse(NormalizedUsageBatch(usageEvents: [makeUsageEvent(id: "event-1")]).isEmpty)
        XCTAssertFalse(NormalizedUsageBatch(toolEvents: [makeToolEvent(id: "tool-1")]).isEmpty)
    }

    private func makeSession(
        id: String,
        totalTokens: Int? = nil,
        cacheCreationInputTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil,
        estimatedCost: Decimal? = nil
    ) -> NormalizedSession {
        NormalizedSession(
            id: id,
            provider: .claude,
            model: "claude-test-model",
            projectPath: "/Users/example/project",
            projectName: "project",
            sessionId: "provider-\(id)",
            startTime: Date(timeIntervalSince1970: 1_725_000_000),
            endTime: nil,
            durationSeconds: nil,
            inputTokens: nil,
            cacheCreationInputTokens: cacheCreationInputTokens,
            cacheReadInputTokens: cacheReadInputTokens,
            outputTokens: nil,
            totalTokens: totalTokens,
            estimatedCost: estimatedCost,
            rawSourcePath: "/Users/example/.claude/log.jsonl"
        )
    }

    private func makeUsageEvent(id: String, totalTokens: Int? = nil) -> UsageEvent {
        UsageEvent(
            id: id,
            sessionId: "session-1",
            timestamp: Date(timeIntervalSince1970: 1_725_000_060),
            inputTokens: nil,
            outputTokens: nil,
            totalTokens: totalTokens,
            estimatedCost: nil,
            rawSourcePath: "/Users/example/.claude/log.jsonl"
        )
    }

    private func makeToolEvent(
        id: String,
        targetPath: String? = "/Users/example/project/App.swift",
        command: String? = nil,
        exitCode: Int? = nil,
        errorSummary: String? = nil
    ) -> ToolEvent {
        ToolEvent(
            id: id,
            provider: .claude,
            sessionId: "provider-session-1",
            timestamp: Date(timeIntervalSince1970: 1_725_000_070),
            toolName: "Read",
            targetPath: targetPath,
            command: command,
            exitCode: exitCode,
            errorSummary: errorSummary,
            rawSourcePath: "/Users/example/.claude/log.jsonl"
        )
    }

    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("TokenScopeTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("TokenScope.sqlite3")
    }

    private func createLegacyDatabaseWithoutCacheColumns(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(url.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil), SQLITE_OK)
        defer { sqlite3_close(database) }

        for statement in legacySchemaStatements {
            XCTAssertEqual(sqlite3_exec(database, statement, nil, nil, nil), SQLITE_OK)
        }
    }

    private func createVersionTwoDatabaseWithSourceFileIndex(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(url.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil), SQLITE_OK)
        defer { sqlite3_close(database) }

        let statements = [
            """
            CREATE TABLE schema_migrations (
                version INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                applied_at TEXT NOT NULL
            );
            """,
            """
            INSERT INTO schema_migrations (version, name, applied_at)
            VALUES
                (1, 'initial_normalized_usage_schema', '2026-07-10T00:00:00.000Z'),
                (2, 'source_file_ingestion_index', '2026-07-10T00:00:00.000Z');
            """,
        ] + StorageSchemaMigrations.initialSchema.statements
            + StorageSchemaMigrations.sourceFileIngestionIndex.statements
            + [
                """
                INSERT INTO source_files (
                    provider_id,
                    path,
                    modified_at,
                    byte_size,
                    content_hash,
                    last_ingested_at
                )
                VALUES (
                    'claude',
                    '/Users/example/.claude/projects/session.jsonl',
                    '2026-07-10T00:00:00.000Z',
                    123,
                    'old-hash',
                    '2026-07-10T00:00:01.000Z'
                );
                """
            ]

        for statement in statements {
            XCTAssertEqual(sqlite3_exec(database, statement, nil, nil, nil), SQLITE_OK)
        }
    }

    private func createVersionThreeDatabaseWithToolEvents(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(url.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil), SQLITE_OK)
        defer { sqlite3_close(database) }

        let statements = [
            """
            CREATE TABLE schema_migrations (
                version INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                applied_at TEXT NOT NULL
            );
            """,
            """
            INSERT INTO schema_migrations (version, name, applied_at)
            VALUES
                (1, 'initial_normalized_usage_schema', '2026-07-10T00:00:00.000Z'),
                (2, 'source_file_ingestion_index', '2026-07-10T00:00:00.000Z'),
                (3, 'tool_events', '2026-07-10T00:00:00.000Z');
            """,
        ] + StorageSchemaMigrations.initialSchema.statements
            + StorageSchemaMigrations.sourceFileIngestionIndex.statements
            + StorageSchemaMigrations.toolEvents.statements
            + [
                """
                INSERT INTO source_files (
                    provider_id,
                    path,
                    modified_at,
                    byte_size,
                    content_hash,
                    last_ingested_at
                )
                VALUES (
                    'claude',
                    '/Users/example/.claude/projects/session.jsonl',
                    '2026-07-10T00:00:00.000Z',
                    123,
                    'old-hash',
                    '2026-07-10T00:00:01.000Z'
                );
                """,
                """
                INSERT INTO tool_events (
                    id,
                    provider_id,
                    session_id,
                    timestamp,
                    tool_name,
                    target_path,
                    command,
                    raw_source_path
                )
                VALUES (
                    'tool-1',
                    'claude',
                    'session-1',
                    '2026-07-10T00:00:00.000Z',
                    'Read',
                    '/Users/example/project/App.swift',
                    NULL,
                    '/Users/example/.claude/projects/session.jsonl'
                );
                """
            ]

        for statement in statements {
            XCTAssertEqual(sqlite3_exec(database, statement, nil, nil, nil), SQLITE_OK)
        }
    }

    private func createVersionFourDatabaseWithToolEvents(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(url.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil), SQLITE_OK)
        defer { sqlite3_close(database) }

        let statements = [
            """
            CREATE TABLE schema_migrations (
                version INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                applied_at TEXT NOT NULL
            );
            """,
            """
            INSERT INTO schema_migrations (version, name, applied_at)
            VALUES
                (1, 'initial_normalized_usage_schema', '2026-07-10T00:00:00.000Z'),
                (2, 'source_file_ingestion_index', '2026-07-10T00:00:00.000Z'),
                (3, 'tool_events', '2026-07-10T00:00:00.000Z'),
                (4, 'tool_event_working_directory', '2026-07-10T00:00:00.000Z');
            """,
        ] + StorageSchemaMigrations.initialSchema.statements
            + StorageSchemaMigrations.sourceFileIngestionIndex.statements
            + StorageSchemaMigrations.toolEvents.statements
            + [
                "ALTER TABLE tool_events ADD COLUMN working_directory TEXT;",
                """
                INSERT INTO source_files (
                    provider_id,
                    path,
                    modified_at,
                    byte_size,
                    content_hash,
                    last_ingested_at
                )
                VALUES (
                    'claude',
                    '/Users/example/.claude/projects/session.jsonl',
                    '2026-07-10T00:00:00.000Z',
                    123,
                    'old-hash',
                    '2026-07-10T00:00:01.000Z'
                );
                """,
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
                    raw_source_path
                )
                VALUES (
                    'tool-1',
                    'claude',
                    'session-1',
                    '2026-07-10T00:00:00.000Z',
                    'Bash',
                    NULL,
                    'npm test',
                    '/Users/example/project',
                    '/Users/example/.claude/projects/session.jsonl'
                );
                """
            ]

        for statement in statements {
            XCTAssertEqual(sqlite3_exec(database, statement, nil, nil, nil), SQLITE_OK)
        }
    }

    private var legacySchemaStatements: [String] {
        [
            """
            CREATE TABLE schema_migrations (
                version INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                applied_at TEXT NOT NULL
            );
            """,
            """
            INSERT INTO schema_migrations (version, name, applied_at)
            VALUES (1, 'initial_normalized_usage_schema', '2026-07-10T00:00:00.000Z');
            """,
            """
            CREATE TABLE providers (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL
            );
            """,
            """
            CREATE TABLE models (
                id TEXT PRIMARY KEY,
                provider_id TEXT NOT NULL,
                name TEXT NOT NULL
            );
            """,
            """
            CREATE TABLE projects (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                path TEXT
            );
            """,
            """
            CREATE TABLE sessions (
                id TEXT PRIMARY KEY,
                provider_id TEXT NOT NULL,
                model_id TEXT,
                project_id TEXT,
                session_id TEXT NOT NULL,
                start_time TEXT NOT NULL,
                end_time TEXT,
                duration_seconds INTEGER,
                input_tokens INTEGER,
                output_tokens INTEGER,
                total_tokens INTEGER,
                estimated_cost REAL,
                raw_source_path TEXT NOT NULL
            );
            """,
            """
            CREATE TABLE usage_events (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                input_tokens INTEGER,
                output_tokens INTEGER,
                total_tokens INTEGER,
                estimated_cost REAL,
                raw_source_path TEXT NOT NULL
            );
            """
        ]
    }
}
