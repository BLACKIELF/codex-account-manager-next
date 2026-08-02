import type { TokenBreakdown, UsageHeatmapDay, UsageTrend } from '../types/models';
import { useI18n } from '../i18n/I18nProvider';

interface UsageHeatmapProps {
  trend: UsageTrend | null;
}

export function UsageHeatmap({ trend }: UsageHeatmapProps) {
  const { t } = useI18n();
  const weeks = trend?.heatmap_weeks ?? [];

  return (
    <article className="glass-panel p-4 sm:p-5" aria-label={t('usage.recentUsage')}>
      <div className="flex items-start justify-between gap-3">
        <div>
          <h3 className="text-sm font-semibold text-primary">{t('usage.recentUsage')}</h3>
          <p className="mt-1 text-xs text-tertiary">{t('usage.lastSixMonths')}</p>
        </div>
        <span className="usage-source-chip">{sourceQualityLabel(trend?.source_quality, t)}</span>
      </div>

      {weeks.length === 0 ? (
        <p className="mt-5 text-sm text-secondary">{t('usage.noRecords')}</p>
      ) : (
        <>
          <div className="usage-heatmap-range mt-5" aria-hidden="true">
            <span>{t('usage.sixMonthsAgo')}</span>
            <span>{t('usage.todayRange')}</span>
          </div>
          <div
            className="usage-heatmap-grid mt-2"
            role="grid"
            aria-label={t('usage.dailyUsage')}
            style={{ gridTemplateColumns: `repeat(${weeks.length}, minmax(0, 1fr))` }}
          >
            {weeks.map((week, weekIndex) => (
              <div className="usage-heatmap-week" role="row" key={`week-${weekIndex}`}>
                {week.map((day) => (
                  <HeatmapCell key={day.id} day={day} thresholds={trend?.heatmap_thresholds ?? []} t={t} />
                ))}
              </div>
            ))}
          </div>
          <div className="usage-heatmap-legend mt-3" aria-hidden="true">
            <span>{t('usage.less')}</span>
            <span className="usage-heatmap-swatch usage-heatmap-empty" />
            <span className="usage-heatmap-swatch usage-heatmap-level-1" />
            <span className="usage-heatmap-swatch usage-heatmap-level-2" />
            <span className="usage-heatmap-swatch usage-heatmap-level-3" />
            <span className="usage-heatmap-swatch usage-heatmap-level-4" />
            <span>{t('usage.more')}</span>
          </div>
        </>
      )}
    </article>
  );
}

function HeatmapCell({
  day,
  thresholds,
  t,
}: {
  day: UsageHeatmapDay;
  thresholds: number[];
  t: ReturnType<typeof useI18n>['t'];
}) {
  const label = heatmapLabel(day, t);
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

function heatmapLabel(day: UsageHeatmapDay, t: ReturnType<typeof useI18n>['t']): string {
  const date = new Intl.DateTimeFormat(undefined, { month: 'short', day: 'numeric' }).format(new Date(day.date));
  if (day.is_future) return t('usage.future', { date });
  if (!day.usage) return t('usage.noRecordedUsage', { date });
  return t('usage.tokens', { date, value: formatTokens(visibleTotalTokens(day.usage.tokens)) });
}

function visibleTotalTokens(tokens: TokenBreakdown): number {
  return Math.max(tokens.total_tokens, tokens.input_tokens + tokens.output_tokens);
}

function formatTokens(value: number): string {
  return Math.round(value).toLocaleString();
}

function sourceQualityLabel(
  value: UsageTrend['source_quality'] | null | undefined,
  t: ReturnType<typeof useI18n>['t'],
): string {
  if (value === 'detailed') return t('usage.detailedEvents');
  if (value === 'approximate') return t('usage.threadFallback');
  return t('usage.noSourceYet');
}
