use serde::{Deserialize, Serialize};

/// Kind of AI worker.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LeadershipWorkerKind {
    Main,
    Subagent,
    Automation,
}

/// Quality of evidence used for scoring.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LeadershipEvidenceQuality {
    Fact,
    Derived,
    Estimated,
}

impl LeadershipEvidenceQuality {
    pub fn confidence(&self) -> f64 {
        match self {
            LeadershipEvidenceQuality::Fact => 1.0,
            LeadershipEvidenceQuality::Derived => 0.9,
            LeadershipEvidenceQuality::Estimated => 0.6,
        }
    }

    pub fn is_scorable(&self) -> bool {
        !matches!(self, LeadershipEvidenceQuality::Estimated)
    }
}

/// A worker (agent) being led.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LeadershipWorker {
    pub id: String,
    pub runtime: String,
    pub kind: LeadershipWorkerKind,
    pub project_id: String,
    pub project_name: String,
    pub parent_id: Option<String>,
}

/// A time interval during which a worker was active.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LeadershipInterval {
    pub id: String,
    pub worker_id: String,
    pub runtime: String,
    pub worker_kind: LeadershipWorkerKind,
    pub project_id: String,
    #[serde(with = "chrono::serde::ts_milliseconds")]
    pub start_at: chrono::DateTime<chrono::Utc>,
    #[serde(with = "chrono::serde::ts_milliseconds")]
    pub end_at: chrono::DateTime<chrono::Utc>,
    pub quality: LeadershipEvidenceQuality,
    pub is_autonomous: bool,
}

/// One of the four leadership dimensions.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LeadershipDimensionKind {
    Span,
    Leverage,
    Orchestration,
    Autonomy,
}

impl LeadershipDimensionKind {
    pub fn weight(&self) -> f64 {
        match self {
            LeadershipDimensionKind::Span => 0.30,
            LeadershipDimensionKind::Leverage => 0.30,
            LeadershipDimensionKind::Orchestration => 0.25,
            LeadershipDimensionKind::Autonomy => 0.15,
        }
    }
}

/// A scored leadership dimension.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LeadershipDimension {
    pub kind: LeadershipDimensionKind,
    pub score: f64,
    pub confidence: f64,
    pub summary_value: f64,
}

/// A leadership title / badge.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LeadershipTitle {
    pub level: i32,
    pub name: String,
    pub english_name: String,
    pub lower_bound: i32,
    pub upper_bound: i32,
}

/// Daily leadership data point.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LeadershipDayPoint {
    #[serde(with = "chrono::serde::ts_milliseconds")]
    pub day: chrono::DateTime<chrono::Utc>,
    pub agent_count: i64,
    pub ai_hours: f64,
    pub peak_concurrency: i64,
}

/// Project contribution to leadership score.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LeadershipProjectContribution {
    pub project_id: String,
    pub project_name: String,
    pub agent_count: i64,
    pub ai_hours: f64,
    pub autonomous_hours: f64,
}

/// A leadership report for a period.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LeadershipReport {
    pub period: String,
    pub score: Option<i32>,
    pub core_score: Option<f64>,
    pub title: Option<LeadershipTitle>,
    pub dimensions: Vec<LeadershipDimension>,
    pub maturity: f64,
    pub evidence_coverage: f64,
    pub active_day_count: i64,
    pub agent_count: Option<i64>,
    pub ai_hours: Option<f64>,
    pub autonomous_hours: Option<f64>,
    pub average_parallelism: Option<f64>,
    pub peak_concurrency: Option<i64>,
    pub project_count: i64,
    pub daily_points: Vec<LeadershipDayPoint>,
    pub projects: Vec<LeadershipProjectContribution>,
}

/// Full leadership dashboard snapshot.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LeadershipDashboardSnapshot {
    pub model_version: String,
    #[serde(with = "chrono::serde::ts_milliseconds")]
    pub refreshed_at: chrono::DateTime<chrono::Utc>,
    pub reports: Vec<LeadershipReport>,
}
