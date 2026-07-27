use std::collections::HashMap;
use std::path::{Path, PathBuf};

use chrono::{DateTime, Utc};
use crate::models::leadership::LeadershipDashboardSnapshot;

use crate::models::*;
use crate::readers::{
    build_leadership_snapshot,
    make_local_usage,
    CodexStateReader,
    CodexThreadMetadata,
    CodexTranscriptReader,
};

/// Default leadership period for dashboard visibility.
const LEADERSHIP_PERIOD_DEFAULT: &str = "twentyEightDays";

/// Default model version for dashboard leadership snapshots.
const DEFAULT_LEADERSHIP_MODEL_VERSION: &str = "1.3-codex-interval";

/// Codex-only dashboard snapshot provider.
///
/// The provider always builds a complete snapshot from local transcript state:
/// - local `state_5.sqlite` metadata
/// - local session summaries (parsed once)
/// - local usage aggregation
/// - leadership score/report composition
///
/// Provider calls should be serialized (single-flight) by the AppState/caller cache
/// so we do not emit overlapping refreshes or race updates into shared snapshot state.
pub struct CodexDashboardProvider {
    codex_root: PathBuf,
    cache_dir: PathBuf,
}

impl CodexDashboardProvider {
    pub fn new(codex_root: impl AsRef<Path>, cache_dir: impl AsRef<Path>) -> Self {
        Self {
            codex_root: codex_root.as_ref().to_path_buf(),
            cache_dir: cache_dir.as_ref().to_path_buf(),
        }
    }

    /// Loads a single Codex dashboard snapshot from local state.
    pub async fn load_dashboard_snapshot(
        &self,
        now: DateTime<Utc>,
    ) -> anyhow::Result<Option<CodexDashboardSnapshot>> {
        let (state_metadata, messages) = self.load_state_metadata().await?;

        let transcript_reader = CodexTranscriptReader::new(&self.cache_dir);
        let summaries = transcript_reader
            .load_local_session_summaries(&self.codex_root, state_metadata)
            .await?;
        let Some(summaries) = summaries else {
            return Ok(None);
        };

        let local_usage = make_local_usage(summaries.clone(), now);
        let leadership_snapshot = build_leadership_snapshot(&summaries, now);
        let leadership_signal = build_codex_leadership_signal(&leadership_snapshot);

        Ok(Some(CodexDashboardSnapshot {
            codex: build_codex_runtime_snapshot(local_usage, now),
            leadership: leadership_signal,
            refreshed_at: now,
            messages,
        }))
    }

    async fn load_state_metadata(
        &self,
    ) -> anyhow::Result<(HashMap<String, CodexThreadMetadata>, Vec<String>)> {
        let state_db_path = self.codex_root.join("state_5.sqlite");
        if !tokio::fs::try_exists(&state_db_path).await.unwrap_or(false) {
            return Ok((
                HashMap::new(),
                vec!["No local Codex state metadata file (state_5.sqlite); using transcript summaries only."
                    .to_string()],
            ));
        }

        match CodexStateReader::new(&state_db_path).load_metadata().await {
            Ok(metadata) => Ok((metadata, vec![])),
            Err(err) => Ok((
                HashMap::new(),
                vec![format!(
                    "Failed to load local Codex state metadata from state_5.sqlite; using transcript summaries only. {}",
                    err
                )],
            )),
        }
    }
}

fn build_codex_runtime_snapshot(
    local: Option<LocalUsage>,
    refreshed_at: DateTime<Utc>,
) -> RuntimeUsageSnapshot {
    let usage = UsageSnapshot {
        refreshed_at,
        account: AccountInfo {
            r#type: "codex-local".to_string(),
            plan_type: None,
            email_present: false,
        },
        limit_id: "codex-local".to_string(),
        limit_name: "Codex local snapshot (no official quota)".to_string(),
        quota_read_succeeded: false,
        five_hour_quota: None,
        seven_day_quota: None,
        monthly_quota: None,
        local,
        task_board: None,
        messages: vec![],
    };

    RuntimeUsageSnapshot {
        scope: RuntimeScope::Codex,
        snapshot: usage,
        status: RuntimeMenuStatus::LocalOnly,
        quota_source_label: "Official quota unavailable on Windows".to_string(),
        usage_source_label: "Local Codex transcript data".to_string(),
    }
}

fn build_codex_leadership_signal(
    snapshot: &LeadershipDashboardSnapshot,
) -> CodexLeadershipSignal {
    let default_report = snapshot
        .reports
        .iter()
        .find(|report| report.period == LEADERSHIP_PERIOD_DEFAULT);

    let report_model_version = if snapshot.model_version.is_empty() {
        DEFAULT_LEADERSHIP_MODEL_VERSION.to_string()
    } else {
        snapshot.model_version.clone()
    };
    let is_non_stub_model = !report_model_version.contains("stub");
    let score = if is_non_stub_model {
        default_report.and_then(|report| report.score)
    } else {
        None
    };

    CodexLeadershipSignal {
        score,
        evidence_coverage: default_report.map(|report| report.evidence_coverage).unwrap_or(0.0),
        active_day_count: default_report.map(|report| report.active_day_count).unwrap_or(0),
        period: default_report
            .map(|report| report.period.clone())
            .unwrap_or_else(|| LEADERSHIP_PERIOD_DEFAULT.to_string()),
        model_version: report_model_version,
        report: Some(snapshot.clone()),
    }
}

#[cfg(test)]
mod tests {
    use chrono::{Duration, TimeZone};
    use rusqlite::Connection;
    use tempfile::tempdir;

    use super::*;
    use crate::readers::{SessionSummary, UsageDelta};
    use crate::models::usage::TokenBreakdown;

    fn create_codex_state_db(
        path: &std::path::Path,
        rollout_filename: &str,
        title: &str,
        cwd: &str,
        model: &str,
        created_at: DateTime<Utc>,
    ) {
        let conn = Connection::open(path).unwrap();
        conn.execute(
            "CREATE TABLE threads (
                id TEXT PRIMARY KEY,
                rollout_path TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                source TEXT NOT NULL,
                model_provider TEXT NOT NULL,
                cwd TEXT NOT NULL,
                title TEXT NOT NULL,
                sandbox_policy TEXT NOT NULL,
                approval_mode TEXT NOT NULL,
                tokens_used INTEGER NOT NULL DEFAULT 0,
                has_user_event INTEGER NOT NULL DEFAULT 0,
                archived INTEGER NOT NULL DEFAULT 0,
                archived_at INTEGER,
                git_sha TEXT,
                git_branch TEXT,
                git_origin_url TEXT,
                cli_version TEXT NOT NULL DEFAULT '',
                first_user_message TEXT NOT NULL DEFAULT '',
                agent_nickname TEXT,
                agent_role TEXT,
                memory_mode TEXT NOT NULL DEFAULT 'enabled',
                model TEXT,
                reasoning_effort TEXT,
                reasoning_summary TEXT,
                agent_path TEXT,
                created_at_ms INTEGER,
                updated_at_ms INTEGER,
                thread_source TEXT,
                preview TEXT NOT NULL DEFAULT '',
                recency_at INTEGER NOT NULL DEFAULT 0,
                recency_at_ms INTEGER NOT NULL DEFAULT 0,
                history_mode TEXT NOT NULL DEFAULT 'legacy',
                name TEXT
            )",
            [],
        )
        .unwrap();
        conn.execute(
            "INSERT INTO threads (
                id, rollout_path, created_at, updated_at, source, model_provider,
                cwd, title, sandbox_policy, approval_mode, archived,
                model, created_at_ms, updated_at_ms, thread_source
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15)",
            rusqlite::params![
                "thread-1",
                rollout_filename,
                0i64,
                0i64,
                "source",
                "openai",
                cwd,
                title,
                "sandbox",
                "approval",
                0i64,
                if model.is_empty() {
                    None::<String>
                } else {
                    Some(model.to_string())
                },
                created_at.timestamp_millis(),
                created_at.timestamp_millis(),
                Some("main"),
            ],
        )
        .unwrap();
        conn.execute(
            "CREATE TABLE thread_spawn_edges (child_thread_id TEXT PRIMARY KEY, parent_thread_id TEXT)",
            [],
        )
        .unwrap();
    }

    fn write_session_file(path: &std::path::Path, lines: Vec<&str>) {
        std::fs::write(path, lines.join("\n")).unwrap();
    }

    #[tokio::test]
    async fn no_local_session_summaries_returns_none() {
        let temp = tempdir().unwrap();
        let provider = CodexDashboardProvider::new(temp.path(), temp.path().join("cache"));

        let snapshot = provider
            .load_dashboard_snapshot(Utc.with_ymd_and_hms(2026, 7, 28, 12, 0, 0).unwrap())
            .await
            .unwrap();

        assert!(snapshot.is_none());
    }

    #[tokio::test]
    async fn local_transcript_builds_runtime_snapshot_with_nested_local_usage_and_source_labels() {
        let temp = tempdir().unwrap();
        let archived = temp.path().join("archived_sessions");
        std::fs::create_dir_all(&archived).unwrap();
        let now = Utc.with_ymd_and_hms(2026, 3, 26, 12, 53, 47).unwrap();
        let state_path = temp.path().join("state_5.sqlite");
        create_codex_state_db(
            &state_path,
            "rollout-local.jsonl",
            "Task",
            "C:\\Projects\\A",
            "gpt-5.4",
            now,
        );

        let session = archived.join("rollout-local.jsonl");
        write_session_file(
            &session,
            vec![
                r#"{"timestamp":"2026-03-26T12:53:47.026Z","type":"session_meta","payload":{"id":"thread-1","timestamp":"2026-03-26T12:53:36.076Z","cwd":"C:\\\\Projects\\\\Demo","model_provider":"openai"}}"#,
                r#"{"timestamp":"2026-03-26T12:53:47.028Z","type":"turn_context","payload":{"turn_id":"turn-1","cwd":"C:\\\\Projects\\\\Demo","model":"gpt-5.4"}}"#,
                r#"{"timestamp":"2026-03-26T12:53:47.164Z","type":"event_msg","payload":{"type":"token_count","turn_id":"turn-1","info":{"last_token_usage":{"input_tokens":100,"cached_input_tokens":50,"output_tokens":30,"reasoning_output_tokens":10,"total_tokens":190}}}}"#,
            ],
        );
        let cache = temp.path().join("cache");
        let provider = CodexDashboardProvider::new(temp.path(), &cache);

        let snapshot = provider
            .load_dashboard_snapshot(now)
            .await
            .unwrap()
            .expect("should return snapshot");

        assert_eq!(snapshot.codex.scope, RuntimeScope::Codex);
        assert_eq!(snapshot.codex.status, RuntimeMenuStatus::LocalOnly);
        assert_eq!(snapshot.codex.usage_source_label, "Local Codex transcript data");
        assert_eq!(snapshot.codex.quota_source_label, "Official quota unavailable on Windows");
        assert!(!snapshot.codex.snapshot.quota_read_succeeded);
        assert!(snapshot.codex.snapshot.five_hour_quota.is_none());
        assert!(snapshot.codex.snapshot.task_board.is_none());
        assert_eq!(snapshot.codex.snapshot.local.as_ref().unwrap().thread_count, 1);
        assert!(snapshot.messages.is_empty());
    }

    #[tokio::test]
    async fn missing_state_db_preserves_local_transcripts_with_snapshot_warning() {
        let temp = tempdir().unwrap();
        let archived = temp.path().join("archived_sessions");
        std::fs::create_dir_all(&archived).unwrap();

        let now = Utc.with_ymd_and_hms(2026, 7, 28, 12, 0, 0).unwrap();
        let session = archived.join("rollout-no-state.jsonl");
        write_session_file(
            &session,
            vec![
                r#"{"timestamp":"2026-07-28T11:30:00.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1","started_at":"2026-07-28T11:30:00.000Z"}}"#,
                r#"{"timestamp":"2026-07-28T11:45:00.000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1","completed_at":"2026-07-28T11:45:00.000Z"}}"#,
                r#"{"timestamp":"2026-07-28T11:45:10.000Z","type":"event_msg","payload":{"type":"token_count","turn_id":"turn-1","info":{"last_token_usage":{"input_tokens":180,"cached_input_tokens":0,"output_tokens":60,"reasoning_output_tokens":0,"total_tokens":240}}}}"#,
            ],
        );

        let provider = CodexDashboardProvider::new(temp.path(), temp.path().join("cache"));
        let snapshot = provider
            .load_dashboard_snapshot(now)
            .await
            .unwrap()
            .expect("should produce snapshot");

        assert!(snapshot.codex.snapshot.local.is_some());
        assert!(
            snapshot
                .messages
                .iter()
                .any(|message| message.contains("state_5.sqlite"))
        );
    }

    #[tokio::test]
    async fn corrupted_state_db_preserves_local_transcripts_with_snapshot_warning() {
        let temp = tempdir().unwrap();
        let archived = temp.path().join("archived_sessions");
        std::fs::create_dir_all(&archived).unwrap();

        let now = Utc.with_ymd_and_hms(2026, 7, 28, 12, 0, 0).unwrap();
        let state_path = temp.path().join("state_5.sqlite");
        std::fs::write(&state_path, b"not a sqlite database").unwrap();

        let session = archived.join("rollout-corrupt.jsonl");
        write_session_file(
            &session,
            vec![
                r#"{"timestamp":"2026-07-28T11:10:00.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1","started_at":"2026-07-28T11:10:00.000Z"}}"#,
                r#"{"timestamp":"2026-07-28T11:25:00.000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1","completed_at":"2026-07-28T11:25:00.000Z"}}"#,
                r#"{"timestamp":"2026-07-28T11:25:10.000Z","type":"event_msg","payload":{"type":"token_count","turn_id":"turn-1","info":{"last_token_usage":{"input_tokens":250,"cached_input_tokens":10,"output_tokens":50,"reasoning_output_tokens":5,"total_tokens":315}}}}"#,
            ],
        );

        let provider = CodexDashboardProvider::new(temp.path(), temp.path().join("cache"));
        let snapshot = provider
            .load_dashboard_snapshot(now)
            .await
            .unwrap()
            .expect("should produce snapshot");

        assert!(snapshot.codex.snapshot.local.is_some());
        assert!(
            snapshot
                .messages
                .iter()
                .any(|message| message.starts_with("Failed to load local Codex state metadata"))
        );
    }

    #[tokio::test]
    async fn factual_twenty_eight_day_leadership_data_stays_in_leadership_report() {
        let temp = tempdir().unwrap();
        let archived = temp.path().join("archived_sessions");
        std::fs::create_dir_all(&archived).unwrap();

        let now = Utc.with_ymd_and_hms(2026, 7, 28, 12, 0, 0).unwrap();
        let state_path = temp.path().join("state_5.sqlite");
        create_codex_state_db(
            &state_path,
            "rollout-28d.jsonl",
            "Task",
            "C:\\Projects\\A",
            "gpt-5.4",
            now - Duration::hours(2),
        );

        let session = archived.join("rollout-28d.jsonl");
        write_session_file(
            &session,
            vec![
                r#"{"timestamp":"2026-07-28T11:40:00.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1","started_at":"2026-07-28T11:40:00.000Z"}}"#,
                r#"{"timestamp":"2026-07-28T11:55:00.000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1","completed_at":"2026-07-28T11:55:00.000Z"}}"#,
                r#"{"timestamp":"2026-07-28T11:56:10.000Z","type":"event_msg","payload":{"type":"token_count","turn_id":"turn-1","info":{"last_token_usage":{"input_tokens":100,"cached_input_tokens":0,"output_tokens":25,"reasoning_output_tokens":0,"total_tokens":125}}}}"#,
            ],
        );

        let provider = CodexDashboardProvider::new(temp.path(), temp.path().join("cache"));
        let snapshot = provider
            .load_dashboard_snapshot(now)
            .await
            .unwrap()
            .expect("should produce snapshot");

        let report = snapshot
            .leadership
            .report
            .as_ref()
            .and_then(|report| report.reports.iter().find(|r| r.period == "twentyEightDays"));
        assert!(report.is_some());
        let report = report.unwrap();
        assert!(snapshot.leadership.score.is_some());
        assert_eq!(snapshot.leadership.score, report.score);
        assert_eq!(report.period, snapshot.leadership.period);
        assert_eq!(report.evidence_coverage, snapshot.leadership.evidence_coverage);
        assert_eq!(report.active_day_count, snapshot.leadership.active_day_count);
        assert!(snapshot.codex.snapshot.local.is_some());
    }

    #[tokio::test]
    async fn weak_task_interval_evidence_keeps_local_usage_and_suppresses_score() {
        let temp = tempdir().unwrap();
        let archived = temp.path().join("archived_sessions");
        std::fs::create_dir_all(&archived).unwrap();

        let now = Utc.with_ymd_and_hms(2026, 7, 28, 12, 0, 0).unwrap();
        let session = archived.join("rollout-weak.jsonl");
        write_session_file(
            &session,
            vec![
                r#"{"timestamp":"2026-07-28T11:59:00.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1","started_at":"2026-07-28T11:59:00.000Z"}}"#,
                r#"{"timestamp":"2026-07-28T12:00:00.000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1","completed_at":"2026-07-28T12:00:00.000Z"}}"#,
                r#"{"timestamp":"2026-07-28T12:01:00.000Z","type":"event_msg","payload":{"type":"token_count","turn_id":"turn-1","info":{"last_token_usage":{"input_tokens":120,"cached_input_tokens":0,"output_tokens":20,"reasoning_output_tokens":0,"total_tokens":140}}}}"#,
            ],
        );

        let provider = CodexDashboardProvider::new(temp.path(), temp.path().join("cache"));
        let snapshot = provider
            .load_dashboard_snapshot(now)
            .await
            .unwrap()
            .expect("should produce snapshot");

        assert!(snapshot.codex.snapshot.local.is_some());
        assert!(snapshot.leadership.score.is_none());
    }

    #[test]
    fn codex_dashboard_snapshot_roundtrips_json_with_expected_top_level_shape() {
        let now = Utc.with_ymd_and_hms(2026, 7, 28, 12, 0, 0).unwrap();
        let usage = make_local_usage(
            vec![SessionSummary {
                file_path: "rollout-1.jsonl".to_string(),
                session_id: "thread-1".to_string(),
                project_path: "C:\\Projects\\A".to_string(),
                model: Some("gpt-5.4".to_string()),
                last_active_at: Some(now),
                created_at: Some(now),
                deltas: vec![UsageDelta {
                    message_id: Some("turn-1".to_string()),
                    date: now,
                    tokens: TokenBreakdown {
                        input_tokens: 10,
                        cached_input_tokens: 0,
                        output_tokens: 5,
                        reasoning_output_tokens: 0,
                        total_tokens: 15,
                    },
                    model: Some("gpt-5.4".to_string()),
                    project_path: "C:\\Projects\\A".to_string(),
                    session_id: "thread-1".to_string(),
                }],
                tool_calls: std::collections::HashMap::new(),
                title: None,
                archived: false,
                git_branch: None,
                git_origin_url: None,
                thread_source: Some("main".to_string()),
                parent_thread_id: None,
                task_intervals: vec![],
            }],
            now,
        )
        .unwrap();

        let runtime = build_codex_runtime_snapshot(Some(usage), now);
        let report = LeadershipReport {
            period: LEADERSHIP_PERIOD_DEFAULT.to_string(),
            score: Some(72),
            core_score: Some(73.5),
            title: Some(LeadershipTitle {
                level: 4,
                name: "Silicon Lord".to_string(),
                english_name: "Silicon Lord".to_string(),
                lower_bound: 50,
                upper_bound: 64,
            }),
            dimensions: vec![],
            maturity: 1.0,
            evidence_coverage: 0.95,
            active_day_count: 14,
            agent_count: Some(1),
            ai_hours: Some(1.2),
            autonomous_hours: Some(0.2),
            average_parallelism: Some(1.0),
            peak_concurrency: Some(1),
            project_count: 1,
            daily_points: vec![],
            projects: vec![],
        };
        let leadership_snapshot = LeadershipDashboardSnapshot {
            model_version: "1.3-codex-interval".to_string(),
            refreshed_at: now,
            reports: vec![report],
        };
        let leadership = build_codex_leadership_signal(&leadership_snapshot);
        let snapshot = CodexDashboardSnapshot {
            codex: runtime,
            leadership,
            refreshed_at: now,
            messages: vec!["Local Codex snapshot".to_string()],
        };

        let json = serde_json::to_string_pretty(&snapshot).unwrap();
        let decoded: serde_json::Value = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded["codex"]["scope"], "codex");
        assert!(decoded["leadership"]["report"].is_object());

        let roundtrip: CodexDashboardSnapshot = serde_json::from_str(&json).unwrap();
        assert_eq!(snapshot, roundtrip);
    }
}
