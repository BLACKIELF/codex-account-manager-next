import { Activity, Calendar, Coins, TrendingUp, type LucideIcon } from 'lucide-react';
import type { PricedTokenUsage, TokenBreakdown, LocalUsage } from '../types/models';
import { TrendChart } from './TrendChart';
import { UsageHeatmap } from './UsageHeatmap';

interface UsagePanelProps {
  usage: LocalUsage | null | undefined;
}

export function UsagePanel({ usage }: UsagePanelProps) {
  const detailed = usage?.detailed_usage ?? null;
  const trend = usage?.usage_trend ?? null;

  return (
    <section className="space-y-4 usage-panel" aria-label="Local usage records">
      <div className="glass-panel p-4 sm:p-5 usage-panel-heading">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.12em] text-tertiary">Usage</p>
          <h2 className="mt-1 text-lg font-semibold text-primary">Local token activity</h2>
          <p className="mt-1 text-sm text-secondary">
            Recent and lifetime records from this device. Official quota is shown separately.
          </p>
        </div>
        <div className="usage-panel-source">
          <span className="usage-source-chip">{sourceQualityLabel(trend?.source_quality)}</span>
          <span className="text-xs text-tertiary">Not official quota or billing</span>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <UsageMetricCard
          label="Today"
          icon={Activity}
          usage={detailed?.today ?? null}
          fallbackTokens={usage?.today_tokens}
          accent="primary"
        />
        <UsageMetricCard
          label="Last 7 days"
          icon={Calendar}
          usage={detailed?.seven_day ?? null}
          fallbackTokens={usage?.seven_day_tokens}
          accent="secondary"
        />
        <UsageMetricCard
          label="Lifetime"
          icon={TrendingUp}
          usage={detailed?.lifetime ?? null}
          fallbackTokens={usage?.lifetime_tokens}
          accent="tertiary"
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1.05fr)_minmax(0,1fr)] gap-3">
        <UsageHeatmap trend={trend} />
        <TrendChart trend={trend} />
      </div>

      <div className="glass-panel px-4 py-3 sm:px-5 usage-panel-note" role="note">
        <Coins size={15} aria-hidden="true" />
        {detailed ? (
          <span>
            Local API-equivalent estimate: <strong>${formatUSD(detailed.lifetime.estimated_cost_usd)}</strong> · not official billing.
          </span>
        ) : (
          <span>Local API-equivalent estimate is unavailable until detailed token events are recorded.</span>
        )}
      </div>
    </section>
  );
}

interface UsageMetricCardProps {
  label: string;
  icon: LucideIcon;
  usage: PricedTokenUsage | null;
  fallbackTokens: number | null | undefined;
  accent: 'primary' | 'secondary' | 'tertiary';
}

function UsageMetricCard({ label, icon: Icon, usage, fallbackTokens, accent }: UsageMetricCardProps) {
  const value = usage ? visibleTotalTokens(usage.tokens) : fallbackTokens;
  const accentClass =
    accent === 'primary'
      ? 'bg-data-primary/20 text-data-primary'
      : accent === 'secondary'
        ? 'bg-data-secondary/20 text-data-secondary'
        : 'bg-data-tertiary/20 text-data-tertiary';

  return (
    <article className="glass-panel p-4 usage-metric-card">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-sm font-medium text-secondary">{label}</p>
          <p className="mt-1 text-2xl font-semibold text-primary tabular-nums">{formatTokens(value)}</p>
        </div>
        <span className={`p-2 rounded-lg border border-current/20 ${accentClass}`} aria-hidden="true">
          <Icon size={17} />
        </span>
      </div>
      <TokenBreakdownBar tokens={usage?.tokens ?? null} />
    </article>
  );
}

function TokenBreakdownBar({ tokens }: { tokens: TokenBreakdown | null }) {
  const segments = splitTokenBreakdown(tokens);
  const total = segments.reduce((sum, segment) => sum + segment.value, 0);

  return (
    <div className="mt-4" aria-label="Token breakdown">
      <div className="usage-token-track" aria-hidden="true">
        {total > 0 &&
          segments.map((segment) => (
            <span
              className={`usage-token-segment ${segment.className}`}
              key={segment.label}
              style={{ width: `${(segment.value / total) * 100}%` }}
            />
          ))}
      </div>
      {tokens ? (
        <div className="mt-2 grid grid-cols-3 gap-2 text-[11px] text-tertiary">
          {segments.map((segment) => (
            <span key={segment.label} className="min-w-0 truncate">
              {segment.label} {formatTokens(segment.value)}
            </span>
          ))}
        </div>
      ) : (
        <p className="mt-2 text-[11px] text-tertiary">Detailed token split unavailable</p>
      )}
    </div>
  );
}

function splitTokenBreakdown(tokens: TokenBreakdown | null): Array<{ label: string; value: number; className: string }> {
  const cached = Math.min(Math.max(tokens?.cached_input_tokens ?? 0, 0), Math.max(tokens?.input_tokens ?? 0, 0));
  const input = Math.max((tokens?.input_tokens ?? 0) - cached, 0);
  const output = Math.max(tokens?.output_tokens ?? 0, 0);
  return [
    { label: 'Input', value: input, className: 'bg-data-primary' },
    { label: 'Cached', value: cached, className: 'bg-data-secondary' },
    { label: 'Output', value: output, className: 'bg-data-tertiary' },
  ];
}

function visibleTotalTokens(tokens: TokenBreakdown): number {
  return Math.max(tokens.total_tokens, tokens.input_tokens + tokens.output_tokens);
}

function formatTokens(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return '--';
  return Math.round(value).toLocaleString();
}

function formatUSD(value: number): string {
  if (!Number.isFinite(value)) return '--';
  return value.toFixed(2);
}

function sourceQualityLabel(value: 'detailed' | 'approximate' | null | undefined): string {
  if (value === 'detailed') return 'Detailed events';
  if (value === 'approximate') return 'Thread fallback';
  return 'No source yet';
}
