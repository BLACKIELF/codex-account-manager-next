use serde::{Deserialize, Serialize};

/// Quality label for usage data sources.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UsageSourceQuality {
    Detailed,
    Approximate,
}

/// Breakdown of token usage into input / cached input / output / reasoning.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct TokenBreakdown {
    pub input_tokens: i64,
    pub cached_input_tokens: i64,
    pub output_tokens: i64,
    pub reasoning_output_tokens: i64,
    pub total_tokens: i64,
}

impl TokenBreakdown {
    pub const ZERO: Self = Self {
        input_tokens: 0,
        cached_input_tokens: 0,
        output_tokens: 0,
        reasoning_output_tokens: 0,
        total_tokens: 0,
    };

    /// Cached input tokens cannot exceed total input tokens.
    pub fn billable_cached_input_tokens(&self) -> i64 {
        self.cached_input_tokens
            .max(0)
            .min(self.input_tokens.max(0))
    }

    pub fn uncached_input_tokens(&self) -> i64 {
        (self.input_tokens - self.billable_cached_input_tokens()).max(0)
    }

    pub fn visible_total_tokens(&self) -> i64 {
        self.total_tokens
            .max(self.input_tokens + self.output_tokens)
    }

    pub fn split_total_tokens(&self) -> i64 {
        (self.uncached_input_tokens()
            + self.billable_cached_input_tokens()
            + self.output_tokens.max(0))
        .max(0)
    }

    pub fn is_zero(&self) -> bool {
        self.input_tokens == 0
            && self.cached_input_tokens == 0
            && self.output_tokens == 0
            && self.reasoning_output_tokens == 0
            && self.total_tokens == 0
    }

    pub fn add(&mut self, other: &Self) {
        self.input_tokens += other.input_tokens;
        self.cached_input_tokens += other.cached_input_tokens;
        self.output_tokens += other.output_tokens;
        self.reasoning_output_tokens += other.reasoning_output_tokens;
        self.total_tokens += other.total_tokens;
    }
}

/// Token usage with an estimated dollar cost.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct PricedTokenUsage {
    pub tokens: TokenBreakdown,
    pub estimated_cost_usd: f64,
}

impl PricedTokenUsage {
    pub const ZERO: Self = Self {
        tokens: TokenBreakdown::ZERO,
        estimated_cost_usd: 0.0,
    };

    pub fn add_tokens(&mut self, tokens: &TokenBreakdown, cost_usd: f64) {
        self.tokens.add(tokens);
        self.estimated_cost_usd += cost_usd;
    }
}

/// Detailed usage across time windows.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct DetailedUsage {
    pub today: PricedTokenUsage,
    pub seven_day: PricedTokenUsage,
    pub month: PricedTokenUsage,
    pub lifetime: PricedTokenUsage,
    pub parsed_file_count: i64,
    pub token_event_count: i64,
}

/// A single day's usage bucket.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct UsageDayBucket {
    pub id: String,
    #[serde(with = "chrono::serde::ts_milliseconds")]
    pub date: chrono::DateTime<chrono::Utc>,
    pub usage: PricedTokenUsage,
    pub source_quality: UsageSourceQuality,
}

/// Summary of usage trend.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct UsageTrendSummary {
    pub seven_day: PricedTokenUsage,
    pub daily_average_tokens: i64,
    pub peak_day: Option<UsageDayBucket>,
    pub change_percent: Option<f64>,
    pub is_new_activity: bool,
}

/// Trend for a specific model.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ModelUsageTrend {
    pub id: String,
    pub model: Option<String>,
    pub day_buckets: Vec<UsageDayBucket>,
    pub summary: UsageTrendSummary,
    pub active_day_count: i64,
}

/// Overall usage trend.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct UsageTrend {
    pub day_buckets: Vec<UsageDayBucket>,
    pub heatmap_weeks: Vec<Vec<UsageHeatmapDay>>,
    pub heatmap_thresholds: Vec<i64>,
    pub summary: UsageTrendSummary,
    pub model_trends: Option<Vec<ModelUsageTrend>>,
    pub month: PricedTokenUsage,
    pub projected_month_cost_usd: Option<f64>,
    pub active_day_count: i64,
    pub source_quality: UsageSourceQuality,
}

/// A single day in a heatmap, possibly without usage.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct UsageHeatmapDay {
    pub id: String,
    #[serde(with = "chrono::serde::ts_milliseconds")]
    pub date: chrono::DateTime<chrono::Utc>,
    pub usage: Option<PricedTokenUsage>,
    pub is_future: bool,
}

/// A local thread summary.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LocalThread {
    pub id: String,
    pub title: String,
    pub tokens: i64,
    #[serde(with = "chrono::serde::ts_milliseconds_option")]
    pub updated_at: Option<chrono::DateTime<chrono::Utc>>,
    pub model: Option<String>,
    pub cwd: String,
    pub archived: bool,
}

/// Project usage summary.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ProjectUsage {
    pub id: String,
    pub name: String,
    pub full_path: String,
    pub tokens: i64,
    pub estimated_cost_usd: Option<f64>,
    pub thread_count: i64,
    #[serde(with = "chrono::serde::ts_milliseconds_option")]
    pub last_active_at: Option<chrono::DateTime<chrono::Utc>>,
    pub source_quality: UsageSourceQuality,
}

/// Tool usage summary.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ToolUsage {
    pub id: String,
    pub name: String,
    pub category: String,
    pub call_count: i64,
    pub estimated_tokens: Option<i64>,
    pub estimated_cost_usd: Option<f64>,
}

/// Skill usage summary.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SkillUsage {
    pub id: String,
    pub name: String,
    pub source_label: String,
    pub load_count: i64,
    pub thread_count: i64,
    #[serde(with = "chrono::serde::ts_milliseconds_option")]
    pub last_loaded_at: Option<chrono::DateTime<chrono::Utc>>,
}

/// Aggregated local usage.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LocalUsage {
    pub lifetime_tokens: i64,
    pub today_tokens: i64,
    pub seven_day_tokens: i64,
    pub thread_count: i64,
    #[serde(with = "chrono::serde::ts_milliseconds_option")]
    pub last_updated_at: Option<chrono::DateTime<chrono::Utc>>,
    pub daily_buckets: Vec<DailyTokenBucket>,
    pub recent_threads: Vec<LocalThread>,
    pub detailed_usage: Option<DetailedUsage>,
    pub usage_trend: Option<UsageTrend>,
    pub project_board: Option<ProjectBoard>,
    pub tool_usages: Vec<ToolUsage>,
    pub skill_usages: Vec<SkillUsage>,
}

/// A bucket for the recent 7-day bar chart.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct DailyTokenBucket {
    pub id: String,
    pub label: String,
    pub tokens: i64,
}

/// Project board with recent and all projects.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ProjectBoard {
    pub recent_projects: Vec<ProjectUsage>,
    pub all_projects: Vec<ProjectUsage>,
}

/// A single task item.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TaskItem {
    pub id: String,
    pub code: String,
    pub title: String,
    pub detail: String,
    pub chip: String,
    #[serde(with = "chrono::serde::ts_milliseconds_option")]
    pub updated_at: Option<chrono::DateTime<chrono::Utc>>,
    pub tokens: Option<i64>,
    pub kind: String,
    pub thread_id: Option<String>,
    pub runtime_state: String,
    pub source_kind: String,
    pub display_state: String,
    pub state_basis: String,
    pub raw_status: Option<String>,
    #[serde(with = "chrono::serde::ts_milliseconds_option")]
    pub next_run_at: Option<chrono::DateTime<chrono::Utc>>,
}

/// A task column.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TaskColumn {
    pub id: String,
    pub title: String,
    pub count: i64,
    pub items: Vec<TaskItem>,
}

/// A task board.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TaskBoard {
    #[serde(with = "chrono::serde::ts_milliseconds")]
    pub refreshed_at: chrono::DateTime<chrono::Utc>,
    pub columns: Vec<TaskColumn>,
}
