use std::collections::VecDeque;

use anyhow::Result;
use codexu_core::readers::codex_app_server::{
    read_installed_codex_quota, read_quota_from_transport, AppServerTransport,
    CodexAppServerQuotaSnapshot,
};
use serde_json::json;

#[test]
fn treats_a_single_weekly_app_server_window_as_an_authoritative_quota() {
    let quota = CodexAppServerQuotaSnapshot::from_rate_limit_response(&json!({
        "rateLimits": {
            "limitId": "codex",
            "limitName": "Codex",
            "primary": {
                "usedPercent": 41,
                "windowDurationMins": 10080,
                "resetsAt": 1_800_000_000
            },
            "secondary": null
        }
    }));

    assert!(quota.quota_read_succeeded);
    assert!(quota.five_hour_quota.is_none());
    assert_eq!(
        quota.seven_day_quota.expect("weekly quota").used_percent,
        41.0
    );
    assert!(quota.monthly_quota.is_none());
}

struct FixtureTransport {
    responses: VecDeque<serde_json::Value>,
}

impl FixtureTransport {
    fn with_responses(responses: impl IntoIterator<Item = serde_json::Value>) -> Self {
        Self {
            responses: responses.into_iter().collect(),
        }
    }
}

impl AppServerTransport for FixtureTransport {
    async fn request(&mut self, _request: serde_json::Value) -> Result<serde_json::Value> {
        Ok(self.responses.pop_front().expect("fixture response"))
    }

    async fn notify(&mut self, _notification: serde_json::Value) -> Result<()> {
        Ok(())
    }
}

#[tokio::test]
async fn reads_account_metadata_and_weekly_quota_through_the_app_server_protocol() {
    let mut transport = FixtureTransport::with_responses([
        json!({"id": 1, "result": {}}),
        json!({
            "id": 2,
            "result": {"account": {"type": "chatgpt", "planType": "pro", "email": "hidden@example.test"}}
        }),
        json!({
            "id": 3,
            "result": {
                "rateLimits": {
                    "limitId": "codex",
                    "limitName": "Codex",
                    "primary": {"usedPercent": 41, "windowDurationMins": 10080, "resetsAt": 1_800_000_000},
                    "secondary": null
                }
            }
        }),
    ]);

    let quota = read_quota_from_transport(&mut transport)
        .await
        .expect("official quota response");

    assert_eq!(quota.account.expect("account").r#type, "chatgpt");
    assert_eq!(quota.limit_id.as_deref(), Some("codex"));
    assert_eq!(quota.limit_name.as_deref(), Some("Codex"));
    assert!(quota.quota_read_succeeded);
    assert_eq!(
        quota.seven_day_quota.expect("weekly quota").used_percent,
        41.0
    );
}

#[cfg(windows)]
#[tokio::test]
#[ignore = "requires the locally installed Codex CLI and authenticated account"]
async fn installed_codex_app_server_returns_at_least_one_authoritative_window() {
    let quota = read_installed_codex_quota()
        .await
        .expect("installed Codex app-server quota response");

    assert!(quota.quota_read_succeeded);
    assert!(
        quota.five_hour_quota.is_some()
            || quota.seven_day_quota.is_some()
            || quota.monthly_quota.is_some()
    );
}
