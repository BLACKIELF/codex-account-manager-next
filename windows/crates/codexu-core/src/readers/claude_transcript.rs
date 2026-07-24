//! Claude Code transcript reader.
//!
//! Translates the Swift `ClaudeCodeRuntimeProvider` logic to Rust.
//! Reads `~/.claude/projects/**/*.jsonl` on any platform and produces `LocalUsage`.

use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};

use chrono::{DateTime, Datelike, TimeZone, Utc};
use serde::{Deserialize, Serialize};

use crate::models::*;

const MAX_CACHE_BYTES: u64 = 128 * 1024 * 1024;
const MAX_LINE_BYTES: usize = 4 * 1024 * 1024;
const READ_CHUNK_BYTES: usize = 64 * 1024;
const CACHE_VERSION: i32 = 2;

/// A fingerprint for a transcript file.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct FileFingerprint {
    pub file_size: i64,
    pub modification_time_ns: Option<i64>,
}

/// A cached summary for a single transcript file.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ClaudeSessionCacheEntry {
    pub file_size: i64,
    pub modification_time_ns: Option<i64>,
    pub summary: ClaudeTranscriptSummary,
}

impl ClaudeSessionCacheEntry {
    pub fn matches(&self, fingerprint: &FileFingerprint) -> bool {
        self.file_size == fingerprint.file_size
            && self.modification_time_ns == fingerprint.modification_time_ns
    }
}

/// On-disk cache for Claude transcript summaries.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ClaudeSessionDiskCache {
    pub version: i32,
    pub entries: HashMap<String, ClaudeSessionCacheEntry>,
}

/// A single usage delta extracted from a transcript.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ClaudeUsageDelta {
    pub message_id: Option<String>,
    #[serde(with = "chrono::serde::ts_milliseconds")]
    pub date: DateTime<Utc>,
    pub tokens: TokenBreakdown,
    pub model: Option<String>,
    pub project_path: String,
    pub session_id: String,
}

/// A skill load event.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ClaudeSkillLoad {
    pub name: String,
    pub path: Option<String>,
    #[serde(with = "chrono::serde::ts_milliseconds_option")]
    pub date: Option<DateTime<Utc>>,
}

/// Summary of a single Claude transcript file.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ClaudeTranscriptSummary {
    pub file_path: String,
    pub session_id: String,
    pub project_path: String,
    pub model: Option<String>,
    #[serde(with = "chrono::serde::ts_milliseconds_option")]
    pub last_active_at: Option<DateTime<Utc>>,
    pub deltas: Vec<ClaudeUsageDelta>,
    pub tool_calls: HashMap<String, i64>,
    pub skill_loads: Vec<ClaudeSkillLoad>,
}

/// Reads Claude Code transcripts and produces `LocalUsage`.
pub struct ClaudeCodeTranscriptReader {
    cache_dir: PathBuf,
}

impl ClaudeCodeTranscriptReader {
    pub fn new(cache_dir: impl AsRef<Path>) -> Self {
        Self {
            cache_dir: cache_dir.as_ref().to_path_buf(),
        }
    }

    pub async fn load_local_usage(
        &self,
        projects_root: impl AsRef<Path>,
        now: DateTime<Utc>,
    ) -> anyhow::Result<Option<LocalUsage>> {
        let projects_root = projects_root.as_ref();
        if !tokio::fs::try_exists(projects_root).await.unwrap_or(false) {
            return Ok(None);
        }

        let files = enumerate_jsonl_files(projects_root).await;
        if files.is_empty() {
            return Ok(None);
        }

        let mut cache = self.read_cache().await;
        let live_paths: HashSet<String> = files.iter().map(|f| f.to_string_lossy().to_string()).collect();
        cache.entries.retain(|k, _| live_paths.contains(k));

        let mut summaries = Vec::new();
        for file in files {
            let fingerprint = fingerprint_for(&file).await;
            let key = file.to_string_lossy().to_string();

            if let Some(entry) = cache.entries.get(&key) {
                if let Some(fp) = fingerprint {
                    if entry.matches(&fp) {
                        summaries.push(entry.summary.clone());
                        continue;
                    }
                }
            }

            let summary = parse_transcript(&file, fingerprint.as_ref()).await;
            if let Some(fp) = fingerprint {
                cache.entries.insert(
                    key,
                    ClaudeSessionCacheEntry {
                        file_size: fp.file_size,
                        modification_time_ns: fp.modification_time_ns,
                        summary: summary.clone(),
                    },
                );
            }
            summaries.push(summary);
        }

        self.write_cache(&cache).await;
        Ok(make_local_usage(summaries, now))
    }

    async fn read_cache(&self) -> ClaudeSessionDiskCache {
        let path = self.cache_dir.join("claude-code").join("session-usage-v1.json");
        match tokio::fs::metadata(&path).await {
            Ok(meta) if meta.len() <= MAX_CACHE_BYTES => {}
            _ => return ClaudeSessionDiskCache { version: CACHE_VERSION, entries: HashMap::new() },
        }
        match tokio::fs::read(&path).await {
            Ok(data) => match serde_json::from_slice::<ClaudeSessionDiskCache>(&data) {
                Ok(cache) if cache.version == CACHE_VERSION => cache,
                _ => ClaudeSessionDiskCache { version: CACHE_VERSION, entries: HashMap::new() },
            },
            _ => ClaudeSessionDiskCache { version: CACHE_VERSION, entries: HashMap::new() },
        }
    }

    async fn write_cache(
        &self, cache: &ClaudeSessionDiskCache) {
        let path = self.cache_dir.join("claude-code").join("session-usage-v1.json");
        if let Ok(data) = serde_json::to_vec(cache) {
            if data.len() as u64 <= MAX_CACHE_BYTES {
                let _ = tokio::fs::create_dir_all(path.parent().unwrap()).await;
                let _ = tokio::fs::write(&path, data).await;
            }
        }
    }
}

async fn enumerate_jsonl_files(root: &Path) -> Vec<PathBuf> {
    let mut files = Vec::new();
    let mut dirs = vec![root.to_path_buf()];
    while let Some(dir) = dirs.pop() {
        let mut entries = match tokio::fs::read_dir(&dir).await {
            Ok(entries) => entries,
            Err(_) => continue,
        };
        while let Ok(Some(entry)) = entries.next_entry().await {
            let path = entry.path();
            let file_type = match entry.file_type().await {
                Ok(ft) => ft,
                Err(_) => continue,
            };
            if file_type.is_dir() {
                if !path.file_name().map(|n| n.to_string_lossy().starts_with('.')).unwrap_or(false) {
                    dirs.push(path);
                }
            } else if file_type.is_file() {
                if path.extension().and_then(|e| e.to_str()) == Some("jsonl") {
                    files.push(path);
                }
            }
        }
    }
    files.sort();
    files
}

async fn fingerprint_for(path: &Path) -> Option<FileFingerprint> {
    let meta = tokio::fs::metadata(path).await.ok()?;
    let modified = meta.modified().ok()?;
    let duration = modified.duration_since(std::time::UNIX_EPOCH).ok()?;
    Some(FileFingerprint {
        file_size: meta.len() as i64,
        modification_time_ns: Some(duration.as_nanos() as i64),
    })
}

async fn parse_transcript(file: &Path, fingerprint: Option<&FileFingerprint>) -> ClaudeTranscriptSummary {
    let session_id = file
        .file_stem()
        .map(|s| s.to_string_lossy().to_string())
        .unwrap_or_default();
    let modification_date = fingerprint.and_then(|fp| {
        fp.modification_time_ns.map(|ns| Utc.timestamp_nanos(ns))
    });

    let mut summary = ClaudeTranscriptSummary {
        file_path: file.to_string_lossy().to_string(),
        session_id,
        project_path: infer_claude_project_path(file),
        model: None,
        last_active_at: modification_date,
        deltas: Vec::new(),
        tool_calls: HashMap::new(),
        skill_loads: Vec::new(),
    };

    let data = match tokio::fs::read(file).await {
        Ok(data) => data,
        Err(_) => return summary,
    };

    let mut seen_message_ids = HashSet::new();

    for line in data.split(|b| *b == b'\n') {
        if line.is_empty() || line.len() > MAX_LINE_BYTES {
            continue;
        }
        let text = match std::str::from_utf8(line) {
            Ok(text) => text,
            Err(_) => continue,
        };
        if !text.contains("\"usage\"") && !text.contains("\"tool_use\"") && !text.contains("attribution") {
            continue;
        }
        let object: serde_json::Value = match serde_json::from_str(text) {
            Ok(v) => v,
            Err(_) => continue,
        };

        let message = object.get("message");
        let timestamp = claude_date_value(object.get("timestamp"))
            .or(modification_date)
            .unwrap_or_else(Utc::now);
        let project_path = claude_string_value(object.get("cwd"))
            .or_else(|| claude_string_value(object.get("projectPath")))
            .unwrap_or_else(|| summary.project_path.clone());
        let model = claude_string_value(message.and_then(|m| m.get("model")))
            .or_else(|| claude_string_value(object.get("model")))
            .or_else(|| summary.model.clone());

        summary.project_path = project_path.clone();
        summary.model = model.clone();
        summary.last_active_at = summary.last_active_at.map(|d| d.max(timestamp)).or(Some(timestamp));

        if let Some(skill_name) = claude_string_value(object.get("attributionSkill"))
            .or_else(|| claude_string_value(object.get("attribution_skill")))
            .or_else(|| claude_string_value(message.and_then(|m| m.get("attributionSkill"))))
            .or_else(|| claude_string_value(message.and_then(|m| m.get("attribution_skill"))))
        {
            summary.skill_loads.push(ClaudeSkillLoad {
                name: skill_name,
                path: None,
                date: Some(timestamp),
            });
        }

        parse_tool_calls(message.and_then(|m| m.get("content")), timestamp, &mut summary);

        let usage = match message.and_then(|m| m.get("usage")) {
            Some(u) => u,
            None => continue,
        };
        let tokens = match parse_usage(usage) {
            Some(t) if !t.is_zero() => t,
            _ => continue,
        };

        let message_id = claude_string_value(message.and_then(|m| m.get("id")))
            .or_else(|| claude_string_value(object.get("uuid")))
            .or_else(|| claude_string_value(object.get("id")));
        if let Some(ref id) = message_id {
            if seen_message_ids.contains(id) {
                continue;
            }
            seen_message_ids.insert(id.clone());
        }

        summary.deltas.push(ClaudeUsageDelta {
            message_id,
            date: timestamp,
            tokens,
            model,
            project_path,
            session_id: summary.session_id.clone(),
        });
    }

    summary
}

fn parse_tool_calls(content: Option<&serde_json::Value>, date: DateTime<Utc>, summary: &mut ClaudeTranscriptSummary) {
    let items = match content.and_then(|c| c.as_array()) {
        Some(items) => items,
        None => return,
    };
    for item in items {
        let item_object = match item.as_object() {
            Some(o) => o,
            None => continue,
        };
        if claude_string_value(item_object.get("type")).as_deref() != Some("tool_use") {
            continue;
        }
        let name = match claude_string_value(item_object.get("name")) {
            Some(n) if !n.is_empty() => n,
            _ => continue,
        };
        *summary.tool_calls.entry(name.clone()).or_insert(0) += 1;
        if name.to_lowercase().contains("skill") {
            summary.skill_loads.push(ClaudeSkillLoad {
                name,
                path: None,
                date: Some(date),
            });
        }
    }
}

fn parse_usage(usage: &serde_json::Value) -> Option<TokenBreakdown> {
    let input = claude_i64_value(usage.get("input_tokens")).unwrap_or(0);
    let cache_creation = claude_i64_value(usage.get("cache_creation_input_tokens")).unwrap_or(0);
    let cache_read = claude_i64_value(usage.get("cache_read_input_tokens")).unwrap_or(0);
    let output = claude_i64_value(usage.get("output_tokens")).unwrap_or(0);
    let reasoning = claude_i64_value(usage.get("reasoning_output_tokens")).unwrap_or(0);
    let total = claude_i64_value(usage.get("total_tokens"))
        .unwrap_or(input + cache_creation + cache_read + output + reasoning);

    Some(TokenBreakdown {
        input_tokens: input + cache_creation + cache_read,
        cached_input_tokens: cache_creation + cache_read,
        output_tokens: output,
        reasoning_output_tokens: reasoning,
        total_tokens: total,
    })
}

fn infer_claude_project_path(file: &Path) -> String {
    let encoded = file
        .parent()
        .and_then(|p| p.file_name())
        .map(|s| s.to_string_lossy().to_string())
        .unwrap_or_default();
    if encoded.starts_with('-') {
        encoded.replacen('-', "/", 1)
    } else {
        encoded
    }
}

fn claude_string_value(value: Option<&serde_json::Value>) -> Option<String> {
    value.and_then(|v| {
        if let Some(s) = v.as_str() {
            if !s.is_empty() { Some(s.to_string()) } else { None }
        } else {
            v.as_number().map(|n| n.to_string())
        }
    })
}

fn claude_i64_value(value: Option<&serde_json::Value>) -> Option<i64> {
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

fn claude_date_value(value: Option<&serde_json::Value>) -> Option<DateTime<Utc>> {
    value.and_then(|v| {
        if let Some(n) = v.as_f64() {
            let seconds = if n > 10_000_000_000.0 { n / 1000.0 } else { n };
            Some(DateTime::from_timestamp(seconds as i64, 0).unwrap_or_else(Utc::now))
        } else if let Some(s) = v.as_str() {
            s.parse::<DateTime<Utc>>().ok()
        } else {
            None
        }
    })
}

fn make_local_usage(summaries: Vec<ClaudeTranscriptSummary>, now: DateTime<Utc>) -> Option<LocalUsage> {
    let mut unique_deltas: Vec<ClaudeUsageDelta> = Vec::new();
    let mut seen_message_ids = HashSet::new();
    for delta in summaries.iter().flat_map(|s| s.deltas.iter()) {
        if let Some(ref id) = delta.message_id {
            if seen_message_ids.contains(id) {
                continue;
            }
            seen_message_ids.insert(id.clone());
        }
        unique_deltas.push(delta.clone());
    }

    if unique_deltas.is_empty() {
        return None;
    }

    unique_deltas.sort_by(|a, b| a.date.cmp(&b.date));

    let day_start = Utc.with_ymd_and_hms(now.year(), now.month(), now.day(), 0, 0, 0).unwrap();
    let seven_day_start = day_start - chrono::Duration::days(6);
    let previous_seven_day_start = day_start - chrono::Duration::days(13);
    let month_start = Utc.with_ymd_and_hms(now.year(), now.month(), 1, 0, 0, 0).unwrap();

    let mut today = PricedTokenUsage::ZERO;
    let mut seven_day = PricedTokenUsage::ZERO;
    let mut previous_seven_day = PricedTokenUsage::ZERO;
    let mut month = PricedTokenUsage::ZERO;
    let mut lifetime = PricedTokenUsage::ZERO;
    let mut daily_usage: HashMap<String, (DateTime<Utc>, PricedTokenUsage)> = HashMap::new();
    let mut projects: HashMap<String, ClaudeProjectAccumulator> = HashMap::new();

    for delta in &unique_deltas {
        let cost = claude_estimated_cost_usd(&delta.tokens, delta.model.as_deref());
        lifetime.add_tokens(&delta.tokens, cost);
        if delta.date >= month_start {
            month.add_tokens(&delta.tokens, cost);
        }
        if delta.date >= seven_day_start {
            seven_day.add_tokens(&delta.tokens, cost);
        }
        if delta.date >= previous_seven_day_start && delta.date < seven_day_start {
            previous_seven_day.add_tokens(&delta.tokens, cost);
        }
        if delta.date >= day_start {
            today.add_tokens(&delta.tokens, cost);
        }

        let bucket_date = Utc.with_ymd_and_hms(delta.date.year(), delta.date.month(), delta.date.day(), 0, 0, 0).unwrap();
        let key = bucket_date.format("%Y-%m-%d").to_string();
        let entry = daily_usage.entry(key).or_insert_with(|| (bucket_date, PricedTokenUsage::ZERO));
        entry.1.add_tokens(&delta.tokens, cost);

        let project_path = if delta.project_path.is_empty() {
            "Claude Code".to_string()
        } else {
            delta.project_path.clone()
        };
        let acc = projects.entry(project_path.clone()).or_insert_with(|| ClaudeProjectAccumulator {
            path: project_path.clone(),
            ..Default::default()
        });
        acc.add(delta, cost);
    }

    let daily_buckets = make_seven_day_buckets(&daily_usage, now);
    let usage_trend = make_usage_trend(&daily_usage, &seven_day, &previous_seven_day, &month, now);

    let detailed = DetailedUsage {
        today: today.clone(),
        seven_day: seven_day.clone(),
        month: month.clone(),
        lifetime: lifetime.clone(),
        parsed_file_count: summaries.len() as i64,
        token_event_count: unique_deltas.len() as i64,
    };

    let mut project_usages: Vec<ProjectUsage> = projects.values().map(|p| p.make_project()).collect();
    project_usages.sort_by(|a, b| {
        if a.tokens != b.tokens {
            b.tokens.cmp(&a.tokens)
        } else {
            b.last_active_at.cmp(&a.last_active_at)
        }
    });

    let recent_threads: Vec<LocalThread> = summaries
        .iter()
        .map(|s| {
            let tokens = s.deltas.iter().map(|d| d.tokens.visible_total_tokens()).sum();
            LocalThread {
                id: s.session_id.clone(),
                title: short_workspace_name(&s.project_path),
                tokens,
                updated_at: s.last_active_at,
                model: s.model.clone(),
                cwd: s.project_path.clone(),
                archived: false,
            }
        })
        .collect();

    let tool_usages = make_tool_usages(&summaries, &lifetime);

    Some(LocalUsage {
        lifetime_tokens: lifetime.tokens.visible_total_tokens(),
        today_tokens: today.tokens.visible_total_tokens(),
        seven_day_tokens: seven_day.tokens.visible_total_tokens(),
        thread_count: summaries.len().max(1) as i64,
        last_updated_at: summaries.iter().filter_map(|s| s.last_active_at).max(),
        daily_buckets,
        recent_threads,
        detailed_usage: Some(detailed),
        usage_trend: Some(usage_trend),
        project_board: Some(ProjectBoard {
            recent_projects: project_usages.iter().take(8).cloned().collect(),
            all_projects: project_usages,
        }),
        tool_usages,
        skill_usages: Vec::new(), // TODO: implement skill resolver
    })
}

fn make_seven_day_buckets(
    daily_usage: &HashMap<String, (DateTime<Utc>, PricedTokenUsage)>,
    now: DateTime<Utc>,
) -> Vec<DailyTokenBucket> {
    let start = now - chrono::Duration::days(6);
    (0..7)
        .filter_map(|offset| {
            let date = start + chrono::Duration::days(offset);
            let date = Utc.with_ymd_and_hms(date.year(), date.month(), date.day(), 0, 0, 0).unwrap();
            let key = date.format("%Y-%m-%d").to_string();
            Some(DailyTokenBucket {
                id: key.clone(),
                label: date.format("%a").to_string(),
                tokens: daily_usage.get(&key).map(|(_, u)| u.tokens.visible_total_tokens()).unwrap_or(0),
            })
        })
        .collect()
}

fn make_usage_trend(
    daily_usage: &HashMap<String, (DateTime<Utc>, PricedTokenUsage)>,
    seven_day: &PricedTokenUsage,
    previous_seven_day: &PricedTokenUsage,
    month: &PricedTokenUsage,
    now: DateTime<Utc>,
) -> UsageTrend {
    let start = now - chrono::Duration::days(179);
    let mut buckets = Vec::new();
    let mut heatmap_days = Vec::new();

    for offset in 0..180 {
        let date = start + chrono::Duration::days(offset);
        let date = Utc.with_ymd_and_hms(date.year(), date.month(), date.day(), 0, 0, 0).unwrap();
        let key = date.format("%Y-%m-%d").to_string();
        let usage = daily_usage.get(&key).map(|(_, u)| u.clone()).unwrap_or_default();
        buckets.push(UsageDayBucket {
            id: key,
            date,
            usage: usage.clone(),
            source_quality: UsageSourceQuality::Detailed,
        });
        heatmap_days.push(UsageHeatmapDay {
            id: date.format("%Y-%m-%d").to_string(),
            date,
            usage: if usage.tokens.visible_total_tokens() > 0 { Some(usage) } else { None },
            is_future: date > now,
        });
    }

    let active_buckets: Vec<UsageDayBucket> = buckets.iter().filter(|b| b.tokens() > 0).cloned().collect();
    let peak = active_buckets.iter().max_by_key(|b| b.tokens()).cloned();
    let active_day_count = active_buckets.len() as i64;
    let previous_tokens = previous_seven_day.tokens.visible_total_tokens();
    let current_tokens = seven_day.tokens.visible_total_tokens();
    let change_percent = if previous_tokens > 0 {
        Some(((current_tokens - previous_tokens) as f64 / previous_tokens as f64) * 100.0)
    } else {
        None
    };

    let summary = UsageTrendSummary {
        seven_day: seven_day.clone(),
        daily_average_tokens: current_tokens / 7,
        peak_day: peak,
        change_percent,
        is_new_activity: previous_tokens == 0 && current_tokens > 0,
    };

    let mut thresholds = make_heatmap_thresholds(active_buckets.iter().map(|b| b.tokens()).collect());
    if thresholds.is_empty() {
        thresholds = vec![1, 10, 100, 1000];
    }

    let heatmap_weeks: Vec<Vec<_>> = heatmap_days.chunks(7).map(|c| c.to_vec()).collect();

    UsageTrend {
        day_buckets: buckets,
        heatmap_weeks,
        heatmap_thresholds: thresholds,
        summary,
        model_trends: None,
        month: month.clone(),
        projected_month_cost_usd: projected_month_cost(month.estimated_cost_usd, now),
        active_day_count,
        source_quality: UsageSourceQuality::Detailed,
    }
}

fn make_heatmap_thresholds(tokens: Vec<i64>) -> Vec<i64> {
    let mut sorted: Vec<i64> = tokens.into_iter().filter(|t| *t > 0).collect();
    if sorted.is_empty() {
        return Vec::new();
    }
    sorted.sort();

    fn percentile(sorted: &[std::sync::Arc<i64>], p: f64) -> i64 {
        let index = ((sorted.len() - 1) as f64 * p).round() as usize;
        let index = index.min(sorted.len() - 1);
        *sorted[index]
    }

    // Simplified: use direct indexing
    vec![
        sorted[(sorted.len() - 1) * 25 / 100].max(1),
        sorted[(sorted.len() - 1) * 50 / 100].max(1),
        sorted[(sorted.len() - 1) * 75 / 100].max(1),
        sorted[(sorted.len() - 1) * 95 / 100].max(1),
    ]
}

fn projected_month_cost(month_cost: f64, now: DateTime<Utc>) -> Option<f64> {
    let day = now.day();
    let _days_in_month = now.format("%d").to_string().parse::<u32>().unwrap_or(30);
    // Approximate days in month
    let days_in_month = match now.month() {
        1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
        2 => if now.year() % 4 == 0 { 29 } else { 28 },
        _ => 30,
    };
    if day == 0 || day > days_in_month as u32 {
        return None;
    }
    Some(month_cost / day as f64 * days_in_month as f64)
}

fn make_tool_usages(summaries: &[ClaudeTranscriptSummary], lifetime: &PricedTokenUsage) -> Vec<ToolUsage> {
    let mut calls: HashMap<String, i64> = HashMap::new();
    for summary in summaries {
        for (name, count) in &summary.tool_calls {
            *calls.entry(name.clone()).or_insert(0) += count;
        }
    }

    let total_calls: i64 = calls.values().sum();
    let total_calls = total_calls.max(1);
    let tokens_per_call = lifetime.tokens.visible_total_tokens() / total_calls;
    let cost_per_call = lifetime.estimated_cost_usd / total_calls as f64;

    let mut usages: Vec<ToolUsage> = calls
        .into_iter()
        .map(|(name, count)| ToolUsage {
            id: name.clone(),
            name: name.clone(),
            category: tool_category(&name),
            call_count: count,
            estimated_tokens: if tokens_per_call > 0 { Some(tokens_per_call * count) } else { None },
            estimated_cost_usd: if cost_per_call > 0.0 { Some(cost_per_call * count as f64) } else { None },
        })
        .collect();
    usages.sort_by(|a, b| b.call_count.cmp(&a.call_count));
    usages
}

fn tool_category(name: &str) -> String {
    let normalized = name.to_lowercase();
    if normalized.contains("bash") || normalized.contains("shell") || normalized.contains("terminal") {
        "terminal".to_string()
    } else if normalized.contains("edit") || normalized.contains("write") || normalized.contains("patch") {
        "edit".to_string()
    } else if normalized.contains("read") || normalized.contains("grep") || normalized.contains("glob") {
        "docs".to_string()
    } else if normalized.contains("web") || normalized.contains("browser") || normalized.contains("fetch") {
        "browser".to_string()
    } else if normalized.contains("task") || normalized.contains("agent") || normalized.contains("todo") {
        "planning".to_string()
    } else if normalized.contains("mcp") {
        "mcp".to_string()
    } else {
        "tool".to_string()
    }
}

fn short_workspace_name(path: &str) -> String {
    let trimmed = path.trim_matches('/');
    trimmed.split('/').last().unwrap_or(path).to_string()
}

fn claude_estimated_cost_usd(tokens: &TokenBreakdown, model: Option<&str>) -> f64 {
    let price = match model {
        Some(m) if m.to_lowercase().contains("opus") => Some((15.0, 1.5, 75.0)),
        Some(m) if m.to_lowercase().contains("sonnet") => Some((3.0, 0.3, 15.0)),
        Some(m) if m.to_lowercase().contains("haiku") => Some((0.8, 0.08, 4.0)),
        _ => None,
    };
    let Some((input_price, cached_price, output_price)) = price else {
        return 0.0;
    };
    let uncached_cost = tokens.uncached_input_tokens() as f64 / 1_000_000.0 * input_price;
    let cached_cost = tokens.billable_cached_input_tokens() as f64 / 1_000_000.0 * cached_price;
    let output_cost = tokens.output_tokens.max(0) as f64 / 1_000_000.0 * output_price;
    uncached_cost + cached_cost + output_cost
}

#[derive(Debug, Default)]
struct ClaudeProjectAccumulator {
    path: String,
    tokens: TokenBreakdown,
    estimated_cost_usd: f64,
    session_ids: HashSet<String>,
    last_active_at: Option<DateTime<Utc>>,
}

impl ClaudeProjectAccumulator {
    fn add(&mut self, delta: &ClaudeUsageDelta, cost_usd: f64) {
        self.tokens.add(&delta.tokens);
        self.estimated_cost_usd += cost_usd;
        self.session_ids.insert(delta.session_id.clone());
        self.last_active_at = self.last_active_at.map(|d| d.max(delta.date)).or(Some(delta.date));
    }

    fn make_project(&self) -> ProjectUsage {
        ProjectUsage {
            id: self.path.clone(),
            name: short_workspace_name(&self.path),
            full_path: self.path.clone(),
            tokens: self.tokens.visible_total_tokens(),
            estimated_cost_usd: if self.estimated_cost_usd > 0.0 { Some(self.estimated_cost_usd) } else { None },
            thread_count: self.session_ids.len().max(1) as i64,
            last_active_at: self.last_active_at,
            source_quality: UsageSourceQuality::Detailed,
        }
    }
}

// Re-attach methods needed by make_usage_trend
impl UsageDayBucket {
    fn tokens(&self) -> i64 {
        self.usage.tokens.visible_total_tokens()
    }
}
