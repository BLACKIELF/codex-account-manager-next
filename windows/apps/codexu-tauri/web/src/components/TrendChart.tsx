import { useMemo, useState } from 'react';
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import type { TokenBreakdown, UsageTrend } from '../types/models';
import { useI18n } from '../i18n/I18nProvider';

interface TrendChartProps {
  trend: UsageTrend | null;
}

const RANGES = [
  { label: '30D', days: 30 },
  { label: '90D', days: 90 },
  { label: '180D', days: 180 },
];

export function TrendChart({ trend }: TrendChartProps) {
  const { t } = useI18n();
  const [range, setRange] = useState(30);

  const data = useMemo(() => {
    if (!trend) return [];
    const cutoff = Date.now() - range * 24 * 60 * 60 * 1000;
    return trend.day_buckets
      .filter((b) => b.date >= cutoff)
      .map((b) => ({
        date: new Date(b.date).toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
        tokens: visibleTotalTokens(b.usage.tokens),
      }));
  }, [trend, range]);

  if (!trend || data.length === 0) {
    return (
      <div className="glass-panel p-4 sm:p-5">
        <h3 className="text-sm font-semibold text-primary">{t('usage.dailyTrend')}</h3>
        <p className="mt-2 text-sm text-secondary">{t('usage.noTrend')}</p>
        <p className="mt-1 text-xs text-tertiary">{t('usage.trendDetail')}</p>
      </div>
    );
  }

  return (
    <div className="glass-panel p-4 sm:p-5">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-sm font-semibold text-primary">{t('usage.dailyTrend')}</h3>
          <p className="mt-1 text-xs text-tertiary">{sourceQualityLabel(trend.source_quality, t)}</p>
        </div>
        <div className="flex gap-1 glass-toolbar p-0.5 rounded-full">
          {RANGES.map((r) => (
            <button
              key={r.days}
              onClick={() => setRange(r.days)}
              className={`px-2.5 py-1 rounded-full text-xs transition-all ${
                range === r.days
                  ? 'glass-button-solid'
                  : 'text-secondary glass-button'
              }`}
            >
              {r.label}
            </button>
          ))}
        </div>
      </div>
      <div className="usage-trend-summary" aria-label={t('usage.lastSevenSummary')}>
        <div>
          <span>{t('usage.lastSevenDays')}</span>
          <strong>{formatTokens(visibleTotalTokens(trend.summary.seven_day.tokens))}</strong>
        </div>
        <div>
          <span>{t('usage.dailyAverage')}</span>
          <strong>{formatTokens(trend.summary.daily_average_tokens)}</strong>
        </div>
        <div>
          <span>{t('usage.change')}</span>
          <strong>{formatChange(trend.summary.change_percent, trend.summary.is_new_activity, t)}</strong>
        </div>
      </div>
      <div className="h-56">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={data} margin={{ top: 8, right: 8, bottom: 0, left: 0 }}>
            <defs>
              <linearGradient id="colorTokens" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="var(--data-primary)" stopOpacity={0.35} />
                <stop offset="95%" stopColor="var(--data-primary)" stopOpacity={0.02} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" vertical={false} />
            <XAxis
              dataKey="date"
              tick={{ fill: 'var(--text-secondary)', fontSize: 11 }}
              axisLine={{ stroke: 'var(--border)' }}
              tickLine={false}
              minTickGap={24}
            />
            <YAxis
              tick={{ fill: 'var(--text-secondary)', fontSize: 12 }}
              axisLine={false}
              tickLine={false}
              tickFormatter={(v: number) => formatCompact(v)}
            />
            <Tooltip
              contentStyle={{
                backgroundColor: 'var(--surface-elevated)',
                border: '1px solid var(--border)',
                borderRadius: '8px',
                color: 'var(--text-primary)',
              }}
              formatter={(value: number) => [formatNumber(value), t('usage.tokenLabel')]}
            />
            <Area
              type="monotone"
              dataKey="tokens"
              stroke="var(--data-primary)"
              strokeWidth={2}
              fill="url(#colorTokens)"
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}

function formatCompact(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}k`;
  return String(n);
}

function formatNumber(n: number): string {
  return n.toLocaleString();
}

function visibleTotalTokens(tokens: TokenBreakdown): number {
  return Math.max(tokens.total_tokens, tokens.input_tokens + tokens.output_tokens);
}

function formatTokens(value: number): string {
  return Math.round(value).toLocaleString();
}

function formatChange(value: number | null, isNewActivity: boolean, t: ReturnType<typeof useI18n>['t']): string {
  if (isNewActivity) return t('usage.newActivity');
  if (value == null || !Number.isFinite(value)) return '--';
  return `${value >= 0 ? '+' : ''}${value.toFixed(0)}%`;
}

function sourceQualityLabel(value: UsageTrend['source_quality'], t: ReturnType<typeof useI18n>['t']): string {
  return value === 'detailed' ? t('usage.detailedEvents') : t('usage.threadFallback');
}
