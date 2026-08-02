import type { TokenBreakdown, UsageHeatmapDay, UsageTrend } from '../types/models';

interface UsageHeatmapProps {
  trend: UsageTrend | null;
}

export function UsageHeatmap({ trend }: UsageHeatmapProps) {
  const weeks = trend?.heatmap_weeks ?? [];

  return (
    <article className="glass-panel p-4 sm:p-5" aria-label="Recent local usage distribution">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h3 className="text-sm font-semibold text-primary">Recent usage</h3>
          <p className="mt-1 text-xs text-tertiary">Last 6 months · local records</p>
        </div>
        <span className="usage-source-chip">{sourceQualityLabel(trend?.source_quality)}</span>
      </div>

      {weeks.length === 0 ? (
        <p className="mt-5 text-sm text-secondary">No local usage records yet.</p>
      ) : (
        <>
          <div className="usage-heatmap-range mt-5" aria-hidden="true">
            <span>6 months ago</span>
            <span>Today</span>
          </div>
          <div
            className="usage-heatmap-grid mt-2"
            role="grid"
            aria-label="Daily local token usage for the last 6 months"
            style={{ gridTemplateColumns: `repeat(${weeks.length}, minmax(0, 1fr))` }}
          >
            {weeks.map((week, weekIndex) => (
              <div className="usage-heatmap-week" role="row" key={`week-${weekIndex}`}>
                {week.map((day) => (
                  <HeatmapCell key={day.id} day={day} thresholds={trend?.heatmap_thresholds ?? []} />
                ))}
              </div>
            ))}
          </div>
          <div className="usage-heatmap-legend mt-3" aria-hidden="true">
            <span>Less</span>
            <span className="usage-heatmap-swatch usage-heatmap-empty" />
            <span className="usage-heatmap-swatch usage-heatmap-level-1" />
            <span className="usage-heatmap-swatch usage-heatmap-level-2" />
            <span className="usage-heatmap-swatch usage-heatmap-level-3" />
            <span className="usage-heatmap-swatch usage-heatmap-level-4" />
            <span>More</span>
          </div>
        </>
      )}
    </article>
  );
}

function HeatmapCell({ day, thresholds }: { day: UsageHeatmapDay; thresholds: number[] }) {
  const label = heatmapLabel(day);
  const level = heatLevel(day, thresholds);
  const stateClass = day.is_future
    ? 'usage-heatmap-future'
    : day.usage
      ? `usage-heatmap-level-${level}`
      : 'usage-heatmap-empty';

  return (
    <span
      className={`usage-heatmap-cell ${stateClass}`}
      role="gridcell"
      aria-label={label}
      title={label}
    />
  );
}

function heatLevel(day: UsageHeatmapDay, thresholds: number[]): number {
  if (day.is_future || !day.usage) return 0;
  const tokens = visibleTotalTokens(day.usage.tokens);
  return Math.min(4, thresholds.reduce((level, threshold, index) => (tokens >= threshold ? index + 1 : level), 0));
}

function heatmapLabel(day: UsageHeatmapDay): string {
  const date = new Intl.DateTimeFormat(undefined, { month: 'short', day: 'numeric' }).format(new Date(day.date));
  if (day.is_future) return `${date}: future`;
  if (!day.usage) return `${date}: No recorded usage`;
  return `${date}: ${formatTokens(visibleTotalTokens(day.usage.tokens))} tokens`;
}

function visibleTotalTokens(tokens: TokenBreakdown): number {
  return Math.max(tokens.total_tokens, tokens.input_tokens + tokens.output_tokens);
}

function formatTokens(value: number): string {
  return Math.round(value).toLocaleString();
}

function sourceQualityLabel(value: UsageTrend['source_quality'] | null | undefined): string {
  if (value === 'detailed') return 'Detailed events';
  if (value === 'approximate') return 'Thread fallback';
  return 'No source yet';
}
