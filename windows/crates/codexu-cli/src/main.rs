use std::path::PathBuf;

use anyhow::Context;
use chrono::Utc;
use clap::Parser;
use codexu_core::readers::ClaudeCodeTranscriptReader;
use tracing::{info, warn};

#[derive(Parser, Debug)]
#[command(name = "codexu-probe")]
#[command(about = "codexU Windows port - data probe CLI")]
struct Args {
    /// Path to Claude Code projects root (e.g. ~/.claude/projects)
    #[arg(long, value_name = "PATH")]
    claude_projects: Option<PathBuf>,

    /// Cache directory for codexU
    #[arg(long, value_name = "PATH")]
    cache_dir: Option<PathBuf>,

    /// Output file for JSON dump
    #[arg(short, long, value_name = "PATH", default_value = "codexu-probe.json")]
    output: PathBuf,

    /// Only print summary, skip writing JSON
    #[arg(long)]
    summary: bool,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    let args = Args::parse();

    let home = dirs::home_dir().context("Could not determine home directory")?;
    let claude_projects = args
        .claude_projects
        .unwrap_or_else(|| home.join(".claude").join("projects"));

    let cache_dir = args
        .cache_dir
        .unwrap_or_else(|| dirs::cache_dir().unwrap_or_else(|| home.join(".cache")).join("codexU"));

    info!("Claude projects root: {}", claude_projects.display());
    info!("Cache directory: {}", cache_dir.display());

    let reader = ClaudeCodeTranscriptReader::new(&cache_dir);
    let now = Utc::now();

    match reader.load_local_usage(&claude_projects, now).await {
        Ok(Some(local_usage)) => {
            info!(
                "Parsed {} files, {} unique usage events",
                local_usage.detailed_usage.as_ref().map(|d| d.parsed_file_count).unwrap_or(0),
                local_usage.detailed_usage.as_ref().map(|d| d.token_event_count).unwrap_or(0)
            );
            info!(
                "Today: {} tokens, 7-day: {} tokens, lifetime: {} tokens",
                local_usage.today_tokens,
                local_usage.seven_day_tokens,
                local_usage.lifetime_tokens
            );
            info!("Projects: {}", local_usage.project_board.as_ref().map(|b| b.all_projects.len()).unwrap_or(0));
            info!("Tools: {}", local_usage.tool_usages.len());

            if !args.summary {
                let json = serde_json::to_string_pretty(&local_usage)?;
                tokio::fs::write(&args.output, json).await?;
                info!("Wrote JSON to {}", args.output.display());
            }
        }
        Ok(None) => {
            warn!("No Claude Code usage data found at {}", claude_projects.display());
        }
        Err(e) => {
            return Err(e).context("Failed to load Claude Code local usage");
        }
    }

    Ok(())
}
