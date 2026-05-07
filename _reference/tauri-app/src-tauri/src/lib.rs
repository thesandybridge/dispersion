use tauri_plugin_sql::{Migration, MigrationKind};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let migrations = vec![
        Migration {
            version: 1,
            description: "create_clubs_table",
            sql: "CREATE TABLE clubs (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            carry_yards REAL NOT NULL,
            carry_sd REAL NOT NULL,
            lateral_sd REAL NOT NULL,
            created_at INTEGER NOT NULL
        );",
            kind: MigrationKind::Up,
        },
        Migration {
            version: 2,
            description: "create_sessions_table",
            sql: "CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY NOT NULL,
                kind TEXT NOT NULL,
                label TEXT NOT NULL,
                started_at INTEGER NOT NULL
            );",
            kind: MigrationKind::Up,
        },
        Migration {
            version: 3,
            description: "create_shots_table",
            sql: "CREATE TABLE IF NOT EXISTS shots (
                id TEXT PRIMARY KEY NOT NULL,
                session_id TEXT NOT NULL,
                club_id TEXT NOT NULL,
                target_distance_yards REAL NOT NULL,
                long_delta REAL NOT NULL,
                lat_delta REAL NOT NULL,
                outcome TEXT,
                timestamp INTEGER NOT NULL
            );",
            kind: MigrationKind::Up,
        },
        Migration {
            version: 4,
            description: "idx_shots_session",
            sql: "CREATE INDEX IF NOT EXISTS idx_shots_session ON shots (session_id);",
            kind: MigrationKind::Up,
        },
        Migration {
            version: 5,
            description: "idx_shots_club",
            sql: "CREATE INDEX IF NOT EXISTS idx_shots_club ON shots (club_id);",
            kind: MigrationKind::Up,
        },
        Migration {
            version: 6,
            description: "idx_shots_timestamp",
            sql: "CREATE INDEX IF NOT EXISTS idx_shots_timestamp ON shots (timestamp);",
            kind: MigrationKind::Up,
        },
        Migration {
            version: 7,
            description: "create_face_strikes_table",
            sql: "CREATE TABLE IF NOT EXISTS face_strikes (
                id TEXT PRIMARY KEY NOT NULL,
                club_id TEXT NOT NULL,
                x REAL NOT NULL,
                y REAL NOT NULL,
                note TEXT NOT NULL DEFAULT '',
                session_id TEXT,
                shot_id TEXT,
                timestamp INTEGER NOT NULL
            );",
            kind: MigrationKind::Up,
        },
        Migration {
            version: 8,
            description: "idx_face_strikes_club",
            sql: "CREATE INDEX IF NOT EXISTS idx_face_strikes_club ON face_strikes (club_id);",
            kind: MigrationKind::Up,
        },
        Migration {
            version: 9,
            description: "idx_face_strikes_timestamp",
            sql: "CREATE INDEX IF NOT EXISTS idx_face_strikes_timestamp ON face_strikes (timestamp);",
            kind: MigrationKind::Up,
        },
        Migration {
            version: 10,
            description: "create_test_clubs_table",
            sql: "CREATE TABLE IF NOT EXISTS test_clubs (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                carry_yards REAL NOT NULL,
                carry_sd REAL NOT NULL,
                lateral_sd REAL NOT NULL,
                source TEXT NOT NULL DEFAULT '',
                created_at INTEGER NOT NULL
            );",
            kind: MigrationKind::Up,
        },
    ];

    tauri::Builder::default()
        .plugin(tauri_plugin_haptics::init())
        .plugin(
            tauri_plugin_sql::Builder::default()
                .add_migrations("sqlite:dispersion.db", migrations)
                .build(),
        )
        .setup(|app| {
            if cfg!(debug_assertions) {
                app.handle().plugin(
                    tauri_plugin_log::Builder::default()
                        .level(log::LevelFilter::Info)
                        .build(),
                )?;
            }
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
