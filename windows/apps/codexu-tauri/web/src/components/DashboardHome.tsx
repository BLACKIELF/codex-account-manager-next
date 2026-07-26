import { Activity, Calendar, Clock, TrendingUp } from 'lucide-react';
import type { LocalUsage } from '../types/models';
import { LeadershipCommandRail, LeadershipOrbit } from './LeadershipPanel';
import { StatCard } from './StatCard';
import { ThreadList } from './ThreadList';
import { TokenBarChart } from './TokenBarChart';
import { ProjectBoard } from './ProjectBoard';
import { ToolUsageList } from './ToolUsageList';
import { TrendChart } from './TrendChart';
import { LEADERSHIP_BANDS, resolveLeadershipBand } from '../utils/leadershipTitles';

interface DashboardHomeProps {
  usage: LocalUsage | null | undefined;
  onOpenLeadership: () => void;
}

export function DashboardHome({ usage, onOpenLeadership }: DashboardHomeProps) {
  const hasUsage = usage !== null && usage !== undefined;
  const report = usage?.leadership?.reports?.[0] ?? null;

  const detailed = usage?.detailed_usage ?? null;
  const mix = buildTokenMix(detailed);
  const hasMixData = mix.total > 0;

  const score = hasUsage ? report?.score ?? null : null;
  const evidenceRatio = report?.evidence_coverage ?? 0;
  const activeBand = resolveLeadershipBand(score, evidenceRatio, report?.active_day_count ?? 0);
  const hasSignal = activeBand !== null;
  const scoreForVisual = hasSignal && score !== null ? Math.max(0, Math.min(100, Math.round(score))) : 0;

  return (
    <div className="space-y-6 dashboard-home">
      <div className="grid grid-cols-1 lg:grid-cols-[minmax(240px,1.1fr)_minmax(260px,0.95fr)_minmax(250px,1fr)] gap-4">
        <section className="glass-panel p-5 dashboard-home-leadership" aria-label="Leadership summary">
          <div className="text-xs text-tertiary uppercase tracking-wide">AI Leadership</div>
          <h2 className="text-2xl font-semibold text-primary leading-tight mt-1">
            {hasSignal
              ? `${activeBand.zhName} / ${activeBand.enName}`
              : hasUsage
                ? 'Leadership score pending'
                : 'No usage snapshot yet'}
          </h2>
          <p className="text-sm text-secondary mt-1">
            {hasSignal
              ? `Period ${report?.period} | ${report?.active_day_count ?? 0} active days | Evidence ${Math.round(
                  evidenceRatio * 100,
                )}%`
              : hasUsage
                ? `Record insufficient for authoritative title`
                : 'Data not ready. Refresh to load local snapshots.'}
          </p>

          <div className="mt-3 flex items-center gap-2 flex-wrap">
            {hasSignal ? (
              <>
                <span className="px-2 py-1 rounded-full border border-accent/45 bg-accent/12 text-accent text-xs font-medium">
                  L{activeBand.level}
                </span>
                <span className="text-tertiary text-xs">Band {activeBand.scoreMin}-{activeBand.scoreMax}</span>
              </>
            ) : (
              <>
                <span className="px-2 py-1 rounded-full border border-status-warn/45 bg-status-warn/12 text-status-warn text-xs font-medium">
                  Record insufficient
                </span>
                <span className="text-tertiary text-xs">Record insufficient</span>
              </>
            )}
          </div>

          <div className="mt-4 dashboard-leadership-orbit-wrap">
            <LeadershipOrbit score={scoreForVisual} activeBand={activeBand} hasSignal={hasSignal} />
            <button
              className="mt-3 inline-flex items-center gap-1 text-xs text-secondary hover:text-primary"
              onClick={onOpenLeadership}
            >
              <TrendingUp size={14} />
              View Leadership detail
            </button>
          </div>
        </section>

        <section className="glass-panel p-5 dashboard-home-mix" aria-label="7-day token mix">
          <h3 className="text-sm font-semibold text-primary mb-3">7-day Token mix</h3>
          <p className="text-xs text-tertiary mb-3">
            Source: 7-day usage signal from local detailed snapshot.
          </p>
          <div className="space-y-2.5 text-sm">
            <MixRow
              label="Input"
              value={mix.input}
              colorVar="--data-primary"
              hasData={hasMixData}
              total={mix.total}
            />
            <MixRow
              label="Cached input"
              value={mix.cached}
              colorVar="--data-secondary"
              hasData={hasMixData}
              total={mix.total}
            />
            <MixRow
              label="Output"
              value={mix.output}
              colorVar="--data-tertiary"
              hasData={hasMixData}
              total={mix.total}
            />
          </div>
          <div className="mt-4 text-xs text-tertiary">
            {hasMixData ? `Total 7-day tokens: ${formatNumber(mix.total)}` : 'Record insufficient'}
          </div>
          {!hasMixData ? (
            <div className="mt-2 text-xs text-status-warn">Not enough token detail yet. Continue using Codex locally.</div>
          ) : null}
        </section>

        <section className="glass-panel p-4 dashboard-home-metrics" aria-label="local metrics">
          <div className="grid grid-cols-1 gap-2">
            <StatCard
              label="Today"
              value={hasUsage ? formatNumber(usage?.today_tokens ?? 0) : '--'}
              subValue={detailed ? `$${detailed.today.estimated_cost_usd.toFixed(2)} est.` : 'Record insufficient'}
              icon={<Activity size={16} />}
              accent="primary"
            />
            <StatCard
              label="7-Day"
              value={hasUsage ? formatNumber(usage?.seven_day_tokens ?? 0) : '--'}
              subValue={detailed ? `$${detailed.seven_day.estimated_cost_usd.toFixed(2)} est.` : 'Record insufficient'}
              icon={<Calendar size={16} />}
              accent="secondary"
            />
            <StatCard
              label="Lifetime"
              value={hasUsage ? formatNumber(usage?.lifetime_tokens ?? 0) : '--'}
              subValue={detailed ? `$${detailed.lifetime.estimated_cost_usd.toFixed(2)} est.` : 'Record insufficient'}
              icon={<Clock size={16} />}
              accent="tertiary"
            />
          </div>
          <div className="mt-2 text-xs text-tertiary px-2 text-right">7-day & lifetime from local cache only</div>
        </section>
      </div>

      <section className="glass-panel p-4 sm:p-5 dashboard-home-rail" aria-label="Leadership command rail">
        <div className="text-xs text-tertiary uppercase tracking-wide">Progression</div>
        <h3 className="text-sm font-semibold text-primary mt-1 mb-3">L1-L7 command rail</h3>
        <LeadershipCommandRail bands={LEADERSHIP_BANDS} hasSignal={hasSignal} score={scoreForVisual} />
      </section>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <TokenBarChart data={usage?.daily_buckets ?? []} />
        <TrendChart trend={usage?.usage_trend ?? null} />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ThreadList threads={usage?.recent_threads ?? []} />
        <ProjectBoard projects={usage?.project_board?.recent_projects ?? []} />
      </div>
      <ToolUsageList tools={usage?.tool_usages ?? []} />

      {!hasUsage ? (
        <div className="glass-panel p-4 sm:p-5">
          <h3 className="text-sm font-semibold text-primary">Record status</h3>
          <p className="text-sm text-secondary mt-1">Record insufficient. Keep using Codex, then click Refresh.</p>
          <p className="text-xs text-tertiary mt-1">No local usage data available yet.</p>
        </div>
      ) : null}
    </div>
  );
}

function MixRow({
  label,
  value,
  colorVar,
  hasData,
  total,
}: {
  label: string;
  value: number;
  colorVar: string;
  hasData: boolean;
  total: number;
}) {
  const pct = hasData && total > 0 ? Math.max(0, Math.min(100, (value / total) * 100)) : 0;
  const width = hasData ? `${pct}%` : '0%';
  return (
    <article className="space-y-1.5">
      <div className="flex items-center justify-between text-xs text-tertiary">
        <span>{label}</span>
        <span>{hasData ? formatNumber(value) : '--'}</span>
      </div>
      <div className="h-2 rounded-full bg-surface border border-theme overflow-hidden">
        <div className="h-full rounded-full" style={{ width, backgroundColor: `var(${colorVar})` }} />
      </div>
    </article>
  );
}

function buildTokenMix(detailed: LocalUsage['detailed_usage']) {
  if (!detailed || !detailed.seven_day || !detailed.seven_day.tokens) {
    return { input: 0, cached: 0, output: 0, total: 0 };
  }

  const input = Number.isFinite(detailed.seven_day.tokens.input_tokens) ? detailed.seven_day.tokens.input_tokens : 0;
  const cached = Number.isFinite(detailed.seven_day.tokens.cached_input_tokens)
    ? detailed.seven_day.tokens.cached_input_tokens
    : 0;
  const output = Number.isFinite(detailed.seven_day.tokens.output_tokens)
    ? detailed.seven_day.tokens.output_tokens + (Number.isFinite(detailed.seven_day.tokens.reasoning_output_tokens)
      ? detailed.seven_day.tokens.reasoning_output_tokens
      : 0)
    : 0;
  const total = input + cached + output;

  return { input, cached, output, total };
}

function formatNumber(value: number): string {
  if (!Number.isFinite(value)) return '--';
  return Math.round(value).toLocaleString();
}

