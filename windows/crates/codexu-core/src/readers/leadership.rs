use std::collections::{HashMap, HashSet};

use chrono::{offset::LocalResult, DateTime, Duration, Local, NaiveDate, NaiveTime, TimeZone, Utc};

use crate::models::*;
use crate::readers::common::{CodexTaskInterval, SessionSummary};

/// Build a leadership snapshot from parsed session summaries.
pub fn build_leadership_snapshot(
    sessions: &[SessionSummary],
    now: DateTime<Utc>,
) -> LeadershipDashboardSnapshot {
    let statistics_tz = LeadershipStatisticsTimezone::Local;
    build_leadership_snapshot_with_timezone(sessions, now, statistics_tz)
}

/// Build a leadership snapshot with an explicit local statistics boundary.
/// This supports timezone-aware day bucketing in period metrics.
#[derive(Debug, Clone, Copy)]
pub enum LeadershipStatisticsTimezone {
    Local,
    Named(chrono_tz::Tz),
}

pub fn build_leadership_snapshot_with_timezone(
    sessions: &[SessionSummary],
    now: DateTime<Utc>,
    statistics_tz: LeadershipStatisticsTimezone,
) -> LeadershipDashboardSnapshot {
    let workers = deduplicate_workers(sessions.iter().map(make_worker).collect());
    let intervals = build_intervals(sessions, &workers, now);
    let periods = [
        ("today".to_string(), 1i64),
        ("sevenDays".to_string(), 7),
        ("twentyEightDays".to_string(), 28),
    ];

    LeadershipDashboardSnapshot {
        model_version: "1.4-real".to_string(),
        refreshed_at: now,
        reports: periods
            .into_iter()
            .map(|(period, days)| {
                build_report(period, &workers, &intervals, now, days, statistics_tz)
            })
            .collect(),
    }
}

fn make_worker(session: &SessionSummary) -> LeadershipWorker {
    let (kind, automation_id, _) = classify_worker_kind(session);
    LeadershipWorker {
        id: build_worker_id("codex", kind, &session.session_id, automation_id.as_deref()),
        runtime: "codex".to_string(),
        kind,
        project_id: project_id(&session.project_path),
        project_name: project_name(&session.project_path),
        parent_id: session
            .parent_thread_id
            .as_ref()
            .map(|id| format!("codex:main:{id}")),
    }
}

fn build_intervals(
    sessions: &[SessionSummary],
    workers: &[LeadershipWorker],
    now: DateTime<Utc>,
) -> Vec<LeadershipInterval> {
    let worker_map = workers
        .iter()
        .map(|worker| (worker.id.clone(), worker.clone()))
        .collect::<HashMap<_, _>>();

    sessions
        .iter()
        .flat_map(|session| {
            let (kind, automation_id, has_factual_source) = classify_worker_kind(session);
            let worker_id =
                build_worker_id("codex", kind, &session.session_id, automation_id.as_deref());
            let worker = worker_map
                .get(&worker_id)
                .cloned()
                .unwrap_or_else(|| make_worker(session));
            let project_id = project_id(&session.project_path);

            session.task_intervals.iter().filter_map(move |interval| {
                if interval.ended_at <= interval.started_at {
                    return None;
                }
                let mut quality = interval.quality;
                if !interval_has_factual_timing(session.created_at, interval, now)
                    || !has_factual_source
                {
                    quality = LeadershipEvidenceQuality::Estimated;
                } else if kind == LeadershipWorkerKind::Automation && automation_id.is_none() {
                    quality = LeadershipEvidenceQuality::Derived;
                }
                Some(LeadershipInterval {
                    id: format!(
                        "{}:{}",
                        session.session_id,
                        interval
                            .turn_id
                            .clone()
                            .unwrap_or_else(|| interval.started_at.timestamp_millis().to_string())
                    ),
                    worker_id: worker.id.clone(),
                    runtime: "codex".to_string(),
                    worker_kind: worker.kind,
                    project_id: project_id.clone(),
                    start_at: interval.started_at,
                    end_at: interval.ended_at,
                    quality,
                    is_autonomous: matches!(
                        worker.kind,
                        LeadershipWorkerKind::Subagent | LeadershipWorkerKind::Automation
                    ),
                })
            })
        })
        .collect()
}

fn build_report(
    period: String,
    workers: &[LeadershipWorker],
    intervals: &[LeadershipInterval],
    now: DateTime<Utc>,
    day_count: i64,
    statistics_tz: LeadershipStatisticsTimezone,
) -> LeadershipReport {
    let start = statistics_tz.days_before_start(now, day_count - 1);

    let mut period_intervals = intervals
        .iter()
        .filter(|interval| {
            interval.quality.is_scorable() && interval.end_at > start && interval.start_at < now
        })
        .filter_map(|interval| clip_interval(interval, start, now))
        .collect::<Vec<_>>();

    period_intervals = merge_intervals(period_intervals);
    let mut daily_points = build_daily_points(&period_intervals, start, now, statistics_tz);
    let active_worker_ids = period_intervals
        .iter()
        .map(|interval| interval.worker_id.clone())
        .collect::<HashSet<_>>();
    let active_workers = workers
        .iter()
        .filter(|worker| active_worker_ids.contains(&worker.id))
        .cloned()
        .collect::<Vec<_>>();

    let active_day_count = daily_points
        .iter()
        .filter(|point| {
            point.ai_hours >= 0.25
                || (point.agent_count > 0
                    && day_has_autonomous(point.day, &period_intervals, statistics_tz))
        })
        .count() as i64;

    let metrics = timeline_metrics(&period_intervals);
    let ai_seconds = period_intervals.iter().map(duration_seconds).sum::<f64>();
    let ai_hours = ai_seconds / 3600.0;
    let autonomous_seconds = period_intervals
        .iter()
        .filter(|interval| interval.is_autonomous)
        .map(duration_seconds)
        .sum::<f64>();
    let autonomous_hours = autonomous_seconds / 3600.0;
    let delegated_seconds = period_intervals
        .iter()
        .filter(|interval| interval.worker_kind == LeadershipWorkerKind::Subagent)
        .map(duration_seconds)
        .sum::<f64>();
    let longest_autonomous_hours = period_intervals
        .iter()
        .filter(|interval| interval.is_autonomous)
        .map(duration_seconds)
        .max_by(f64::total_cmp)
        .map(|seconds| seconds / 3600.0)
        .unwrap_or(0.0);

    let autonomous_day_count = period_intervals
        .iter()
        .filter(|interval| interval.is_autonomous)
        .map(|interval| statistics_tz.day_start(interval.start_at))
        .collect::<HashSet<_>>()
        .len() as f64;
    let daily_ai_hours = if active_day_count > 0 {
        ai_hours / active_day_count as f64
    } else {
        0.0
    };

    let delegated_share = if ai_seconds > 0.0 {
        delegated_seconds / ai_seconds
    } else {
        0.0
    };
    let autonomous_share = if ai_seconds > 0.0 {
        autonomous_seconds / ai_seconds
    } else {
        0.0
    };
    let parallel_share = if metrics.active_window > 0.0 {
        metrics.parallel_window / metrics.active_window
    } else {
        0.0
    };
    let multi_project_share = if metrics.active_window > 0.0 {
        metrics.multi_project_window / metrics.active_window
    } else {
        0.0
    };
    let confidence = duration_weighted_confidence(&period_intervals);
    let autonomous_day_share = if active_day_count > 0 {
        autonomous_day_count / active_day_count as f64
    } else {
        0.0
    };
    let effective_workers = active_workers_effective_hours(&period_intervals);

    let dimensions = if active_day_count > 0 {
        build_dimensions(
            effective_workers,
            metrics.peak_concurrency,
            daily_ai_hours,
            metrics.average_parallelism,
            delegated_share,
            parallel_share,
            multi_project_share,
            autonomous_share,
            longest_autonomous_hours,
            autonomous_day_share,
            confidence,
        )
    } else {
        Vec::new()
    };
    let evidence_coverage = dimensions
        .iter()
        .map(|dimension| dimension.kind.weight() * dimension.confidence)
        .sum::<f64>();
    let final_score = finalize_score(&dimensions, active_day_count, evidence_coverage);

    LeadershipReport {
        period,
        score: final_score.map(|(score, _)| score),
        core_score: final_score.map(|(_, core)| core),
        title: final_score.map(|(score, _)| build_title(score)),
        dimensions,
        maturity: maturity(active_day_count),
        evidence_coverage,
        active_day_count,
        agent_count: if period_intervals.is_empty() {
            None
        } else {
            Some(active_workers.len() as i64)
        },
        ai_hours: if period_intervals.is_empty() {
            None
        } else {
            Some(ai_hours)
        },
        autonomous_hours: if period_intervals.is_empty() {
            None
        } else {
            Some(autonomous_hours)
        },
        average_parallelism: if period_intervals.is_empty() {
            None
        } else {
            Some(metrics.average_parallelism)
        },
        peak_concurrency: if period_intervals.is_empty() {
            None
        } else {
            Some(metrics.peak_concurrency)
        },
        project_count: period_intervals
            .iter()
            .map(|interval| interval.project_id.clone())
            .collect::<HashSet<_>>()
            .len() as i64,
        daily_points: {
            daily_points.sort_by(|left, right| left.day.cmp(&right.day));
            daily_points
        },
        projects: project_contributions(&active_workers, &period_intervals),
    }
}

fn classify_worker_kind(session: &SessionSummary) -> (LeadershipWorkerKind, Option<String>, bool) {
    match session.thread_source.as_deref() {
        Some("main") => (LeadershipWorkerKind::Main, None, true),
        Some("subagent") => (LeadershipWorkerKind::Subagent, None, true),
        Some("automation") => (
            LeadershipWorkerKind::Automation,
            extract_automation_id(session.title.as_deref()),
            true,
        ),
        Some(_) => (LeadershipWorkerKind::Main, None, false),
        None => (LeadershipWorkerKind::Main, None, false),
    }
}

fn interval_has_factual_timing(
    created_at: Option<DateTime<Utc>>,
    interval: &CodexTaskInterval,
    now: DateTime<Utc>,
) -> bool {
    let Some(created_at) = created_at else {
        return false;
    };
    if interval.ended_at > now + Duration::seconds(5) {
        return false;
    }
    interval.started_at >= created_at - Duration::seconds(2)
}

fn extract_automation_id(title: Option<&str>) -> Option<String> {
    let title = title.unwrap_or("");
    let marker = "Automation ID: ";
    let start = title.find(marker)?;
    let line = title[start + marker.len()..]
        .lines()
        .next()
        .unwrap_or("")
        .trim();
    if line.is_empty() {
        None
    } else {
        Some(line.to_string())
    }
}

fn build_worker_id(
    runtime: &str,
    kind: LeadershipWorkerKind,
    session_id: &str,
    automation_id: Option<&str>,
) -> String {
    match (kind, automation_id) {
        (LeadershipWorkerKind::Automation, Some(id)) => format!("{runtime}:automation:{id}"),
        (LeadershipWorkerKind::Automation, None) => format!("{runtime}:automation:{session_id}"),
        (LeadershipWorkerKind::Subagent, _) => format!("{runtime}:subagent:{session_id}"),
        _ => format!("{runtime}:main:{session_id}"),
    }
}

fn deduplicate_workers(mut workers: Vec<LeadershipWorker>) -> Vec<LeadershipWorker> {
    let mut deduplicated = HashMap::<String, LeadershipWorker>::new();
    for worker in workers.drain(..) {
        if let Some(existing) = deduplicated.get(&worker.id) {
            if existing.parent_id.is_some() {
                continue;
            }
        }
        deduplicated.insert(worker.id.clone(), worker);
    }
    deduplicated.into_values().collect()
}

fn clip_interval(
    interval: &LeadershipInterval,
    start: DateTime<Utc>,
    end: DateTime<Utc>,
) -> Option<LeadershipInterval> {
    let clipped_start = interval.start_at.max(start);
    let clipped_end = interval.end_at.min(end);
    if clipped_end <= clipped_start {
        return None;
    }
    Some(LeadershipInterval {
        id: interval.id.clone(),
        worker_id: interval.worker_id.clone(),
        runtime: interval.runtime.clone(),
        worker_kind: interval.worker_kind,
        project_id: interval.project_id.clone(),
        start_at: clipped_start,
        end_at: clipped_end,
        quality: interval.quality,
        is_autonomous: interval.is_autonomous,
    })
}

fn merge_intervals(mut intervals: Vec<LeadershipInterval>) -> Vec<LeadershipInterval> {
    let by_worker = intervals
        .drain(..)
        .fold(HashMap::new(), |mut acc, interval| {
            acc.entry(interval.worker_id.clone())
                .or_insert_with(Vec::new)
                .push(interval);
            acc
        });

    let mut merged: Vec<LeadershipInterval> = Vec::new();
    for mut group in by_worker.into_values() {
        group.sort_by_key(|interval| interval.start_at);
        let mut per_worker: Vec<LeadershipInterval> = Vec::new();
        for interval in group {
            if let Some(last) = per_worker.last_mut() {
                if interval.start_at <= last.end_at {
                    last.end_at = last.end_at.max(interval.end_at);
                    last.quality = lower_quality(last.quality, interval.quality);
                    last.is_autonomous |= interval.is_autonomous;
                    continue;
                }
            }
            per_worker.push(interval);
        }
        merged.extend(per_worker);
    }
    merged.sort_by_key(|interval| interval.start_at);
    merged
}

fn lower_quality(
    lhs: LeadershipEvidenceQuality,
    rhs: LeadershipEvidenceQuality,
) -> LeadershipEvidenceQuality {
    if lhs.confidence() <= rhs.confidence() {
        lhs
    } else {
        rhs
    }
}

#[derive(Default)]
struct TimelineMetrics {
    active_window: f64,
    parallel_window: f64,
    multi_project_window: f64,
    average_parallelism: f64,
    peak_concurrency: i64,
}

struct Boundary {
    worker_id: String,
    project_id: String,
    is_start: bool,
}

fn timeline_metrics(intervals: &[LeadershipInterval]) -> TimelineMetrics {
    if intervals.is_empty() {
        return TimelineMetrics::default();
    }

    let mut boundaries = Vec::with_capacity(intervals.len() * 2);
    for interval in intervals {
        boundaries.push((
            interval.start_at,
            Boundary {
                worker_id: interval.worker_id.clone(),
                project_id: interval.project_id.clone(),
                is_start: true,
            },
        ));
        boundaries.push((
            interval.end_at,
            Boundary {
                worker_id: interval.worker_id.clone(),
                project_id: interval.project_id.clone(),
                is_start: false,
            },
        ));
    }
    boundaries.sort_by_key(|(at, _)| *at);

    let mut active_workers: HashMap<String, String> = HashMap::new();
    let mut metrics = TimelineMetrics::default();
    let mut previous = boundaries[0].0;
    let mut i = 0usize;

    while i < boundaries.len() {
        let current = boundaries[i].0;
        let seconds = (current - previous).num_milliseconds() as f64 / 1000.0;
        if seconds > 0.0 {
            if !active_workers.is_empty() {
                metrics.active_window += seconds;
            }
            if active_workers.len() >= 2 {
                metrics.parallel_window += seconds;
            }
            let projects = active_workers.values().collect::<HashSet<_>>().len();
            if projects >= 2 {
                metrics.multi_project_window += seconds;
            }
            metrics.peak_concurrency = metrics.peak_concurrency.max(active_workers.len() as i64);
        }

        while i < boundaries.len() && boundaries[i].0 == current {
            let boundary = &boundaries[i].1;
            if boundary.is_start {
                active_workers.insert(boundary.worker_id.clone(), boundary.project_id.clone());
            } else {
                active_workers.remove(&boundary.worker_id);
            }
            i += 1;
        }
        previous = current;
    }

    let total_active_seconds = intervals.iter().map(duration_seconds).sum::<f64>();
    if metrics.active_window > 0.0 {
        metrics.average_parallelism = total_active_seconds / metrics.active_window;
    }
    metrics
}

fn build_daily_points(
    intervals: &[LeadershipInterval],
    start: DateTime<Utc>,
    now: DateTime<Utc>,
    statistics_tz: LeadershipStatisticsTimezone,
) -> Vec<LeadershipDayPoint> {
    let mut points = Vec::new();
    let mut day = statistics_tz.day_start(start);
    let end_day = statistics_tz.day_start(now);

    while day <= end_day {
        let next = statistics_tz.next_day_start(day).min(now);
        let clipped = intervals
            .iter()
            .filter_map(|interval| clip_interval(interval, day, next))
            .collect::<Vec<_>>();
        let metrics = timeline_metrics(&clipped);
        points.push(LeadershipDayPoint {
            day,
            agent_count: clipped
                .iter()
                .map(|interval| interval.worker_id.clone())
                .collect::<HashSet<_>>()
                .len() as i64,
            ai_hours: clipped.iter().map(duration_seconds).sum::<f64>() / 3600.0,
            peak_concurrency: metrics.peak_concurrency,
        });
        if next <= day {
            break;
        }
        day = next;
    }
    points
}

fn day_has_autonomous(
    day: DateTime<Utc>,
    intervals: &[LeadershipInterval],
    statistics_tz: LeadershipStatisticsTimezone,
) -> bool {
    let next = statistics_tz.next_day_start(day);
    intervals
        .iter()
        .any(|interval| interval.is_autonomous && interval.start_at < next && interval.end_at > day)
}

fn active_workers_effective_hours(intervals: &[LeadershipInterval]) -> f64 {
    let mut worker_seconds = HashMap::new();
    for interval in intervals {
        *worker_seconds
            .entry(interval.worker_id.clone())
            .or_insert(0.0) += duration_seconds(interval);
    }
    worker_seconds
        .values()
        .map(|seconds| (*seconds / 3600.0).min(1.0))
        .sum()
}

fn project_contributions(
    workers: &[LeadershipWorker],
    intervals: &[LeadershipInterval],
) -> Vec<LeadershipProjectContribution> {
    let worker_by_id = workers
        .iter()
        .map(|worker| (worker.id.clone(), worker))
        .collect::<HashMap<_, _>>();
    let mut by_project = HashMap::<String, Vec<&LeadershipInterval>>::new();
    for interval in intervals {
        by_project
            .entry(interval.project_id.clone())
            .or_default()
            .push(interval);
    }

    let mut contributions = Vec::new();
    for (project_id, entries) in by_project {
        let project_name = entries
            .iter()
            .find_map(|entry| worker_by_id.get(&entry.worker_id))
            .map(|worker| worker.project_name.clone())
            .unwrap_or_else(|| "Uncategorized".to_string());
        let agent_count = entries
            .iter()
            .map(|interval| interval.worker_id.clone())
            .collect::<HashSet<_>>()
            .len() as i64;
        let ai_hours = entries
            .iter()
            .map(|interval| duration_seconds(interval))
            .sum::<f64>()
            / 3600.0;
        let autonomous_hours = entries
            .iter()
            .filter(|interval| interval.is_autonomous)
            .map(|interval| duration_seconds(interval))
            .sum::<f64>()
            / 3600.0;
        contributions.push(LeadershipProjectContribution {
            project_id,
            project_name,
            agent_count,
            ai_hours,
            autonomous_hours,
        });
    }
    contributions.sort_by(|left, right| {
        right
            .ai_hours
            .partial_cmp(&left.ai_hours)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| left.project_name.cmp(&right.project_name))
    });
    contributions
}

fn build_dimensions(
    effective_workers: f64,
    peak_concurrency: i64,
    daily_ai_hours: f64,
    average_parallelism: f64,
    delegated_share: f64,
    parallel_share: f64,
    multi_project_share: f64,
    autonomous_share: f64,
    longest_autonomous_hours: f64,
    autonomous_day_share: f64,
    confidence: f64,
) -> Vec<LeadershipDimension> {
    let span = 100.0
        * (0.70 * normalize_log(effective_workers, 12.0)
            + 0.30 * normalize_log(peak_concurrency as f64, 6.0));
    let leverage = 100.0
        * (0.70 * normalize_log(daily_ai_hours, 8.0)
            + 0.30 * normalize_log(average_parallelism, 3.0));
    let orchestration = 100.0
        * (0.45 * normalize_linear(delegated_share, 0.60)
            + 0.35 * normalize_linear(parallel_share, 0.50)
            + 0.20 * normalize_linear(multi_project_share, 0.35));
    let autonomy = 100.0
        * (0.50 * normalize_linear(autonomous_share, 0.60)
            + 0.30 * normalize_log(longest_autonomous_hours, 2.0)
            + 0.20 * normalize_linear(autonomous_day_share, 0.70));

    vec![
        LeadershipDimension {
            kind: LeadershipDimensionKind::Span,
            score: normalize_bound(span),
            confidence,
            summary_value: effective_workers,
        },
        LeadershipDimension {
            kind: LeadershipDimensionKind::Leverage,
            score: normalize_bound(leverage),
            confidence,
            summary_value: daily_ai_hours,
        },
        LeadershipDimension {
            kind: LeadershipDimensionKind::Orchestration,
            score: normalize_bound(orchestration),
            confidence,
            summary_value: delegated_share,
        },
        LeadershipDimension {
            kind: LeadershipDimensionKind::Autonomy,
            score: normalize_bound(autonomy),
            confidence,
            summary_value: autonomous_share,
        },
    ]
}

fn finalize_score(
    dimensions: &[LeadershipDimension],
    active_days: i64,
    evidence_coverage: f64,
) -> Option<(i32, f64)> {
    if dimensions.len() != 4 || active_days == 0 || evidence_coverage < 0.70 {
        return None;
    }
    let core = dimensions
        .iter()
        .map(|dimension| (dimension.score.max(1.0) / 100.0).ln() * dimension.kind.weight())
        .sum::<f64>();
    let core_score = (100.0 * core.exp()).clamp(0.0, 100.0);
    let mut score = (core_score * maturity(active_days)).round() as i32;
    if score == 100 && (active_days < 28 || evidence_coverage < 0.95) {
        score = 99;
    }
    Some((score.clamp(0, 100), core_score))
}

fn maturity(active_days: i64) -> f64 {
    if active_days <= 0 {
        0.0
    } else if active_days >= 28 {
        1.0
    } else {
        0.2 + 0.8 * (1.0 - (-active_days as f64 / 6.0).exp())
    }
}

fn duration_weighted_confidence(intervals: &[LeadershipInterval]) -> f64 {
    let total = intervals.iter().map(duration_seconds).sum::<f64>();
    if total == 0.0 {
        0.0
    } else {
        intervals
            .iter()
            .map(|interval| duration_seconds(interval) * interval.quality.confidence())
            .sum::<f64>()
            / total
    }
}

fn build_title(score: i32) -> LeadershipTitle {
    match score {
        93..=100 => LeadershipTitle {
            level: 7,
            name: "Humanity's Apex".to_string(),
            english_name: "Humanity's Apex".to_string(),
            lower_bound: 93,
            upper_bound: 100,
        },
        80..=92 => LeadershipTitle {
            level: 6,
            name: "Super Individual".to_string(),
            english_name: "Super Individual".to_string(),
            lower_bound: 80,
            upper_bound: 92,
        },
        65..=79 => LeadershipTitle {
            level: 5,
            name: "Silicon Marshal".to_string(),
            english_name: "Silicon Marshal".to_string(),
            lower_bound: 65,
            upper_bound: 79,
        },
        50..=64 => LeadershipTitle {
            level: 4,
            name: "Silicon Lord".to_string(),
            english_name: "Silicon Lord".to_string(),
            lower_bound: 50,
            upper_bound: 64,
        },
        35..=49 => LeadershipTitle {
            level: 3,
            name: "Clone Captain".to_string(),
            english_name: "Clone Captain".to_string(),
            lower_bound: 35,
            upper_bound: 49,
        },
        20..=34 => LeadershipTitle {
            level: 2,
            name: "Cyber Overseer".to_string(),
            english_name: "Cyber Overseer".to_string(),
            lower_bound: 20,
            upper_bound: 34,
        },
        _ => LeadershipTitle {
            level: 1,
            name: "Carbon Laborer".to_string(),
            english_name: "Carbon Laborer".to_string(),
            lower_bound: 0,
            upper_bound: 19,
        },
    }
}

fn normalize_log(value: f64, reference: f64) -> f64 {
    if value <= 0.0 || reference <= 0.0 {
        0.0
    } else {
        (value.ln_1p() / reference.ln_1p()).clamp(0.0, 1.0)
    }
}

fn normalize_linear(value: f64, reference: f64) -> f64 {
    if reference <= 0.0 {
        0.0
    } else {
        (value / reference).clamp(0.0, 1.0)
    }
}

fn normalize_bound(value: f64) -> f64 {
    value.clamp(0.0, 100.0)
}

fn project_id(path: &str) -> String {
    let trimmed = path.trim();
    if trimmed.is_empty() {
        "codex:uncategorized".to_string()
    } else {
        format!("codex:{}", hash_path(trimmed))
    }
}

fn project_name(path: &str) -> String {
    let trimmed = path.trim_matches(|ch| ch == '/' || ch == '\\');
    trimmed
        .split(['/', '\\'])
        .next_back()
        .filter(|name| !name.is_empty())
        .map(std::string::ToString::to_string)
        .unwrap_or_else(|| "Uncategorized".to_string())
}

fn hash_path(value: &str) -> String {
    let mut hash: u64 = 14_695_981_039_346_656_037;
    for byte in value.as_bytes() {
        hash ^= *byte as u64;
        hash = hash.wrapping_mul(1_099_511_628_211);
    }
    format!("{hash:x}")
}

impl LeadershipStatisticsTimezone {
    fn day_start(&self, date: DateTime<Utc>) -> DateTime<Utc> {
        match self {
            Self::Local => day_start_in_timezone(date, &Local),
            Self::Named(timezone) => day_start_in_timezone(date, timezone),
        }
    }

    fn days_before_start(&self, date: DateTime<Utc>, day_count: i64) -> DateTime<Utc> {
        if day_count <= 0 {
            return self.day_start(date);
        }
        match self {
            Self::Local => {
                let local_day = date.with_timezone(&Local).date_naive() - Duration::days(day_count);
                to_midnight_utc_from_date(local_day, &Local)
                    .or_else(|| to_midnight_utc_from_date(local_day + Duration::days(1), &Local))
                    .unwrap_or_else(|| self.day_start(date))
            }
            Self::Named(timezone) => {
                let local_day =
                    date.with_timezone(timezone).date_naive() - Duration::days(day_count);
                to_midnight_utc_from_date(local_day, timezone)
                    .or_else(|| to_midnight_utc_from_date(local_day + Duration::days(1), timezone))
                    .unwrap_or_else(|| self.day_start(date))
            }
        }
    }

    fn next_day_start(&self, date: DateTime<Utc>) -> DateTime<Utc> {
        match self {
            Self::Local => {
                let next_local_day: NaiveDate =
                    date.with_timezone(&Local).date_naive() + Duration::days(1);
                to_midnight_utc_from_date(next_local_day, &Local)
                    .or_else(|| {
                        to_midnight_utc_from_date(next_local_day + Duration::days(1), &Local)
                    })
                    .unwrap_or(date)
            }
            Self::Named(timezone) => {
                let next_local_day: NaiveDate =
                    date.with_timezone(timezone).date_naive() + Duration::days(1);
                to_midnight_utc_from_date(next_local_day, timezone)
                    .or_else(|| {
                        to_midnight_utc_from_date(next_local_day + Duration::days(1), timezone)
                    })
                    .unwrap_or(date)
            }
        }
    }
}

fn day_start_in_timezone<Tz: TimeZone>(date: DateTime<Utc>, timezone: &Tz) -> DateTime<Utc> {
    let local = date.with_timezone(timezone);
    to_midnight_utc_from_date(local.date_naive(), timezone).unwrap_or(date)
}

fn to_midnight_utc_from_date<Tz: TimeZone>(
    date: NaiveDate,
    timezone: &Tz,
) -> Option<DateTime<Utc>> {
    resolve_midnight_utc(timezone, date)
}

fn resolve_midnight_utc<Tz: TimeZone>(timezone: &Tz, date: NaiveDate) -> Option<DateTime<Utc>> {
    let local_midnight = NaiveTime::from_hms_opt(0, 0, 0).unwrap();
    let mut local = date.and_time(local_midnight);
    loop {
        match timezone.from_local_datetime(&local) {
            LocalResult::Single(datetime) => return Some(datetime.with_timezone(&Utc)),
            LocalResult::Ambiguous(earliest, _) => return Some(earliest.with_timezone(&Utc)),
            LocalResult::None => {
                local += Duration::minutes(1);
                if local.date() != date {
                    return None;
                }
            }
        }
    }
}

fn duration_seconds(interval: &LeadershipInterval) -> f64 {
    (interval.end_at - interval.start_at).num_milliseconds() as f64 / 1000.0
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::readers::codex_state::CodexThreadMetadata;
    use crate::readers::codex_transcript::CodexTranscriptSummary;
    use crate::readers::common::CodexTaskInterval;
    use crate::readers::CodexTranscriptReader;
    use std::collections::HashMap;
    use tempfile::tempdir;

    fn mock_session(
        session_id: &str,
        project_path: &str,
        thread_source: Option<&str>,
        parent_thread_id: Option<&str>,
        quality: LeadershipEvidenceQuality,
        started_offset_minutes: i64,
        duration_minutes: i64,
        title: Option<&str>,
        created_at: Option<DateTime<Utc>>,
    ) -> SessionSummary {
        let now = Utc
            .with_ymd_and_hms(2026, 7, 28, 12, 0, 0)
            .single()
            .unwrap();
        SessionSummary {
            file_path: format!("{session_id}.jsonl"),
            session_id: session_id.to_string(),
            project_path: project_path.to_string(),
            model: None,
            last_active_at: Some(now),
            deltas: Vec::new(),
            tool_calls: HashMap::new(),
            title: title.map(std::string::ToString::to_string),
            archived: false,
            git_branch: None,
            git_origin_url: None,
            created_at: Some(created_at.unwrap_or(now)),
            thread_source: thread_source.map(std::string::ToString::to_string),
            parent_thread_id: parent_thread_id.map(std::string::ToString::to_string),
            task_intervals: vec![CodexTaskInterval {
                turn_id: Some("turn-1".to_string()),
                started_at: now - Duration::minutes(started_offset_minutes),
                ended_at: now - Duration::minutes(started_offset_minutes - duration_minutes),
                quality,
            }],
        }
    }

    #[test]
    fn unscored_when_all_intervals_are_estimated() {
        let now = Utc
            .with_ymd_and_hms(2026, 7, 28, 12, 0, 0)
            .single()
            .unwrap();
        let session = mock_session(
            "thread-a",
            "C:\\Projects\\A",
            None,
            None,
            LeadershipEvidenceQuality::Estimated,
            60,
            30,
            Some("Derived quality session"),
            Some(Utc.with_ymd_and_hms(2026, 7, 28, 12, 0, 0).unwrap()),
        );
        let snapshot = build_leadership_snapshot(&[session], now);
        let report = snapshot
            .reports
            .iter()
            .find(|r| r.period == "twentyEightDays")
            .unwrap();

        assert_eq!(report.score, None);
        assert_eq!(report.title, None);
        assert!(report.evidence_coverage < 0.7);
    }

    #[test]
    fn score_and_title_for_fact_intervals() {
        let now = Utc
            .with_ymd_and_hms(2026, 7, 28, 12, 0, 0)
            .single()
            .unwrap();
        let session = mock_session(
            "thread-b",
            "C:\\Projects\\B",
            Some("subagent"),
            Some("thread-parent"),
            LeadershipEvidenceQuality::Fact,
            30,
            30,
            Some("Task runner"),
            Some(Utc.with_ymd_and_hms(2026, 7, 28, 12, 0, 0).unwrap() - Duration::minutes(45)),
        );
        let (kind, _, has_factual_source) = classify_worker_kind(&session);
        assert_eq!(kind, LeadershipWorkerKind::Subagent);
        assert!(has_factual_source);
        let snapshot = build_leadership_snapshot(&[session], now);
        let report = snapshot
            .reports
            .iter()
            .find(|r| r.period == "twentyEightDays")
            .unwrap();

        assert!(
            report.score.is_some(),
            "score={:?}, evidence_coverage={}, active_day_count={}",
            report.score,
            report.evidence_coverage,
            report.active_day_count
        );
        assert!(report.title.is_some());
        assert_eq!(report.project_count, 1);
        assert_eq!(report.agent_count, Some(1));
        assert!(!report.projects.is_empty());
    }

    #[test]
    fn missing_legacy_task_intervals_do_not_break_parse() {
        let now = Utc
            .with_ymd_and_hms(2026, 7, 28, 12, 0, 0)
            .single()
            .unwrap();
        let legacy = r#"{
            "file_path":"rollout-c.jsonl",
            "session_id":"thread-c",
            "project_path":"C:/Projects/C",
            "model":null,
            "last_active_at":null,
            "deltas":[],
            "tool_calls":{}
        }"#;
        let summary: CodexTranscriptSummary = serde_json::from_str(legacy).unwrap();
        let session = SessionSummary {
            file_path: summary.file_path,
            session_id: summary.session_id,
            project_path: summary.project_path,
            model: summary.model,
            last_active_at: summary.last_active_at,
            deltas: Vec::new(),
            created_at: None,
            tool_calls: summary.tool_calls,
            title: None,
            archived: false,
            git_branch: None,
            git_origin_url: None,
            thread_source: None,
            parent_thread_id: None,
            task_intervals: summary.task_intervals,
        };
        let snapshot = build_leadership_snapshot(&[session], now);
        let report = snapshot
            .reports
            .iter()
            .find(|r| r.period == "today")
            .unwrap();

        assert_eq!(report.score, None);
        assert_eq!(report.agent_count, None);
        assert_eq!(report.projects.len(), 0);
    }

    #[test]
    fn merge_intervals_does_not_merge_between_workers() {
        let now = Utc
            .with_ymd_and_hms(2026, 7, 28, 12, 0, 0)
            .single()
            .unwrap();
        let intervals = vec![
            LeadershipInterval {
                id: "a1".to_string(),
                worker_id: "codex:main:w1".to_string(),
                runtime: "codex".to_string(),
                worker_kind: LeadershipWorkerKind::Main,
                project_id: "p".to_string(),
                start_at: now - Duration::minutes(60),
                end_at: now - Duration::minutes(30),
                quality: LeadershipEvidenceQuality::Fact,
                is_autonomous: false,
            },
            LeadershipInterval {
                id: "a2".to_string(),
                worker_id: "codex:main:w1".to_string(),
                runtime: "codex".to_string(),
                worker_kind: LeadershipWorkerKind::Main,
                project_id: "p".to_string(),
                start_at: now - Duration::minutes(40),
                end_at: now - Duration::minutes(10),
                quality: LeadershipEvidenceQuality::Fact,
                is_autonomous: false,
            },
            LeadershipInterval {
                id: "b1".to_string(),
                worker_id: "codex:subagent:w2".to_string(),
                runtime: "codex".to_string(),
                worker_kind: LeadershipWorkerKind::Subagent,
                project_id: "p".to_string(),
                start_at: now - Duration::minutes(50),
                end_at: now - Duration::minutes(20),
                quality: LeadershipEvidenceQuality::Fact,
                is_autonomous: true,
            },
        ];

        let merged = merge_intervals(intervals);
        assert_eq!(merged.len(), 2);
        assert_eq!(merged[0].worker_id, "codex:main:w1");
        assert_eq!(merged[0].end_at, now - Duration::minutes(10));
        assert_eq!(merged[1].worker_id, "codex:subagent:w2");
        assert_eq!(merged[1].end_at, now - Duration::minutes(20));
    }

    #[test]
    fn build_worker_id_uses_session_id_for_automation_without_marker() {
        assert_eq!(
            build_worker_id(
                "codex",
                LeadershipWorkerKind::Automation,
                "automation-session",
                None
            ),
            "codex:automation:automation-session"
        );
    }

    #[tokio::test]
    async fn valid_task_jsonl_without_metadata_is_not_scored() {
        let now = Utc.with_ymd_and_hms(2026, 7, 28, 12, 0, 0).unwrap();
        let temp = tempdir().unwrap();
        let archived = temp.path().join("archived_sessions");
        tokio::fs::create_dir_all(&archived).await.unwrap();

        let session = archived.join("rollout-no-metadata.jsonl");
        let lines = vec![
            format!(
                r#"{{"timestamp":"{}","type":"event_msg","payload":{{"type":"task_started","turn_id":"turn-1","started_at":"{}"}}}}"#,
                (now - Duration::minutes(10)).to_rfc3339(),
                (now - Duration::minutes(10)).to_rfc3339()
            ),
            format!(
                r#"{{"timestamp":"{}","type":"event_msg","payload":{{"type":"task_complete","turn_id":"turn-1","completed_at":"{}"}}}}"#,
                (now - Duration::minutes(9)).to_rfc3339(),
                (now - Duration::minutes(9)).to_rfc3339()
            ),
        ];
        tokio::fs::write(&session, lines.join("\n")).await.unwrap();

        let reader = CodexTranscriptReader::new(temp.path().join("cache"));
        let sessions = reader
            .load_local_session_summaries(temp.path(), HashMap::new())
            .await
            .unwrap()
            .expect("should parse session");
        let snapshot = build_leadership_snapshot(&sessions, now);
        let report = snapshot
            .reports
            .iter()
            .find(|r| r.period == "today")
            .unwrap();
        assert_eq!(report.score, None);
    }

    #[tokio::test]
    async fn valid_task_jsonl_with_source_metadata_scores() {
        let now = Utc.with_ymd_and_hms(2026, 7, 28, 12, 0, 0).unwrap();
        let temp = tempdir().unwrap();
        let archived = temp.path().join("archived_sessions");
        tokio::fs::create_dir_all(&archived).await.unwrap();

        let filename = "rollout-with-metadata.jsonl";
        let session = archived.join(filename);
        let lines = vec![
            format!(
                r#"{{"timestamp":"{}","type":"event_msg","payload":{{"type":"task_started","turn_id":"turn-1","started_at":"{}"}}}}"#,
                (now - Duration::minutes(30)).to_rfc3339(),
                (now - Duration::minutes(30)).to_rfc3339()
            ),
            format!(
                r#"{{"timestamp":"{}","type":"event_msg","payload":{{"type":"task_complete","turn_id":"turn-1","completed_at":"{}"}}}}"#,
                (now - Duration::minutes(10)).to_rfc3339(),
                (now - Duration::minutes(10)).to_rfc3339()
            ),
        ];
        tokio::fs::write(&session, lines.join("\n")).await.unwrap();

        let mut metadata = HashMap::new();
        metadata.insert(
            filename.to_string(),
            CodexThreadMetadata {
                thread_id: "thread-1".to_string(),
                rollout_path: filename.to_string(),
                title: None,
                cwd: Some("C:\\Projects\\B".to_string()),
                model: None,
                archived: false,
                created_at: Some((now - Duration::minutes(30)) - Duration::seconds(1)),
                updated_at: Some(now - Duration::minutes(1)),
                thread_source: Some("main".to_string()),
                parent_thread_id: None,
                git_branch: None,
                git_origin_url: None,
            },
        );
        let reader = CodexTranscriptReader::new(temp.path().join("cache"));
        let sessions = reader
            .load_local_session_summaries(temp.path(), metadata)
            .await
            .unwrap()
            .expect("should parse session");
        let snapshot = build_leadership_snapshot(&sessions, now);
        let report = snapshot
            .reports
            .iter()
            .find(|r| r.period == "today")
            .unwrap();
        assert!(report.score.is_some());
    }

    #[test]
    fn interval_far_in_the_future_is_not_scored_without_factual_gate() {
        let now = Utc.with_ymd_and_hms(2026, 7, 28, 12, 0, 0).unwrap();
        let created_at = now - Duration::minutes(1);
        let session = mock_session(
            "thread-future",
            "C:\\Projects\\Future",
            Some("main"),
            None,
            LeadershipEvidenceQuality::Fact,
            1,
            1,
            None,
            Some(created_at),
        );
        let session = SessionSummary {
            task_intervals: vec![CodexTaskInterval {
                turn_id: Some("turn-1".to_string()),
                started_at: now - Duration::minutes(1),
                ended_at: now + Duration::seconds(10),
                quality: LeadershipEvidenceQuality::Fact,
            }],
            ..session
        };

        let snapshot = build_leadership_snapshot(&[session], now);
        let report = snapshot
            .reports
            .iter()
            .find(|r| r.period == "today")
            .unwrap();
        assert_eq!(report.score, None);
    }

    #[test]
    fn interval_pre_created_before_factual_source_is_not_scored() {
        let now = Utc.with_ymd_and_hms(2026, 7, 28, 12, 0, 0).unwrap();
        let created_at = now;
        let session = mock_session(
            "thread-past",
            "C:\\Projects\\Past",
            Some("main"),
            None,
            LeadershipEvidenceQuality::Fact,
            1,
            1,
            None,
            Some(created_at),
        );
        let session = SessionSummary {
            task_intervals: vec![CodexTaskInterval {
                turn_id: Some("turn-1".to_string()),
                started_at: created_at - Duration::seconds(5),
                ended_at: created_at - Duration::seconds(4),
                quality: LeadershipEvidenceQuality::Fact,
            }],
            ..session
        };

        let snapshot = build_leadership_snapshot(&[session], now);
        let report = snapshot
            .reports
            .iter()
            .find(|r| r.period == "today")
            .unwrap();
        assert_eq!(report.score, None);
    }

    #[test]
    fn statistics_day_boundary_uses_calendar_timezone_for_during_spring_forward() {
        let tz = chrono_tz::America::New_York;
        let now = tz
            .with_ymd_and_hms(2026, 3, 9, 12, 0, 0)
            .single()
            .unwrap()
            .with_timezone(&Utc);
        let expected_day_7 = tz
            .with_ymd_and_hms(2026, 3, 7, 0, 0, 0)
            .single()
            .unwrap()
            .with_timezone(&Utc);
        let expected_day_8 = tz
            .with_ymd_and_hms(2026, 3, 8, 0, 0, 0)
            .single()
            .unwrap()
            .with_timezone(&Utc);
        let expected_day_9 = tz
            .with_ymd_and_hms(2026, 3, 9, 0, 0, 0)
            .single()
            .unwrap()
            .with_timezone(&Utc);

        let session = SessionSummary {
            file_path: "rollout-boundary.jsonl".to_string(),
            session_id: "thread-boundary".to_string(),
            project_path: "C:\\Projects\\Boundary".to_string(),
            model: None,
            last_active_at: Some(now),
            deltas: Vec::new(),
            tool_calls: HashMap::new(),
            title: Some("Boundary task".to_string()),
            archived: false,
            created_at: Some(
                tz.with_ymd_and_hms(2026, 3, 8, 0, 30, 0)
                    .single()
                    .unwrap()
                    .with_timezone(&Utc),
            ),
            git_branch: None,
            git_origin_url: None,
            thread_source: Some("main".to_string()),
            parent_thread_id: None,
            task_intervals: vec![CodexTaskInterval {
                turn_id: Some("turn-1".to_string()),
                started_at: tz
                    .with_ymd_and_hms(2026, 3, 8, 0, 30, 0)
                    .single()
                    .unwrap()
                    .with_timezone(&Utc),
                ended_at: tz
                    .with_ymd_and_hms(2026, 3, 8, 1, 30, 0)
                    .single()
                    .unwrap()
                    .with_timezone(&Utc),
                quality: LeadershipEvidenceQuality::Fact,
            }],
        };

        let workers = vec![make_worker(&session)];
        let intervals = build_intervals(std::slice::from_ref(&session), &workers, now);
        let report = build_report(
            "manual".to_string(),
            &workers,
            &intervals,
            now,
            3,
            LeadershipStatisticsTimezone::Named(tz),
        );

        let expected_start = LeadershipStatisticsTimezone::Named(tz).days_before_start(now, 2);
        let report_daily_points = report
            .daily_points
            .iter()
            .filter(|point| point.ai_hours > 0.0)
            .count();
        let active_day_point = report
            .daily_points
            .iter()
            .find(|point| point.ai_hours > 0.0)
            .expect("should emit activity point");

        assert_eq!(intervals.len(), 1);
        assert_eq!(report.daily_points.len(), 3);
        assert_eq!(report.daily_points[0].day, expected_day_7);
        assert_eq!(report.daily_points[1].day, expected_day_8);
        assert_eq!(report.daily_points[2].day, expected_day_9);
        assert_eq!((expected_day_8 - expected_day_7).num_hours(), 24);
        assert_eq!((expected_day_9 - expected_day_8).num_hours(), 23);
        assert_eq!(report.active_day_count, 1);
        assert_eq!(report_daily_points, 1);
        assert_eq!(expected_start, expected_day_7);
        assert_eq!(active_day_point.day, expected_day_8);

        let snapshot = build_leadership_snapshot_with_timezone(
            std::slice::from_ref(&session),
            now,
            LeadershipStatisticsTimezone::Named(tz),
        );
        let report = snapshot
            .reports
            .iter()
            .find(|r| r.period == "today")
            .unwrap();
        assert_eq!(report.daily_points.last().unwrap().day, expected_day_9);
    }
}
