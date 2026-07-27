import { Activity, Calendar, ClipboardList, Cpu, Database, TrendingUp, Wrench } from 'lucide-react';
import { useRef, useState, type KeyboardEvent } from 'react';
import type { LocalUsage, LeadershipReport } from '../types/models';
import { LEADERSHIP_BANDS, resolveLeadershipBand } from '../utils/leadershipTitles';
import { LeadershipCommandRail, LeadershipOrbit } from './LeadershipPanel';
import { MonthlyValueProgress } from './MonthlyValueProgress';
import { ProjectsPanel } from './ProjectsPanel';
import { UsagePanel } from './UsagePanel';
import { StatCard } from './StatCard';

interface DashboardHomeProps {
  usage: LocalUsage | null | undefined;
  onOpenLeadership: () => void;
}

type LowerTab = 'tasks' | 'usage' | 'projects' | 'skills';

const LOWER_TABS: Array<{ id: LowerTab; title: string }> = [
  { id: 'tasks', title: 'Tasks' },
  { id: 'usage', title: 'Usage' },
  { id: 'projects', title: 'Projects' },
  { id: 'skills', title: 'Skills' },
];

const formatUSD = (value: unknown): string => {
  if (typeof value !== 'number' || !Number.isFinite(value)) return '--';
  return value.toFixed(2);
};

export function DashboardHome({ usage, onOpenLeadership }: DashboardHomeProps) {
  const hasUsage = usage !== null && usage !== undefined;
  const report = usage?.leadership?.reports?.[0] ?? null;

  const detailed = usage?.detailed_usage ?? null;
  const tokenMix = buildTokenMix(detailed);
  const hasTokenDetail = tokenMix.hasData;

  const score = hasUsage ? report?.score ?? null : null;
  const evidenceRatio = report?.evidence_coverage ?? 0;
  const activeBand = resolveLeadershipBand(score, evidenceRatio, report?.active_day_count ?? 0);
  const hasSignal = activeBand !== null;
  const scoreForVisual = hasSignal && score !== null ? Math.max(0, Math.min(100, Math.round(score))) : 0;

  const [activeLowerTab, setActiveLowerTab] = useState<LowerTab>('tasks');
  const lowerTabRefs = useRef<Record<LowerTab, HTMLButtonElement | null>>({
    tasks: null,
    usage: null,
    projects: null,
    skills: null,
  });

  const focusLowerTabButton = (tabId: LowerTab) => {
    lowerTabRefs.current[tabId]?.focus();
  };

  const handleLowerTabKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') {
      return;
    }

    const currentIndex = LOWER_TABS.findIndex((item) => item.id === activeLowerTab);
    if (currentIndex < 0) return;

    event.preventDefault();
    event.stopPropagation();

    const nextIndex =
      event.key === 'ArrowRight'
        ? (currentIndex + 1) % LOWER_TABS.length
        : (currentIndex - 1 + LOWER_TABS.length) % LOWER_TABS.length;
    const nextTab = LOWER_TABS[nextIndex].id;
    setActiveLowerTab(nextTab);

    requestAnimationFrame(() => {
      focusLowerTabButton(nextTab);
    });
  };

  return (
    <div className="space-y-6 dashboard-home">
      <div className="grid dashboard-home-top-grid gap-4">
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
              ? `Period ${report?.period} | ${report?.active_day_count ?? 0} active days | Evidence ${Math.round(evidenceRatio * 100)}%`
              : hasUsage
                ? 'Record insufficient for authoritative title'
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

          <div className="mt-3 grid dashboard-home-leadership-metrics">
            <Pill icon={<Cpu size={14} />} label="28-day Agents" value={formatNumberish(report?.agent_count)} />
            <Pill icon={<TrendingUp size={14} />} label="AI Hours" value={formatHours(report?.ai_hours)} />
            <Pill icon={<Database size={14} />} label="Autonomous Hours" value={formatHours(report?.autonomous_hours)} />
            <Pill icon={<Activity size={14} />} label="Peak/Avg Concurrency" value={formatConcurrency(report)} />
          </div>

          <div className="mt-4 dashboard-leadership-orbit-wrap">
            <LeadershipOrbit score={scoreForVisual} activeBand={activeBand} hasSignal={hasSignal} />
            <button
              className="mt-3 inline-flex items-center gap-1 text-xs text-secondary hover:text-primary"
              onClick={onOpenLeadership}
              type="button"
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
              value={tokenMix.input}
              colorVar="--data-primary"
              hasData={hasTokenDetail}
              segmentTotal={tokenMix.segmentTotal}
            />
            <MixRow
              label="Cached input"
              value={tokenMix.cached}
              colorVar="--data-secondary"
              hasData={hasTokenDetail}
              segmentTotal={tokenMix.segmentTotal}
            />
            <MixRow
              label="Output"
              value={tokenMix.output}
              colorVar="--data-tertiary"
              hasData={hasTokenDetail}
              segmentTotal={tokenMix.segmentTotal}
            />
          </div>
          <div className="mt-4 text-xs text-tertiary">
            {hasTokenDetail ? `Total 7-day tokens: ${formatNumber(tokenMix.total)}` : 'Record insufficient'}
          </div>
          {!hasTokenDetail ? (
            <div className="mt-2 text-xs text-status-warn">Not enough token detail yet. Continue using Codex locally.</div>
          ) : null}
        </section>

        <section className="dashboard-home-metrics" aria-label="local metrics">
            <StatCard
              label="Today"
              value={formatNumber(hasUsage ? usage?.today_tokens ?? null : null)}
              subValue={detailed ? `$${formatUSD(detailed.today.estimated_cost_usd)} est.` : 'Record insufficient'}
              icon={<Activity size={16} />}
              accent="primary"
            />
            <StatCard
              label="7-Day"
              value={formatNumber(hasUsage ? usage?.seven_day_tokens ?? null : null)}
              subValue={detailed ? `$${formatUSD(detailed.seven_day.estimated_cost_usd)} est.` : 'Record insufficient'}
              icon={<Calendar size={16} />}
              accent="secondary"
            />
          <StatCard
            label="Lifetime"
            value={formatNumber(hasUsage ? usage?.lifetime_tokens ?? null : null)}
            subValue={detailed ? `$${formatUSD(detailed.lifetime.estimated_cost_usd)} est.` : 'Record insufficient'}
            icon={<TrendingUp size={16} />}
            accent="tertiary"
          />
          <p className="mt-2 text-xs text-tertiary px-1 text-right">7-day & lifetime from local cache only</p>
        </section>
      </div>

      <section className="glass-panel p-4 sm:p-5 dashboard-home-rail" aria-label="Leadership command rail">
        <div className="text-xs text-tertiary uppercase tracking-wide">Progression</div>
        <h3 className="text-sm font-semibold text-primary mt-1 mb-3">L1-L7 command rail</h3>
        <LeadershipCommandRail
          bands={LEADERSHIP_BANDS}
          hasSignal={hasSignal}
          score={scoreForVisual}
          onOpenLeadership={onOpenLeadership}
        />
      </section>

      <MonthlyValueProgress usage={usage} />

      <div
        onKeyDown={handleLowerTabKeyDown}
        role="tablist"
        aria-label="Dashboard lower tabs"
        className="flex items-center gap-1.5 flex-wrap rounded-2xl p-1 glass-toolbar"
      >
        {LOWER_TABS.map((tab) => (
          <button
            key={tab.id}
            id={`dashboard-home-tab-${tab.id}`}
            role="tab"
            aria-selected={activeLowerTab === tab.id}
            aria-controls={`dashboard-home-panel-${tab.id}`}
            tabIndex={activeLowerTab === tab.id ? 0 : -1}
            ref={(element) => {
              lowerTabRefs.current[tab.id] = element;
            }}
            onClick={() => setActiveLowerTab(tab.id)}
            className={`px-3 py-2 rounded-xl text-sm transition-all min-w-[90px] ${
              activeLowerTab === tab.id ? 'glass-button-solid' : 'text-secondary glass-button'
            }`}
          >
            {tab.title}
          </button>
        ))}
      </div>

      {activeLowerTab === 'tasks' && (
        <section
          role="tabpanel"
          id="dashboard-home-panel-tasks"
          aria-labelledby="dashboard-home-tab-tasks"
          className="glass-panel p-4 sm:p-5"
        >
          <div className="flex items-center gap-2">
            <ClipboardList size={16} />
            <h3 className="text-sm font-semibold text-primary">Tasks</h3>
          </div>
          <p className="text-sm text-secondary mt-2">
            Task status is not available in the current local snapshot.
          </p>
          <p className="text-sm text-secondary mt-2">
            Threads are separate local records and are not inferred as tasks here.
          </p>
          <p className="text-xs text-tertiary mt-3">Task details will appear when the local snapshot provides task status.</p>
        </section>
      )}

      {activeLowerTab === 'usage' && (
        <section
          role="tabpanel"
          id="dashboard-home-panel-usage"
          aria-labelledby="dashboard-home-tab-usage"
        >
          <UsagePanel usage={usage} />
        </section>
      )}

      {activeLowerTab === 'projects' && (
        <section
          role="tabpanel"
          id="dashboard-home-panel-projects"
          aria-labelledby="dashboard-home-tab-projects"
        >
          <ProjectsPanel
            projects={usage?.project_board?.recent_projects ?? []}
            tools={usage?.tool_usages ?? []}
          />
        </section>
      )}

      {activeLowerTab === 'skills' && (
        <section
          role="tabpanel"
          id="dashboard-home-panel-skills"
          aria-labelledby="dashboard-home-tab-skills"
          className="glass-panel p-4 sm:p-5"
        >
          <div className="flex items-center gap-2">
            <Wrench size={16} />
            <h3 className="text-sm font-semibold text-primary">Skills</h3>
          </div>
          <p className="text-sm text-secondary mt-2">
            Skill usage is not available in the current local snapshot.
          </p>
          <p className="text-xs text-tertiary mt-1">
            This area will show skill usage when that record becomes available.
          </p>
        </section>
      )}
    </div>
  );
}

function MixRow({
  label,
  value,
  colorVar,
  hasData,
  segmentTotal,
}: {
  label: string;
  value: number;
  colorVar: string;
  hasData: boolean;
  segmentTotal: number;
}) {
  const pct = hasData && segmentTotal > 0 ? Math.max(0, Math.min(100, (value / segmentTotal) * 100)) : 0;
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
  const hasSevenDayTokens =
    detailed?.seven_day?.tokens &&
    Number.isFinite(detailed.seven_day.tokens.input_tokens) &&
    Number.isFinite(detailed.seven_day.tokens.cached_input_tokens) &&
    Number.isFinite(detailed.seven_day.tokens.output_tokens) &&
    Number.isFinite(detailed.seven_day.tokens.total_tokens);

  if (!hasSevenDayTokens) {
    return { input: 0, cached: 0, output: 0, total: 0, segmentTotal: 0, hasData: false };
  }

  const rawInput = nonNegativeNumber(detailed.seven_day.tokens.input_tokens);
  const rawCached = nonNegativeNumber(detailed.seven_day.tokens.cached_input_tokens);
  const rawOutput = nonNegativeNumber(detailed.seven_day.tokens.output_tokens);
  const rawTotal = nonNegativeNumber(detailed.seven_day.tokens.total_tokens);

  const cached = clamp(Math.max(0, rawCached), 0, rawInput);
  const input = clamp(rawInput - cached, 0, Infinity);
  const output = clamp(rawOutput, 0, Infinity);
  const visibleTotal = clamp(Math.max(rawTotal, rawInput + rawOutput), 0, Infinity);
  const segmentTotal = clamp(input + cached + output, 0, Infinity);

  return { input, cached, output, total: visibleTotal, segmentTotal, hasData: true };
}

function formatNumber(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return '--';
  return Math.round(value).toLocaleString();
}

function formatHours(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return '--';
  return `${value.toFixed(1)}h`;
}

function formatConcurrency(report: LeadershipReport | null): string {
  if (!report) return '--';
  const peakConcurrency = report.peak_concurrency;
  const avgParallelism = report.average_parallelism;

  const peak = typeof peakConcurrency === 'number' && Number.isFinite(peakConcurrency) ? Math.round(peakConcurrency) : null;
  const avg = typeof avgParallelism === 'number' && Number.isFinite(avgParallelism) ? avgParallelism.toFixed(1) : null;
  if (peak === null && avg === null) return '--';
  return `${peak === null ? '--' : peak} / ${avg === null ? '--' : `${avg}x`}`;
}

function formatNumberish(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return '--';
  return String(Math.round(value));
}

function nonNegativeNumber(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, value);
}

function clamp(value: number, min: number, max: number): number {
  const lowerBounded = Math.max(min, value);
  return Math.min(max, lowerBounded);
}

function Pill({
  icon,
  label,
  value,
}: {
  icon: JSX.Element;
  label: string;
  value: string;
}) {
  return (
    <div className="rounded-lg border border-theme bg-surface-inset px-3 py-2">
      <p className="inline-flex items-center gap-1 text-xs text-tertiary">
        <span className="text-secondary inline-flex" aria-hidden="true">
          {icon}
        </span>
        <span>{label}</span>
      </p>
      <p className="text-sm font-medium text-primary mt-1">{value}</p>
    </div>
  );
}
