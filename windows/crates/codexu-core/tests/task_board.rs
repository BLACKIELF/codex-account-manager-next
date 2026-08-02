use chrono::{TimeZone, Utc};
use codexu_core::readers::CodexTaskBoardReader;
use rusqlite::{params, Connection};

fn create_task_state_db(root: &std::path::Path) {
    let connection = Connection::open(root.join("state_5.sqlite")).unwrap();
    connection
        .execute_batch(
            "CREATE TABLE threads (
                id TEXT PRIMARY KEY,
                title TEXT,
                cwd TEXT,
                archived INTEGER NOT NULL,
                thread_source TEXT,
                created_at INTEGER,
                updated_at INTEGER,
                recency_at INTEGER,
                archived_at INTEGER
            );",
        )
        .unwrap();
}

fn column<'a>(
    board: &'a codexu_core::models::TaskBoard,
    id: &str,
) -> &'a codexu_core::models::TaskColumn {
    board
        .columns
        .iter()
        .find(|column| column.id == id)
        .unwrap_or_else(|| panic!("missing {id} column"))
}

#[tokio::test]
async fn classifies_non_subagent_state_records_without_claiming_completion() {
    let root = tempfile::tempdir().unwrap();
    create_task_state_db(root.path());
    let now = Utc.with_ymd_and_hms(2026, 7, 29, 12, 0, 0).unwrap();
    let today = now
        .date_naive()
        .and_hms_opt(0, 0, 0)
        .unwrap()
        .and_utc()
        .timestamp();
    let connection = Connection::open(root.path().join("state_5.sqlite")).unwrap();

    for (id, title, archived, source, updated_at, archived_at) in [
        (
            "active",
            "Active work",
            0,
            "main",
            now.timestamp() - 60,
            None,
        ),
        (
            "pending",
            "Pending work",
            0,
            "main",
            now.timestamp() - 3 * 60 * 60,
            None,
        ),
        (
            "archived",
            "Archived work",
            1,
            "main",
            now.timestamp() - 60,
            Some(now.timestamp() - 30),
        ),
        (
            "subagent",
            "Hidden worker",
            0,
            "subagent",
            now.timestamp() - 60,
            None,
        ),
    ] {
        connection
            .execute(
                "INSERT INTO threads (
                    id, title, cwd, archived, thread_source, created_at, updated_at, recency_at, archived_at
                ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
                params![id, title, "C:\\Projects\\Example", archived, source, today, updated_at, updated_at, archived_at],
            )
            .unwrap();
    }
    drop(connection);

    let automation_dir = root.path().join("automations").join("daily-check");
    std::fs::create_dir_all(&automation_dir).unwrap();
    std::fs::write(
        automation_dir.join("automation.toml"),
        "id = \"daily-check\"\nname = \"Daily check\"\nstatus = \"ACTIVE\"\nkind = \"cron\"\nrrule = \"FREQ=DAILY\"\n",
    )
    .unwrap();
    let disabled_dir = root.path().join("automations").join("disabled-check");
    std::fs::create_dir_all(&disabled_dir).unwrap();
    std::fs::write(
        disabled_dir.join("automation.toml"),
        "id = \"disabled-check\"\nname = \"Disabled check\"\nstatus = \"PAUSED\"\nkind = \"cron\"\nrrule = \"FREQ=DAILY\"\n",
    )
    .unwrap();

    let board = CodexTaskBoardReader::new(root.path())
        .load(now)
        .await
        .unwrap()
        .expect("state database should produce a board");

    let active = column(&board, "active");
    assert_eq!(active.count, 1);
    assert_eq!(active.items[0].title, "Active work");
    assert_eq!(active.items[0].display_state, "recentlyActive");
    assert_eq!(active.items[0].state_basis, "activityWindow");

    let pending = column(&board, "pending");
    assert_eq!(pending.count, 1);
    assert_eq!(pending.items[0].title, "Pending work");
    assert_eq!(pending.items[0].display_state, "continueLater");

    let done = column(&board, "done");
    assert_eq!(done.count, 1);
    assert_eq!(done.items[0].title, "Archived work");
    assert_eq!(done.items[0].display_state, "archived");
    assert_eq!(done.items[0].state_basis, "archive");
    assert_ne!(done.items[0].display_state, "completed");

    let scheduled = column(&board, "scheduled");
    assert_eq!(scheduled.count, 1);
    assert_eq!(scheduled.items[0].title, "Daily check");
    assert_eq!(scheduled.items[0].display_state, "scheduled");
    assert_eq!(scheduled.items[0].state_basis, "scheduleConfig");
}

#[tokio::test]
async fn returns_an_explicit_empty_board_when_state_records_are_empty() {
    let root = tempfile::tempdir().unwrap();
    create_task_state_db(root.path());
    let now = Utc.with_ymd_and_hms(2026, 7, 29, 12, 0, 0).unwrap();

    let board = CodexTaskBoardReader::new(root.path())
        .load(now)
        .await
        .unwrap()
        .expect("an available state database should yield an empty board");

    assert_eq!(
        board
            .columns
            .iter()
            .map(|column| column.id.as_str())
            .collect::<Vec<_>>(),
        vec!["active", "pending", "scheduled", "done"]
    );
    assert!(board
        .columns
        .iter()
        .all(|column| column.count == 0 && column.items.is_empty()));
}

#[tokio::test]
async fn replaces_untrusted_titles_before_they_reach_the_task_snapshot() {
    let root = tempfile::tempdir().unwrap();
    create_task_state_db(root.path());
    let now = Utc.with_ymd_and_hms(2026, 7, 29, 12, 0, 0).unwrap();
    let connection = Connection::open(root.path().join("state_5.sqlite")).unwrap();

    for (id, title) in [
        ("safe", "Review task board layout"),
        (
            "path",
            "[build] C:\\Users\\Example\\Documents\\draft.md review",
        ),
        (
            "sensitive",
            "Private note: 20% carry and $1000 investment discussion",
        ),
    ] {
        connection
            .execute(
                "INSERT INTO threads (
                    id, title, cwd, archived, thread_source, created_at, updated_at, recency_at, archived_at
                ) VALUES (?1, ?2, ?3, 0, 'main', ?4, ?4, ?4, NULL)",
                params![id, title, "C:\\Projects\\Example", now.timestamp(),],
            )
            .unwrap();
    }
    drop(connection);

    let board = CodexTaskBoardReader::new(root.path())
        .load(now)
        .await
        .unwrap()
        .expect("state database should produce a board");
    let titles: Vec<&str> = column(&board, "active")
        .items
        .iter()
        .map(|item| item.title.as_str())
        .collect();

    assert!(titles.contains(&"Review task board layout"));
    assert_eq!(
        titles
            .iter()
            .filter(|title| **title == "Local activity record")
            .count(),
        2
    );
    assert!(titles.iter().all(|title| !title.contains("\\Users\\")));
    assert!(titles.iter().all(|title| !title.contains('$')));
    assert!(titles.iter().all(|title| !title.contains('%')));
}
