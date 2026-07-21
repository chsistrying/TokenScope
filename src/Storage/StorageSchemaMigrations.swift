import Foundation

public struct StorageSchemaMigration: Equatable, Sendable {
    public var version: Int
    public var name: String
    public var statements: [String]

    public init(version: Int, name: String, statements: [String]) {
        self.version = version
        self.name = name
        self.statements = statements
    }
}

public enum StorageSchemaMigrations {
    public static let all: [StorageSchemaMigration] = [
        initialSchema,
        sourceFileIngestionIndex,
        toolEvents,
        toolEventWorkingDirectory,
        toolEventFailures
    ]

    public static let initialSchema = StorageSchemaMigration(
        version: 1,
        name: "initial_normalized_usage_schema",
        statements: [
            """
            CREATE TABLE IF NOT EXISTS providers (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS models (
                id TEXT PRIMARY KEY,
                provider_id TEXT NOT NULL,
                name TEXT NOT NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS projects (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                path TEXT
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                provider_id TEXT NOT NULL,
                model_id TEXT,
                project_id TEXT,
                session_id TEXT NOT NULL,
                start_time TEXT NOT NULL,
                end_time TEXT,
                duration_seconds INTEGER,
                input_tokens INTEGER,
                cache_creation_input_tokens INTEGER,
                cache_read_input_tokens INTEGER,
                output_tokens INTEGER,
                total_tokens INTEGER,
                estimated_cost REAL,
                raw_source_path TEXT NOT NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS usage_events (
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
    )

    public static let sourceFileIngestionIndex = StorageSchemaMigration(
        version: 2,
        name: "source_file_ingestion_index",
        statements: [
            """
            CREATE TABLE IF NOT EXISTS source_files (
                provider_id TEXT NOT NULL,
                path TEXT NOT NULL,
                modified_at TEXT,
                byte_size INTEGER,
                content_hash TEXT NOT NULL,
                last_ingested_at TEXT NOT NULL,
                PRIMARY KEY (provider_id, path)
            );
            """
        ]
    )

    public static let toolEvents = StorageSchemaMigration(
        version: 3,
        name: "tool_events",
        statements: [
            """
            CREATE TABLE IF NOT EXISTS tool_events (
                id TEXT PRIMARY KEY,
                provider_id TEXT NOT NULL,
                session_id TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                tool_name TEXT NOT NULL,
                target_path TEXT,
                command TEXT,
                raw_source_path TEXT NOT NULL
            );
            """,
            """
            DELETE FROM source_files;
            """
        ]
    )

    public static let toolEventWorkingDirectory = StorageSchemaMigration(
        version: 4,
        name: "tool_event_working_directory",
        statements: [
            """
            ALTER TABLE tool_events ADD COLUMN working_directory TEXT;
            """,
            """
            DELETE FROM tool_events;
            """,
            """
            DELETE FROM source_files;
            """
        ]
    )

    public static let toolEventFailures = StorageSchemaMigration(
        version: 5,
        name: "tool_event_failures",
        statements: [
            """
            ALTER TABLE tool_events ADD COLUMN tool_call_id TEXT;
            """,
            """
            ALTER TABLE tool_events ADD COLUMN exit_code INTEGER;
            """,
            """
            ALTER TABLE tool_events ADD COLUMN error_summary TEXT;
            """,
            """
            DELETE FROM tool_events;
            """,
            """
            DELETE FROM source_files;
            """
        ]
    )
}
