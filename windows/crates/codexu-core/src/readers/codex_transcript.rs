//! Codex transcript reader.
//!
//! Reads Codex archived session JSONL files and produces `LocalUsage`.
//!
//! Codex JSONL format (Windows, 2026-07) has only three top-level fields:
//! `timestamp`, `type`, `payload`. All event-specific data lives inside
//! `payload`, so this reader maps the macOS-expected fields from the payload
//! object rather than the top-level line.
//!
//! Usage events appear as:
//! ```json
//! {
//!   "timestamp": "2026-03-26T12:53:47.164Z",
//!   "type": "event_msg",
//!   "payload": {
//!     "type": "token_count",
//!     "info": {
//!       "total_token_usage": {
//!         "input_tokens": 16545,
//!         "cached_input_tokens": 9728,
//!         "output_tokens": 710,
//!         "reasoning_output_tokens": 368,
//!         "total_tokens": 17255
//!       }
//!     }
//!   }
//! }
//! ```

use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};

use chrono::{DateTime, TimeZone, Utc};
use serde::{Deserialize, Serialize};

use super::common::*;
use super::codex_state::CodexThreadMetadata;
use crate::models::*;

const CODEX_CACHE_VERSION: i32 = 1;

/// On-disk cache for Codex transcript summaries.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CodexSessionDiskCache {
    pub version: i32,
    pub entries: HashMap<String, CodexSessionCacheEntry>,
}

/// A cached summary for a single Codex transcript file.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CodexSessionCacheEntry {
    pub file_size: i64,
    pub modification_time_ns: Option<i64>,
    pub summary: CodexTranscriptSummary,
}

impl CodexSessionCacheEntry {
    pub fn matches(&self, fingerprint: &FileFingerprint) -> bool {
        self.file_size == fingerprint.file_size
            && self.modification_time_ns == fingerprint.modification_time_ns
    }
}

/// Summary of a single Codex transcript file.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CodexTranscriptSummary {
    pub file_path: String,
    pub session_id: String,
    pub project_path: String,
    pub model: Option<String>,
    #[serde(with = "chrono::serde::ts_milliseconds_option")]
    pub last_active_at: Option<DateTime<Utc>>,
    pub deltas: Vec<CodexUsageDelta>,
    pub tool_calls: HashMap<String, i64>,
}

/// A single usage delta extracted from a Codex transcript.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CodexUsageDelta {
    pub turn_id: Option<String>,
    #[serde(with = "chrono::serde::ts_milliseconds")]
    pub date: DateTime<Utc>,
    pub tokens: TokenBreakdown,
    pub model: Option<String>,
    pub project_path: String,
    pub session_id: String,
}

/// Reads Codex transcripts and produces `LocalUsage`.
pub struct CodexTranscriptReader {
    cache_dir: PathBuf,
}

impl CodexTranscriptReader {
    pub fn new(cache_dir: impl AsRef<Path>) -> Self {
        Self {
            cache_dir: cache_dir.as_ref().to_path_buf(),
        }
    }

    pub async fn load_local_usage(
        &self,
        data_root: impl AsRef<Path>,
        now: DateTime<Utc>,
    ) -> anyhow::Result<Option<LocalUsage>> {
        self.load_local_usage_with_metadata(data_root, HashMap::new(), now)
            .await
    }

    /// Loads usage and enriches each session with metadata from `state_5.sqlite`.
    pub async fn load_local_usage_with_metadata(
        &self,
        data_root: impl AsRef<Path>,
        metadata: HashMap<String, CodexThreadMetadata>,
        now: DateTime<Utc>,
    ) -> anyhow::Result<Option<LocalUsage>> {
        let data_root = data_root.as_ref();
        if !tokio::fs::try_exists(data_root).await.unwrap_or(false) {
            return Ok(None);
        }

        let archived_dir = data_root.join("archived_sessions");
        let sessions_dir = data_root.join("sessions");

        let mut files = Vec::new();
        if tokio::fs::try_exists(&archived_dir).await.unwrap_or(false) {
            files.extend(enumerate_jsonl_files(&archived_dir).await);
        }
        if tokio::fs::try_exists(&sessions_dir).await.unwrap_or(false) {
            files.extend(enumerate_jsonl_files(&sessions_dir).await);
        }

        if files.is_empty() {
            return Ok(None);
        }

        files.sort();
        files.dedup();

        let mut cache = self.read_cache().await;
        let live_paths: HashSet<String> = files
            .iter()
            .map(|f| f.to_string_lossy().to_string())
            .collect();
        cache.entries.retain(|k, _| live_paths.contains(k));

        let mut summaries = Vec::new();
        for file in files {
            let fingerprint = fingerprint_for(&file).await;
            let key = file.to_string_lossy().to_string();

            if let Some(entry) = cache.entries.get(&key) {
                if let Some(ref fp) = fingerprint {
                    if entry.matches(fp) {
                        summaries.push(entry.summary.clone());
                        continue;
                    }
                }
            }

            let summary = parse_transcript(&file, fingerprint.as_ref()).await;
            if let Some(fp) = fingerprint {
                cache.entries.insert(
                    key,
                    CodexSessionCacheEntry {
                        file_size: fp.file_size,
                        modification_time_ns: fp.modification_time_ns,
                        summary: summary.clone(),
                    },
                );
            }
            summaries.push(summary);
        }

        self.write_cache(&cache).await;
        Ok(make_local_usage_from_codex(summaries, metadata, now))
    }

    async fn read_cache(&self) -> CodexSessionDiskCache {
        let path = self.cache_dir.join("codex").join("session-usage-v1.json");
        match tokio::fs::metadata(&path).await {
            Ok(meta) if meta.len() <= MAX_CACHE_BYTES => {}
            _ => {
                return CodexSessionDiskCache {
                    version: CODEX_CACHE_VERSION,
                    entries: HashMap::new(),
                }
            }
        }
        match tokio::fs::read(&path).await {
            Ok(data) => match serde_json::from_slice::<CodexSessionDiskCache>(&data) {
                Ok(cache) if cache.version == CODEX_CACHE_VERSION => cache,
                _ => CodexSessionDiskCache {
                    version: CODEX_CACHE_VERSION,
                    entries: HashMap::new(),
                },
            },
            _ => CodexSessionDiskCache {
                version: CODEX_CACHE_VERSION,
                entries: HashMap::new(),
            },
        }
    }

    async fn write_cache(&self, cache: &CodexSessionDiskCache) {
        let path = self.cache_dir.join("codex").join("session-usage-v1.json");
        if let Ok(data) = serde_json::to_vec(cache) {
            if data.len() as u64 <= MAX_CACHE_BYTES {
                let _ = tokio::fs::create_dir_all(path.parent().unwrap()).await;
                let _ = tokio::fs::write(&path, data).await;
            }
        }
    }
}

async fn parse_transcript(
    file: &Path,
    fingerprint: Option<&FileFingerprint>,
) -> CodexTranscriptSummary {
    let session_id = file
        .file_stem()
        .map(|s| s.to_string_lossy().to_string())
        .unwrap_or_default();
    let modification_date =
        fingerprint.and_then(|fp| fp.modification_time_ns.map(|ns| Utc.timestamp_nanos(ns)));

    let mut summary = CodexTranscriptSummary {
        file_path: file.to_string_lossy().to_string(),
        session_id: session_id.clone(),
        project_path: String::new(),
        model: None,
        last_active_at: modification_date,
        deltas: Vec::new(),
        tool_calls: HashMap::new(),
    };

    let data = match tokio::fs::read(file).await {
        Ok(data) => data,
        Err(_) => return summary,
    };

    let mut seen_turn_ids = HashSet::new();
    // Track the most recently observed model per turn so token_count events can
    // inherit it even if the turn_context appeared earlier in the file.
    let mut turn_models: HashMap<String, String> = HashMap::new();

    for line in data.split(|b| *b == b'\n') {
        if line.is_empty() || line.len() > MAX_LINE_BYTES {
            continue;
        }
        let text = match std::str::from_utf8(line) {
            Ok(text) => text,
            Err(_) => continue,
        };
        let object: serde_json::Value = match serde_json::from_str(text) {
            Ok(v) => v,
            Err(_) => continue,
        };

        let envelope_type = object.get("type").and_then(|v| v.as_str());
        let payload = match object.get("payload") {
            Some(p) if !p.is_null() => p,
            _ => continue,
        };

        let timestamp = codex_date_value(object.get("timestamp"))
            .or_else(|| codex_date_value(payload.get("timestamp")))
            .or(modification_date)
            .unwrap_or_else(Utc::now);

        // Update session-level context from session_meta / turn_context.
        if envelope_type == Some("session_meta") {
            if let Some(cwd) = codex_string_value(payload.get("cwd")) {
                summary.project_path = cwd;
            }
            // model_provider (e.g. "openai") is not a model name; ignore it.
        } else if envelope_type == Some("turn_context") {
            if let Some(cwd) = codex_string_value(payload.get("cwd")) {
                summary.project_path = cwd;
            }
            if let Some(model) = codex_string_value(payload.get("model")) {
                summary.model = Some(model.clone());
            }
            if let Some(turn_id) = codex_string_value(payload.get("turn_id")) {
                if let Some(ref m) = summary.model {
                    turn_models.insert(turn_id, m.clone());
                }
            }
        }

        summary.last_active_at = summary
            .last_active_at
            .map(|d| d.max(timestamp))
            .or(Some(timestamp));

        // Tool calls are response_items with payload.type == "custom_tool_call".
        if envelope_type == Some("response_item") {
            if let Some(payload_type) = codex_string_value(payload.get("type")) {
                if payload_type == "custom_tool_call" {
                    if let Some(name) = codex_string_value(payload.get("name")) {
                        if !name.is_empty() {
                            *summary.tool_calls.entry(name).or_insert(0) += 1;
                        }
                    }
                }
            }
            continue;
        }

        // Usage events are event_msg with payload.type == "token_count".
        if envelope_type != Some("event_msg") {
            continue;
        }
        if codex_string_value(payload.get("type")).as_deref() != Some("token_count") {
            continue;
        }

        let info = match payload.get("info") {
            Some(i) if !i.is_null() => i,
            _ => continue,
        };
        // `last_token_usage` is the delta for the current turn; `total_token_usage`
        // is cumulative across the session. Prefer the per-turn delta so we can
        // sum across turns without over-counting.
        let usage = match info
            .get("last_token_usage")
            .or_else(|| info.get("total_token_usage"))
        {
            Some(u) => u,
            None => continue,
        };
        let tokens = match parse_usage(usage) {
            Some(t) if !t.is_zero() => t,
            _ => continue,
        };

        let turn_id = codex_string_value(payload.get("turn_id"));
        let dedup_key = turn_id.clone().unwrap_or_else(|| {
            // Token-count events without a turn_id are usually session-level
            // warm-up/context counts. Use the timestamp as a synthetic key.
            format!("{}:{}", summary.session_id, timestamp.timestamp_millis())
        });
        if seen_turn_ids.contains(&dedup_key) {
            continue;
        }
        seen_turn_ids.insert(dedup_key);

        let model = turn_id
            .as_ref()
            .and_then(|id| turn_models.get(id).cloned())
            .or_else(|| summary.model.clone());

        summary.deltas.push(CodexUsageDelta {
            turn_id,
            date: timestamp,
            tokens,
            model,
            project_path: summary.project_path.clone(),
            session_id: summary.session_id.clone(),
        });
    }

    summary
}

fn parse_usage(usage: &serde_json::Value) -> Option<TokenBreakdown> {
    let input = codex_i64_value(usage.get("input_tokens")).unwrap_or(0);
    let cached = codex_i64_value(usage.get("cached_input_tokens")).unwrap_or(0);
    let output = codex_i64_value(usage.get("output_tokens")).unwrap_or(0);
    let reasoning = codex_i64_value(usage.get("reasoning_output_tokens")).unwrap_or(0);
    let total =
        codex_i64_value(usage.get("total_tokens")).unwrap_or(input + cached + output + reasoning);

    Some(TokenBreakdown {
        input_tokens: input + cached,
        cached_input_tokens: cached,
        output_tokens: output,
        reasoning_output_tokens: reasoning,
        total_tokens: total,
    })
}

fn codex_string_value(value: Option<&serde_json::Value>) -> Option<String> {
    value.and_then(|v| {
        if let Some(s) = v.as_str() {
            if !s.is_empty() {
                Some(s.to_string())
            } else {
                None
            }
        } else {
            v.as_number().map(|n| n.to_string())
        }
    })
}

fn codex_i64_value(value: Option<&serde_json::Value>) -> Option<i64> {
    value.and_then(|v| {
        if let Some(n) = v.as_i64() {
            Some(n)
        } else if let Some(s) = v.as_str() {
            s.parse().ok()
        } else {
            None
        }
    })
}

fn codex_date_value(value: Option<&serde_json::Value>) -> Option<DateTime<Utc>> {
    value.and_then(|v| {
        if let Some(s) = v.as_str() {
            s.parse::<DateTime<Utc>>().ok()
        } else if let Some(n) = v.as_f64() {
            let seconds = if n > 10_000_000_000.0 { n / 1000.0 } else { n };
            DateTime::from_timestamp(seconds as i64, 0)
        } else {
            None
        }
    })
}

fn make_local_usage_from_codex(
    summaries: Vec<CodexTranscriptSummary>,
    metadata: HashMap<String, CodexThreadMetadata>,
    now: DateTime<Utc>,
) -> Option<LocalUsage> {
    let common_summaries: Vec<SessionSummary> = summaries
        .into_iter()
        .map(|s| {
            let key = Path::new(&s.file_path)
                .file_name()
                .map(|n| n.to_string_lossy().to_string())
                .unwrap_or_else(|| s.session_id.clone());
            let meta = metadata.get(&key);

            let project_path = meta
                .and_then(|m| m.cwd.as_ref())
                .filter(|p| !p.is_empty())
                .cloned()
                .unwrap_or(s.project_path);
            let model = s.model.or_else(|| meta.and_then(|m| m.model.clone()));
            let last_active_at = match (s.last_active_at, meta.and_then(|m| m.updated_at)) {
                (Some(a), Some(b)) => Some(a.max(b)),
                (Some(a), None) => Some(a),
                (None, Some(b)) => Some(b),
                (None, None) => None,
            };

            SessionSummary {
                file_path: s.file_path,
                session_id: s.session_id,
                project_path: project_path.clone(),
                model,
                last_active_at,
                deltas: s
                    .deltas
                    .into_iter()
                    .map(|d| UsageDelta {
                        message_id: d.turn_id,
                        date: d.date,
                        tokens: d.tokens,
                        model: d.model,
                        project_path: project_path.clone(),
                        session_id: d.session_id,
                    })
                    .collect(),
                tool_calls: s.tool_calls,
                title: meta.and_then(|m| m.title.clone()),
                archived: meta.map(|m| m.archived).unwrap_or(false),
                git_branch: meta.and_then(|m| m.git_branch.clone()),
                git_origin_url: meta.and_then(|m| m.git_origin_url.clone()),
            }
        })
        .collect();
    make_local_usage(common_summaries, now)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::readers::CodexStateReader;

    #[tokio::test]
    async fn parses_codex_session_jsonl() {
        let temp = tempfile::tempdir().unwrap();
        let archived = temp.path().join("archived_sessions");
        tokio::fs::create_dir_all(&archived).await.unwrap();

        let session = archived.join("rollout-test.jsonl");
        let lines = vec![
            r#"{"timestamp":"2026-03-26T12:53:47.026Z","type":"session_meta","payload":{"id":"session-1","timestamp":"2026-03-26T12:53:36.076Z","cwd":"h:\\project\\demo","model_provider":"openai"}}"#,
            r#"{"timestamp":"2026-03-26T12:53:47.028Z","type":"turn_context","payload":{"turn_id":"turn-1","cwd":"h:\\project\\demo","model":"gpt-5.4"}}"#,
            r#"{"timestamp":"2026-03-26T12:53:47.164Z","type":"event_msg","payload":{"type":"token_count","turn_id":"turn-1","info":{"last_token_usage":{"input_tokens":100,"cached_input_tokens":50,"output_tokens":30,"reasoning_output_tokens":10,"total_tokens":190}}}}"#,
            r#"{"timestamp":"2026-03-26T12:54:00.000Z","type":"response_item","payload":{"type":"custom_tool_call","status":"completed","call_id":"call-1","name":"apply_patch","input":""}}"#,
        ];
        tokio::fs::write(&session, lines.join("\n")).await.unwrap();

        let cache = temp.path().join("cache");
        let reader = CodexTranscriptReader::new(&cache);
        let usage = reader
            .load_local_usage(temp.path(), Utc::now())
            .await
            .unwrap()
            .expect("should produce LocalUsage");

        assert_eq!(usage.thread_count, 1);
        assert_eq!(usage.lifetime_tokens, 190);
        assert_eq!(usage.project_board.as_ref().unwrap().all_projects.len(), 1);
        assert_eq!(usage.tool_usages.len(), 1);
        assert_eq!(usage.tool_usages[0].name, "apply_patch");
        assert_eq!(usage.tool_usages[0].call_count, 1);

        let detailed = usage.detailed_usage.unwrap();
        assert_eq!(detailed.parsed_file_count, 1);
        assert_eq!(detailed.token_event_count, 1);
    }

    #[tokio::test]
    async fn uses_last_token_usage_not_cumulative_total() {
        let temp = tempfile::tempdir().unwrap();
        let archived = temp.path().join("archived_sessions");
        tokio::fs::create_dir_all(&archived).await.unwrap();

        let session = archived.join("rollout-cumulative.jsonl");
        let lines = vec![
            r#"{"timestamp":"2026-03-26T12:53:47.026Z","type":"session_meta","payload":{"id":"session-c","cwd":"/tmp","model_provider":"openai"}}"#,
            r#"{"timestamp":"2026-03-26T12:53:48.000Z","type":"event_msg","payload":{"type":"token_count","turn_id":"turn-1","info":{"last_token_usage":{"input_tokens":100,"cached_input_tokens":0,"output_tokens":50,"reasoning_output_tokens":0,"total_tokens":150},"total_token_usage":{"input_tokens":100,"cached_input_tokens":0,"output_tokens":50,"reasoning_output_tokens":0,"total_tokens":150}}}}"#,
            r#"{"timestamp":"2026-03-26T12:53:49.000Z","type":"event_msg","payload":{"type":"token_count","turn_id":"turn-2","info":{"last_token_usage":{"input_tokens":50,"cached_input_tokens":0,"output_tokens":25,"reasoning_output_tokens":0,"total_tokens":75},"total_token_usage":{"input_tokens":150,"cached_input_tokens":0,"output_tokens":75,"reasoning_output_tokens":0,"total_tokens":225}}}}"#,
        ];
        tokio::fs::write(&session, lines.join("\n")).await.unwrap();

        let cache = temp.path().join("cache");
        let reader = CodexTranscriptReader::new(&cache);
        let usage = reader
            .load_local_usage(temp.path(), Utc::now())
            .await
            .unwrap()
            .expect("should produce LocalUsage");

        // Should sum last_token_usage deltas (150 + 75 = 225), not total_token_usage totals.
        assert_eq!(usage.lifetime_tokens, 225);
    }

    #[tokio::test]
    async fn enriches_session_with_state_metadata() {
        let temp = tempfile::tempdir().unwrap();
        let archived = temp.path().join("archived_sessions");
        tokio::fs::create_dir_all(&archived).await.unwrap();

        let session = archived.join("rollout-test.jsonl");
        let lines = vec![
            r#"{"timestamp":"2026-03-26T12:53:47.164Z","type":"event_msg","payload":{"type":"token_count","turn_id":"turn-1","info":{"last_token_usage":{"input_tokens":100,"cached_input_tokens":0,"output_tokens":50,"reasoning_output_tokens":0,"total_tokens":150}}}}"#,
        ];
        tokio::fs::write(&session, lines.join("\n")).await.unwrap();

        let db_path = temp.path().join("state_5.sqlite");
        create_test_state_db(
            &db_path,
            "rollout-test.jsonl",
            "Test Thread Title",
            "h:\\project\\demo",
            "gpt-5.4",
            true,
        );

        let metadata = CodexStateReader::new(&db_path)
            .load_metadata()
            .await
            .unwrap();
        assert_eq!(metadata.len(), 1);

        let cache = temp.path().join("cache");
        let reader = CodexTranscriptReader::new(&cache);
        let usage = reader
            .load_local_usage_with_metadata(temp.path(), metadata, Utc::now())
            .await
            .unwrap()
            .expect("should produce LocalUsage");

        assert_eq!(usage.recent_threads.len(), 1);
        let thread = &usage.recent_threads[0];
        assert_eq!(thread.title, "Test Thread Title");
        assert_eq!(thread.cwd, "h:\\project\\demo");
        assert_eq!(thread.model.as_deref(), Some("gpt-5.4"));
        assert!(thread.archived);

        let projects = &usage.project_board.as_ref().unwrap().all_projects;
        assert_eq!(projects[0].full_path, "h:\\project\\demo");
    }

    #[tokio::test]
    async fn falls_back_to_short_path_when_title_missing() {
        let temp = tempfile::tempdir().unwrap();
        let archived = temp.path().join("archived_sessions");
        tokio::fs::create_dir_all(&archived).await.unwrap();

        let session = archived.join("rollout-test.jsonl");
        let lines = vec![
            r#"{"timestamp":"2026-03-26T12:53:47.164Z","type":"event_msg","payload":{"type":"token_count","turn_id":"turn-1","info":{"last_token_usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":5,"reasoning_output_tokens":0,"total_tokens":15}}}}"#,
        ];
        tokio::fs::write(&session, lines.join("\n")).await.unwrap();

        let db_path = temp.path().join("state_5.sqlite");
        create_test_state_db(
            &db_path,
            "rollout-test.jsonl",
            "",
            "h:\\project\\demo",
            "",
            false,
        );

        let metadata = CodexStateReader::new(&db_path)
            .load_metadata()
            .await
            .unwrap();

        let cache = temp.path().join("cache");
        let reader = CodexTranscriptReader::new(&cache);
        let usage = reader
            .load_local_usage_with_metadata(temp.path(), metadata, Utc::now())
            .await
            .unwrap()
            .expect("should produce LocalUsage");

        assert_eq!(usage.recent_threads[0].title, "demo");
    }

    fn create_test_state_db(
        path: &std::path::Path,
        rollout_filename: &str,
        title: &str,
        cwd: &str,
        model: &str,
        archived: bool,
    ) {
        use rusqlite::Connection;
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
                model, created_at_ms, updated_at_ms
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14)",
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
                archived as i64,
                if model.is_empty() { None::<String> } else { Some(model.to_string()) },
                1711434827000i64,
                1711434827000i64,
            ],
        )
        .unwrap();
    }
}
