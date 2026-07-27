import {
  AlertTriangle,
  BookOpenText,
  Brain,
  Calendar,
  Cpu,
  Eye,
  Globe,
  ShieldQuestion,
  TrendingUp,
} from 'lucide-react';
import { Fragment, type CSSProperties, type ReactNode } from 'react';
import type {
  CodexLeadershipSignal,
  LeadershipDayPoint,
  LeadershipDimension,
  LeadershipProjectContribution,
  LeadershipReport,
} from '../types/models';
import { LEADERSHIP_BANDS, type LeadershipBand, resolveLeadershipBand } from '../utils/leadershipTitles';

interface LeadershipPanelProps {
  signal: CodexLeadershipSignal | null;
}

type DimensionKind = LeadershipDimension['kind'];

type SortField = 'ai_hours' | 'agent_count' | 'autonomous_hours';

interface DimensionMeta {
  label: string;
  weight: string;
  description: string;
}

const DIMENSION_META: Record<DimensionKind, DimensionMeta> = {
  span: {
    label: 'Span',
    weight: '30%',
    description: 'How broadly leadership extends across workers and active windows.',
  },
  leverage: {
    label: 'Leverage',
    weight: '30%',
    description: 'How much additional AI throughput is unlocked by coordination.',
  },
  orchestration: {
    label: 'Orchestration',
    weight: '25%',
    description: 'How evenly execution is distributed across projects.',
  },
  autonomy: {
    label: 'Autonomy',
    weight: '15%',
    description: 'How much execution continues without manual intervention.',
  },
};

export function LeadershipPanel({ signal }: LeadershipPanelProps) {
  if (!signal) {
    return (
      <section className="glass-panel p-6 sm:p-7 space-y-3">
        <h2 className="text-lg font-semibold text-primary">AI Leadership</h2>
        <p className="text-sm text-secondary">
          No leadership snapshot yet. Keep usage running and refresh to load leadership snapshot.
        </p>
      </section>
    );
  }

  const report = getReportFromSignal(signal);
  if (!report) {
    return (
      <section className="glass-panel p-6 sm:p-7 space-y-3">
        <h2 className="text-lg font-semibold text-primary">AI Leadership</h2>
        <p className="text-sm text-secondary">
          Leadership report is not ready yet for period {signal.period}. Refresh after more local snapshots are
          collected.
        </p>
      </section>
    );
  }

  const score = signal.score;
  const evidenceRatio = Number.isFinite(signal.evidence_coverage) ? signal.evidence_coverage : 0;
  const activeBand = resolveLeadershipBand(score, evidenceRatio, report.active_day_count);
  const hasSignal = score !== null && activeBand !== null;
  const confidence = Math.max(0, Math.min(100, Math.round(evidenceRatio * 100)));
  const trend = buildTrendSummary(report.daily_points);
  const sortedProjects = sortProjects(report.projects, 'ai_hours');
  const latest = report.daily_points.length > 0 ? report.daily_points[report.daily_points.length - 1] : null;
  const isStub = signal.model_version.toLowerCase().includes('stub');
  const scoreForVisual = hasSignal ? Math.max(0, Math.min(100, Math.round(score ?? 0))) : 0;

  return (
    <div className="space-y-6">
      {isStub ? (
        <section className="glass-panel border border-status-warn/30 bg-status-warn/8 p-4 text-sm">
          <div className="flex items-start gap-2">
            <AlertTriangle size={16} className="text-status-warn mt-0.5" />
            <div>
              <p className="font-semibold text-primary">Fallback snapshot mode</p>
              <p className="text-xs text-tertiary mt-1">
                Snapshot source is {signal.model_version}; fields may be fallback-approximated.
              </p>
            </div>
          </div>
        </section>
      ) : null}

      <section className="glass-panel p-5 space-y-5">
        <div className="leadership-hero">
          <div className="leadership-hero-left">
            <div className="text-xs text-tertiary uppercase tracking-wide">AI Leadership</div>
            <h2 className="text-2xl sm:text-3xl font-semibold mt-1 text-primary leading-tight">
              {hasSignal ? `${activeBand?.zhName} / ${activeBand?.enName}` : 'Leadership score pending'}
            </h2>
            <p className="text-sm text-secondary mt-1">
              {hasSignal
                ? `Period ${report.period} | ${report.active_day_count} active days | Evidence ${confidence}%`
                : `Record insufficient for authoritative title | Period ${report.period}`}
            </p>
            <div className="mt-3 flex items-center gap-2">
              {hasSignal ? (
                <>
                  <span className="px-2 py-1 rounded-full border border-accent/45 bg-accent/12 text-accent text-xs font-medium">
                    L{activeBand?.level}
                  </span>
                  <span className="text-tertiary text-xs">Band {activeBand?.scoreMin}-{activeBand?.scoreMax}</span>
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
          </div>
          <div className="leadership-hero-right">
                <LeadershipOrbit score={scoreForVisual} activeBand={activeBand} hasSignal={hasSignal} />
          </div>
        </div>

        <LeadershipCommandRail
          bands={LEADERSHIP_BANDS}
          hasSignal={hasSignal}
          score={hasSignal ? scoreForVisual : 0}
        />

        <div className="leadership-hero-metrics-grid">
          <Pill icon={<Brain size={14} />} label="Leadership Score" value={formatScore(hasSignal ? scoreForVisual : null)} />
          <Pill icon={<Calendar size={14} />} label="28-day Agents" value={formatNumberish(report.agent_count)} />
          <Pill icon={<Globe size={14} />} label="AI Hours" value={formatHours(report.ai_hours)} />
          <Pill icon={<TrendingUp size={14} />} label="Peak Concurrency" value={formatNumberish(report.peak_concurrency)} />
        </div>
      </section>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="glass-panel p-5">
          <div className="flex items-center gap-2 mb-3">
            <Brain size={16} className="text-secondary" />
            <h3 className="text-sm font-semibold text-primary">Dimension Scores</h3>
          </div>
          <div className="space-y-3">
            {report.dimensions.map((dimension) => {
              const meta = DIMENSION_META[dimension.kind];
              const pct = clampPercent(dimension.score);
              const confidencePct = Math.round(dimension.confidence * 100);
              return (
                <article
                  key={dimension.kind}
                  className="space-y-2 rounded-lg border border-theme bg-surface-inset p-3"
                >
                  <div className="flex items-center justify-between gap-2 text-sm">
                    <span className="text-primary font-medium">
                      {meta.label}
                      <span className="text-tertiary ml-2">({meta.weight})</span>
                    </span>
                    <span className="text-tertiary">
                      {dimension.score.toFixed(1)} / 100 | {confidencePct}% conf
                    </span>
                  </div>
                  <p className="text-xs text-tertiary">{meta.description}</p>
                  <div className="h-2 bg-surface rounded-full overflow-hidden">
                    <div className="h-full rounded-full bg-accent/90" style={{ width: `${pct}%` }} />
                  </div>
                  <p className="text-xs text-secondary">
                    Value: <span className="text-primary">{dimension.summary_value.toFixed(2)}</span>
                  </p>
                </article>
              );
            })}
            {report.dimensions.length === 0 && <p className="text-sm text-secondary">No dimension data yet.</p>}
          </div>
        </div>

        <div className="glass-panel p-5">
          <div className="flex items-center gap-2 mb-3">
            <BookOpenText size={16} className="text-secondary" />
            <h3 className="text-sm font-semibold text-primary">Score Path</h3>
          </div>
          <p className="text-sm text-secondary">This score is composed of span, leverage, orchestration, and autonomy.</p>
          <div className="mt-4 grid grid-cols-2 gap-2">
            <Pill icon={<Globe size={14} />} label="Core score" value={formatCoreScore(report.core_score)} />
            <Pill icon={<Eye size={14} />} label="Maturity" value={report.maturity.toFixed(1)} />
            <Pill icon={<Cpu size={14} />} label="Evidence" value={`${confidence}%`} />
            <Pill icon={<Calendar size={14} />} label="Active window" value={`${report.active_day_count} days`} />
          </div>
          {latest ? (
            <div className="mt-4 p-3 rounded-lg border border-theme bg-surface-inset text-sm">
              <p className="text-primary font-medium">Latest day signal</p>
              <p className="text-xs text-secondary mt-1">
                {formatPointDate(latest.day)} | {latest.agent_count} agents, {latest.ai_hours.toFixed(1)}h AI hours,
                peak {latest.peak_concurrency}
              </p>
            </div>
          ) : (
            <p className="text-xs text-tertiary mt-4">No daily trend data yet.</p>
          )}
        </div>
      </section>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="glass-panel p-5">
          <div className="flex items-center justify-between mb-3">
            <h3 className="text-sm font-semibold text-primary">Leading Projects</h3>
            <span className="text-xs text-tertiary">Sorted by AI hours</span>
          </div>
          {sortedProjects.length === 0 ? (
            <p className="text-sm text-secondary">No project contribution available.</p>
          ) : (
            <div className="space-y-2">
              {sortedProjects.slice(0, 5).map((project, index) => (
                <div
                  key={`${project.project_id}-${project.agent_count}-${index}`}
                  className="rounded-lg border border-theme bg-surface-inset p-3 text-sm"
                >
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-primary font-medium truncate">{project.project_name || 'Unknown'}</span>
                    <span className="text-tertiary text-xs">#{index + 1}</span>
                  </div>
                  <p className="text-xs text-secondary mt-1">
                    Agents {project.agent_count} | AI Hours {project.ai_hours.toFixed(1)} | Autonomous{' '}
                    {project.autonomous_hours.toFixed(1)}h
                  </p>
                  <div className="mt-2 h-1.5 bg-surface rounded-full overflow-hidden">
                    <div
                      className="h-full rounded-full bg-accent/80"
                      style={{
                        width: `${Math.min(
                          100,
                          (project.ai_hours / Math.max(...report.projects.map((p) => p.ai_hours), 1)) * 100,
                        )}%`,
                      }}
                    />
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="glass-panel p-5">
          <div className="flex items-center gap-2 mb-3">
            <TrendingUp size={16} className="text-secondary" />
            <h3 className="text-sm font-semibold text-primary">28-day Trend Snapshot</h3>
          </div>
          {report.daily_points.length === 0 ? (
            <p className="text-sm text-secondary">No trend points available.</p>
          ) : (
            <div className="space-y-2">
              {report.daily_points
                .slice(-8)
                .map((point) => (
                  <div key={point.day} className="grid grid-cols-4 items-center text-sm text-secondary">
                    <span className="text-xs sm:text-sm">{formatPointDate(point.day)}</span>
                    <span>{point.agent_count} agents</span>
                    <span>{point.ai_hours.toFixed(1)}h</span>
                    <span>parallel x{point.peak_concurrency}</span>
                  </div>
                ))}
            </div>
          )}
          <p className="text-xs text-tertiary mt-3">Avg parallelism: {formatRatio(report.average_parallelism)}</p>
          {trend ? (
            <p className="text-xs text-secondary mt-1">
              {trend.direction === 'up' ? 'Momentum up' : 'Momentum down'} {trend.delta >= 0 ? '+' : ''}
              {trend.delta.toFixed(2)}h vs previous sample
            </p>
          ) : null}
        </div>
      </section>
    </div>
  );
}

export function LeadershipOrbit({
  score,
  hasSignal,
  activeBand,
}: {
  score: number;
  hasSignal: boolean;
  activeBand: LeadershipBand | null;
}) {
  const radius = 56;
  const circumference = Math.round(2 * Math.PI * radius);
  const safeScore = hasSignal ? clampPercent(score) : 0;
  const dashOffset = circumference - (safeScore / 100) * circumference;

  return (
    <div className="leadership-orbit-wrap">
      <div className="leadership-orbit" role="img" aria-label="Leadership score orbit">
        {hasSignal && activeBand ? (
            <img src={activeBand.badge} alt="Leadership badge" className="leadership-orbit-badge" />
        ) : (
          <ShieldQuestion size={40} className="leadership-orbit-neutral-icon" />
        )}
        <svg viewBox="0 0 140 140" className="leadership-orbit-ring">
          <circle cx="70" cy="70" r={radius} className="orbit-track" fill="none" />
          {hasSignal ? (
            <circle
              cx="70"
              cy="70"
              r={radius}
              className="orbit-value"
              strokeDasharray={circumference}
              strokeDashoffset={dashOffset}
            />
          ) : null}
        </svg>
      </div>
      <div className={`leadership-orbit-score ${!hasSignal ? 'leadership-orbit-score-empty' : ''}`}>
        {hasSignal ? `${safeScore}` : '--'}
      </div>
    </div>
  );
}

export function LeadershipCommandRail({
  bands,
  hasSignal,
  score,
  onOpenLeadership,
}: {
  bands: readonly LeadershipBand[];
  hasSignal: boolean;
  score: number;
  onOpenLeadership?: () => void;
}) {
  const safeScore = clampPercent(score);
  const currentBand = bands.find((band) => safeScore >= band.scoreMin && safeScore <= band.scoreMax) ?? null;
  const hasInteractive = typeof onOpenLeadership === 'function';
  const signalLabel = currentBand
    ? `Open AI Leadership detail for score ${safeScore}, L${currentBand.level} ${currentBand.zhName} / ${currentBand.enName}`
    : 'Open AI Leadership detail';
  const railContent = (
    <>
      <div className="leadership-rail-track" />
      {hasSignal ? (
        <div
          className="leadership-rail-fill"
          style={{ ['--progress' as keyof CSSProperties]: `${safeScore}%` } as CSSProperties}
        />
      ) : null}

      {hasSignal ? (
        <div className="leadership-threshold-points">
          {bands.map((band) => {
            const isCurrent = score >= band.scoreMin && score <= band.scoreMax;
            const thresholdPercent = clampPercent((band.scoreMin / 100) * 100);
            const isLargeBadge = band.level === 6;
            const isLeftEdge = band.scoreMin === 0;
            const nodeClass = [
              'leadership-rail-node',
              isCurrent ? 'leadership-rail-node-current' : '',
              isLeftEdge ? 'leadership-rail-node-left-edge' : '',
            ]
              .filter(Boolean)
              .join(' ');

            return (
              <Fragment key={band.id}>
                <div
                  className={nodeClass}
                  style={{ left: `${thresholdPercent}%` }}
                  aria-label={`Band ${band.level} start at ${band.scoreMin}`}
                >
                  <span className="leadership-rail-dot" aria-hidden="true" />
                  <span className="leadership-rail-node-label">L{band.level}</span>
                </div>
                <img
                  src={band.badge}
                  alt=""
                  style={{ left: `${thresholdPercent}%` }}
                  className={[
                    'leadership-rail-badge',
                    isCurrent ? 'leadership-rail-badge-current' : '',
                    isLeftEdge ? 'leadership-rail-badge-left-edge' : '',
                    isLargeBadge ? 'leadership-rail-badge-large' : '',
                  ]
                    .filter(Boolean)
                    .join(' ')}
                />
              </Fragment>
            );
          })}
          <div className="leadership-rail-score-marker" style={{ left: `${safeScore}%` }}>
            <span className="leadership-rail-score-text">{`${safeScore} / 100`}</span>
            <span className="leadership-rail-score-stem" aria-hidden="true" />
            <span className="leadership-rail-score-pin" aria-hidden="true" />
          </div>
        </div>
      ) : null}
    </>
  );

  if (!hasInteractive) {
    return (
      <div className="leadership-command-rail" aria-label="AI leadership maturity command rail">
        {railContent}
        <span className="sr-only">Leadership details unavailable</span>
      </div>
    );
  }

  return (
    <button
      type="button"
      onClick={onOpenLeadership}
      className="leadership-command-rail leadership-command-rail-button leadership-command-rail-clickable"
      aria-label={hasSignal ? signalLabel : 'Open AI Leadership detail'}
    >
      {railContent}
    </button>
  );
}

function getReportFromSignal(signal: CodexLeadershipSignal): LeadershipReport | null {
  if (!signal.report) return null;
  const byPeriod = signal.report.reports.find((item) => item.period === signal.period);
  return byPeriod ?? signal.report.reports[0] ?? null;
}

function Pill({
  icon,
  label,
  value,
}: {
  icon: ReactNode;
  label: string;
  value: number | string;
}) {
  return (
    <div className="rounded-lg border border-theme bg-surface-inset px-3 py-2">
      <p className="inline-flex items-center gap-1 text-xs text-tertiary">
        <span className="text-secondary inline-flex">{icon}</span> {label}
      </p>
      <p className="text-sm font-medium text-primary mt-1">{value}</p>
    </div>
  );
}

function clampPercent(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(100, value));
}

function sortProjects(
  projects: LeadershipProjectContribution[],
  field: SortField,
): LeadershipProjectContribution[] {
  return [...projects].sort((a, b) => {
    const left = getProjectSortValue(a, field);
    const right = getProjectSortValue(b, field);
    if (right !== left) return right - left;
    return b.agent_count - a.agent_count;
  });
}

function getProjectSortValue(
  project: LeadershipProjectContribution,
  field: SortField,
): number {
  if (field === 'agent_count') return project.agent_count;
  if (field === 'autonomous_hours') return project.autonomous_hours;
  return project.ai_hours;
}

function buildTrendSummary(
  points: LeadershipDayPoint[],
): { direction: 'up' | 'down'; delta: number } | null {
  if (points.length < 2) return null;
  const latest = points[points.length - 1]?.ai_hours ?? 0;
  const prev = points[points.length - 2]?.ai_hours ?? 0;
  const delta = latest - prev;
  return {
    direction: delta >= 0 ? 'up' : 'down',
    delta,
  };
}

function formatPointDate(ms: number): string {
  const d = new Date(ms);
  return `${d.getMonth() + 1}/${d.getDate()}`;
}

function formatCoreScore(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return 'N/A';
  return value.toFixed(1);
}

function formatHours(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return '--';
  return `${value.toFixed(1)}h`;
}

function formatNumberish(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return '--';
  return String(value);
}

function formatScore(value: number | null): string {
  if (value == null || !Number.isFinite(value)) return '--';
  return `${Math.round(value)} / 100`;
}

function formatRatio(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return 'N/A';
  return `${value.toFixed(2)}x`;
}
