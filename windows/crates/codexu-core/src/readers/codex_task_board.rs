//! Privacy-safe local Codex task-board reader.
//!
//! The board deliberately reads only trusted state metadata from
//! `state_5.sqlite` and enabled automation metadata. It never opens session
//! JSONL files, previews, prompts, replies, tool arguments, or raw logs.

use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};

use anyhow::Result;
use chrono::{DateTime, Datelike, Duration, Local, TimeZone, Utc};
use rusqlite::{Connection, OpenFlags};

use crate::models::{TaskBoard, TaskColumn, TaskItem};

const ACTIVE_WINDOW: Duration = Duration::hours(2);
const MAX_AUTOMATION_SCAN_DEPTH: usize = 3;
const THREAD_ACTIVITY_TITLE: &str = "Codex activity";

/// Reads only local Codex task state appropriate for presentation.
pub struct CodexTaskBoardReader {
    codex_root: PathBuf,
}

impl CodexTaskBoardReader {
    pub fn new(codex_root: impl AsRef<Path>) -> Self {
        Self {
            codex_root: codex_root.as_ref().to_path_buf(),
        }
    }

    /// Returns `None` only when no trustworthy task source is available.
    ///
    /// An available but empty state database returns a board with the four
    /// stable columns so the UI can distinguish "no records yet" from a
    /// source that cannot be read.
    pub async fn load(&self, now: DateTime<Utc>) -> Result<Option<TaskBoard>> {
        let codex_root = self.codex_root.clone();
        tokio::task::spawn_blocking(move || load_task_board(&codex_root, now)).await?
    }
}

#[derive(Debug)]
struct ThreadRecord {
    id: String,
    workspace: String,
    activity_at: Option<DateTime<Utc>>,
    archived_at: Option<DateTime<Utc>>,
    archived: bool,
}

#[derive(Debug, Default)]
struct AutomationRecord {
    id: String,
    title: String,
    detail: String,
    chip: String,
}

fn load_task_board(codex_root: &Path, now: DateTime<Utc>) -> Result<Option<TaskBoard>> {
    let state_db = [
        codex_root.join("state_5.sqlite"),
        codex_root.join("sqlite").join("state_5.sqlite"),
    ]
    .into_iter()
    .find(|path| path.is_file());
    let automation_root = codex_root.join("automations");
    let has_automation_root = automation_root.is_dir();

    if state_db.is_none() && !has_automation_root {
        return Ok(None);
    }

    let records = match state_db {
        Some(path) => read_thread_records(&path, now)?,
        None => Vec::new(),
    };
    let automations = read_active_automations(&automation_root);
    Ok(Some(build_task_board(records, automations, now)))
}

fn read_thread_records(path: &Path, now: DateTime<Utc>) -> Result<Vec<ThreadRecord>> {
    let connection = Connection::open_with_flags(path, OpenFlags::SQLITE_OPEN_READ_ONLY)?;
    let columns = table_columns(&connection, "threads")?;
    if !["id", "title", "archived", "created_at", "updated_at"]
        .iter()
        .all(|column| columns.contains(*column))
    {
        return Ok(Vec::new());
    }

    let day_start = local_day_start(now).timestamp();
    let source_clause = if columns.contains("thread_source") {
        " AND COALESCE(LOWER(thread_source), '') <> 'subagent'"
    } else {
        ""
    };
    let cwd_expr = if columns.contains("cwd") { "cwd" } else { "''" };
    let recency_expr = if columns.contains("recency_at") {
        "recency_at"
    } else {
        "NULL"
    };
    let archived_at_expr = if columns.contains("archived_at") {
        "archived_at"
    } else {
        "NULL"
    };

    let active_query = format!(
        "SELECT id, {cwd_expr}, updated_at, {recency_expr}, created_at
         FROM threads
         WHERE COALESCE(archived, 0) = 0
           AND TRIM(COALESCE(title, '')) <> ''
           {source_clause}
           AND MAX(COALESCE(updated_at, 0), COALESCE({recency_expr}, 0), COALESCE(created_at, 0)) >= ?1
         ORDER BY MAX(COALESCE({recency_expr}, 0), COALESCE(updated_at, 0), COALESCE(created_at, 0)) DESC"
    );
    let archived_query = format!(
        "SELECT id, {cwd_expr}, {archived_at_expr}, updated_at, created_at
         FROM threads
         WHERE COALESCE(archived, 0) = 1
           AND TRIM(COALESCE(title, '')) <> ''
           {source_clause}
           AND MAX(COALESCE({archived_at_expr}, 0), COALESCE(updated_at, 0), COALESCE(created_at, 0)) >= ?1
         ORDER BY MAX(COALESCE({archived_at_expr}, 0), COALESCE(updated_at, 0), COALESCE(created_at, 0)) DESC"
    );

    let mut records = Vec::new();
    let mut active_statement = connection.prepare(&active_query)?;
    let active_rows = active_statement.query_map([day_start], |row| {
        Ok(ThreadRecord {
            id: row.get(0)?,
            workspace: row.get::<_, Option<String>>(1)?.unwrap_or_default(),
            activity_at: latest_timestamp([
                row.get::<_, Option<i64>>(2)?,
                row.get::<_, Option<i64>>(3)?,
                row.get::<_, Option<i64>>(4)?,
            ]),
            archived_at: None,
            archived: false,
        })
    })?;
    for row in active_rows {
        records.push(row?);
    }

    let mut archived_statement = connection.prepare(&archived_query)?;
    let archived_rows = archived_statement.query_map([day_start], |row| {
        let archived_at = latest_timestamp([
            row.get::<_, Option<i64>>(2)?,
            row.get::<_, Option<i64>>(3)?,
            row.get::<_, Option<i64>>(4)?,
        ]);
        Ok(ThreadRecord {
            id: row.get(0)?,
            workspace: row.get::<_, Option<String>>(1)?.unwrap_or_default(),
            activity_at: archived_at,
            archived_at,
            archived: true,
        })
    })?;
    for row in archived_rows {
        records.push(row?);
    }

    Ok(records)
}

fn build_task_board(
    records: Vec<ThreadRecord>,
    automations: Vec<AutomationRecord>,
    now: DateTime<Utc>,
) -> TaskBoard {
    let mut active = Vec::new();
    let mut pending = Vec::new();
    let mut done = Vec::new();

    for record in records {
        if record.archived {
            done.push(thread_task_item(record, "done", "archived", "archive"));
        } else if record
            .activity_at
            .is_some_and(|activity| activity >= now - ACTIVE_WINDOW)
        {
            active.push(thread_task_item(
                record,
                "active",
                "recentlyActive",
                "activityWindow",
            ));
        } else {
            pending.push(thread_task_item(
                record,
                "pending",
                "continueLater",
                "activityWindow",
            ));
        }
    }

    sort_task_items(&mut active);
    sort_task_items(&mut pending);
    sort_task_items(&mut done);

    let mut scheduled: Vec<TaskItem> = automations
        .into_iter()
        .map(|automation| TaskItem {
            id: format!("automation-{}", automation.id),
            code: display_code("AUTO", &automation.id),
            title: automation.title,
            detail: automation.detail,
            chip: automation.chip,
            updated_at: None,
            tokens: None,
            kind: "scheduled".to_string(),
            thread_id: None,
            runtime_state: "recorded".to_string(),
            source_kind: "codexAutomation".to_string(),
            display_state: "scheduled".to_string(),
            state_basis: "scheduleConfig".to_string(),
            raw_status: None,
            next_run_at: None,
        })
        .collect();
    scheduled.sort_by(|left, right| {
        left.title
            .cmp(&right.title)
            .then_with(|| left.id.cmp(&right.id))
    });

    TaskBoard {
        refreshed_at: now,
        columns: vec![
            task_column("active", "Recent activity", active),
            task_column("pending", "To continue", pending),
            task_column("scheduled", "Scheduled", scheduled),
            task_column("done", "Archived today", done),
        ],
    }
}

fn thread_task_item(
    record: ThreadRecord,
    kind: &str,
    display_state: &str,
    state_basis: &str,
) -> TaskItem {
    let factual_time = if record.archived_at.is_some() {
        record.archived_at
    } else {
        record.activity_at
    };
    TaskItem {
        id: format!("{}-{kind}", record.id),
        code: display_code("COD", &record.id),
        // `threads.title` is a user/session label and has no provenance that
        // proves it is safe agent-generated task text. Keep the activity card
        // and its factual state while using a non-content label at this boundary.
        title: THREAD_ACTIVITY_TITLE.to_string(),
        detail: if record.workspace.trim().is_empty() {
            String::new()
        } else {
            short_workspace_name(&record.workspace)
        },
        chip: display_state.to_string(),
        updated_at: factual_time,
        tokens: None,
        kind: kind.to_string(),
        thread_id: Some(record.id),
        runtime_state: "recorded".to_string(),
        source_kind: "codexThread".to_string(),
        display_state: display_state.to_string(),
        state_basis: state_basis.to_string(),
        raw_status: None,
        next_run_at: None,
    }
}

fn task_column(id: &str, title: &str, items: Vec<TaskItem>) -> TaskColumn {
    TaskColumn {
        id: id.to_string(),
        title: title.to_string(),
        count: items.len() as i64,
        items,
    }
}

fn sort_task_items(items: &mut [TaskItem]) {
    items.sort_by(|left, right| {
        right
            .updated_at
            .cmp(&left.updated_at)
            .then_with(|| left.id.cmp(&right.id))
    });
}

fn read_active_automations(root: &Path) -> Vec<AutomationRecord> {
    let mut files = Vec::new();
    find_automation_files(root, 0, &mut files);
    files
        .into_iter()
        .filter_map(|path| fs::read_to_string(path).ok())
        .filter_map(|contents| parse_active_automation(&contents))
        .collect()
}

fn find_automation_files(directory: &Path, depth: usize, files: &mut Vec<PathBuf>) {
    if depth > MAX_AUTOMATION_SCAN_DEPTH {
        return;
    }
    let Ok(entries) = fs::read_dir(directory) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_file()
            && path
                .file_name()
                .is_some_and(|name| name == "automation.toml")
        {
            files.push(path);
        } else if path.is_dir() {
            find_automation_files(&path, depth + 1, files);
        }
    }
}

fn parse_active_automation(contents: &str) -> Option<AutomationRecord> {
    let mut id = None;
    let mut name = None;
    let mut status = None;
    let mut kind = None;
    let mut rrule = None;

    for line in contents.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let (key, value) = line.split_once('=')?;
        let value = value.trim().trim_matches('"').trim_matches('\'').trim();
        match key.trim() {
            "id" => id = non_empty(value),
            "name" => name = non_empty(value),
            "status" => status = non_empty(value),
            "kind" => kind = non_empty(value),
            "rrule" => rrule = non_empty(value),
            _ => {}
        }
    }

    if !status.is_some_and(|value| value.eq_ignore_ascii_case("ACTIVE")) {
        return None;
    }
    let kind = kind.unwrap_or("cron");
    let is_heartbeat = kind.eq_ignore_ascii_case("heartbeat");
    let schedule = rrule.filter(|rule| valid_rrule(rule));
    if !is_heartbeat && schedule.is_none() {
        return None;
    }

    let id = id.map(str::to_owned).unwrap_or_else(|| "local".to_string());
    let title = name
        .map(str::to_owned)
        .unwrap_or_else(|| "Codex automation".to_string());
    Some(AutomationRecord {
        id,
        title: display_title(&title),
        detail: if is_heartbeat {
            "Active heartbeat".to_string()
        } else {
            schedule_summary(schedule.as_deref().unwrap_or_default())
        },
        chip: if is_heartbeat {
            "Heartbeat".to_string()
        } else {
            "Scheduled".to_string()
        },
    })
}

fn valid_rrule(rule: &str) -> bool {
    let normalized = rule.to_ascii_uppercase();
    ["DAILY", "WEEKLY", "HOURLY", "MINUTELY"]
        .iter()
        .any(|frequency| normalized.contains(&format!("FREQ={frequency}")))
}

fn schedule_summary(rule: &str) -> String {
    let normalized = rule.to_ascii_uppercase();
    if normalized.contains("FREQ=DAILY") {
        "Every day".to_string()
    } else if normalized.contains("FREQ=WEEKLY") {
        "Every week".to_string()
    } else if normalized.contains("FREQ=HOURLY") {
        "Every hour".to_string()
    } else {
        "Every minute".to_string()
    }
}

fn non_empty(value: &str) -> Option<&str> {
    (!value.is_empty()).then_some(value)
}

fn display_code(prefix: &str, id: &str) -> String {
    let compact: String = id
        .chars()
        .filter(|character| character.is_ascii_alphanumeric())
        .collect();
    let suffix: String = compact
        .chars()
        .rev()
        .take(4)
        .collect::<String>()
        .chars()
        .rev()
        .collect();
    format!("{prefix}-{}", suffix.to_ascii_uppercase())
}

fn display_title(title: &str) -> String {
    const MAX_SAFE_TITLE_CHARS: usize = 160;
    const SAFE_FALLBACK_TITLE: &str = "Local activity record";
    let normalized = title.split_whitespace().collect::<Vec<_>>().join(" ");
    let has_control_character = title.chars().any(char::is_control);
    let is_untrusted = normalized.is_empty()
        || has_control_character
        || normalized.chars().count() > MAX_SAFE_TITLE_CHARS
        || contains_private_path(&normalized)
        || contains_sensitive_value_marker(&normalized);

    if is_untrusted {
        SAFE_FALLBACK_TITLE.to_string()
    } else {
        normalized
    }
}

fn contains_private_path(title: &str) -> bool {
    let lowercase = title.to_ascii_lowercase();
    title.contains("\\")
        || title.contains(":/")
        || lowercase.contains("/users/")
        || lowercase.contains("/home/")
        || lowercase.contains(".codex")
        || lowercase.contains(".claude")
}

fn contains_sensitive_value_marker(title: &str) -> bool {
    title.contains('$') || title.contains('%') || title.contains('¥') || title.contains('￥')
}

fn short_workspace_name(path: &str) -> String {
    let trimmed = path.trim_matches(|character| character == '/' || character == '\\');
    trimmed
        .split(['/', '\\'])
        .next_back()
        .unwrap_or_default()
        .to_string()
}

fn latest_timestamp(values: [Option<i64>; 3]) -> Option<DateTime<Utc>> {
    values
        .into_iter()
        .flatten()
        .filter(|timestamp| *timestamp > 0)
        .max()
        .and_then(|timestamp| Utc.timestamp_opt(timestamp, 0).single())
}

fn table_columns(connection: &Connection, table: &str) -> Result<HashSet<String>> {
    let mut statement = connection.prepare(&format!("PRAGMA table_info({table})"))?;
    let columns = statement
        .query_map([], |row| row.get::<_, String>(1))?
        .collect::<std::result::Result<HashSet<_>, _>>()?;
    Ok(columns)
}

fn local_day_start(now: DateTime<Utc>) -> DateTime<Utc> {
    let local = now.with_timezone(&Local);
    Local
        .with_ymd_and_hms(local.year(), local.month(), local.day(), 0, 0, 0)
        .earliest()
        .map(|value| value.with_timezone(&Utc))
        .unwrap_or(now)
}
