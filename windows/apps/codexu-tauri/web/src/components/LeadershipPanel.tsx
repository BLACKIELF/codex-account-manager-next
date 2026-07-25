import {
  ArrowDown,
  ArrowUp,
  BadgeCheck,
  BookOpenText,
  Brain,
  Calendar,
  Clock3,
  Cpu,
  Eye,
  Globe,
  Lightbulb,
  TrendingUp,
  Users,
} from 'lucide-react';
import type { ReactNode } from 'react';
import type {
  LeadershipDashboardSnapshot,
  LeadershipDayPoint,
  LeadershipDimension,
  LeadershipProjectContribution,
} from '../types/models';

interface LeadershipPanelProps {
  snapshot: LeadershipDashboardSnapshot | null;
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
    description: 'Counts how much you are actively coordinating active workforce across time windows.',
  },
  leverage: {
    label: 'Leverage',
    weight: '30%',
    description: 'Measures the scale effect from parallel agent deployment and repeated cycles.',
  },
  orchestration: {
    label: 'Orchestration',
    weight: '25%',
    description: 'Evaluates role mixing, project distribution, and cross-runtime coordination quality.',
  },
  autonomy: {
    label: 'Autonomy',
    weight: '15%',
    description: 'Looks at how much execution is autonomous versus manual trigger dependency.',
  },
};

export function LeadershipPanel({ snapshot }: LeadershipPanelProps) {
  if (!snapshot || snapshot.reports.length === 0) {
    return (
      <div className="glass-panel p-6 sm:p-7">
        <h2 className="text-lg font-semibold text-primary">AI Leadership</h2>
        <p className="text-sm text-secondary mt-2">
          Leadership data not available yet. Open settings or refresh to update.
        </p>
      </div>
    );
  }

  const report = snapshot.reports[0];
  const title = report.title?.name ?? 'No Title';
  const subtitle = report.title ? `${report.title.english_name} · ${title}` : 'AI leadership profile';
  const score = report.score ?? 0;
  const confidence = Math.round(report.evidence_coverage * 100);
  const trend = buildTrendSummary(report.daily_points);
  const sortedProjects = sortProjects(report.projects, 'ai_hours');
  const latest = report.daily_points.length > 0 ? report.daily_points[report.daily_points.length - 1] : null;
  const scoreBand = buildScoreBand(score);

  return (
    <div className="space-y-6">
      <section className="glass-panel p-5 space-y-5">
        <div className="flex items-start justify-between gap-4">
          <div>
            <p className="text-xs text-tertiary uppercase tracking-wide">AI Leadership</p>
            <h2 className="text-2xl sm:text-3xl font-semibold mt-1 text-primary leading-tight">{subtitle}</h2>
            <p className="text-sm text-secondary mt-1">
              Period: {report.period} · snapshot {snapshot.model_version}
            </p>
            <p className="text-xs text-tertiary mt-2">{scoreBand}</p>
          </div>
          <div className="w-20 h-20 rounded-full bg-surface-inset border border-theme flex flex-col items-center justify-center text-center">
            <span className="text-xs text-tertiary">Score</span>
            <span className="text-2xl font-semibold text-primary leading-none">{score}</span>
            <span className="text-[11px] text-tertiary">/100</span>
          </div>
        </div>
        <div className="h-2.5 w-full rounded-full bg-surface-inset overflow-hidden">
          <div className="h-full rounded-full bg-accent" style={{ width: `${clampPercent(score)}%` }} />
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-2">
          <Pill icon={<BadgeCheck size={14} />} label="Evidence confidence" value={`${confidence}%`} />
          <Pill icon={<Calendar size={14} />} label="Active days (28d)" value={report.active_day_count} />
          <Pill icon={<Cpu size={14} />} label="Project count" value={report.project_count} />
          <Pill icon={<Users size={14} />} label="Agent count" value={report.agent_count ?? 'N/A'} />
          <Pill icon={<Clock3 size={14} />} label="Peak concurrency" value={report.peak_concurrency ?? 'N/A'} />
          <Pill icon={<Globe size={14} />} label="AI hours" value={formatHours(report.ai_hours)} />
          <Pill
            icon={<Lightbulb size={14} />}
            label="Autonomous hours"
            value={formatHours(report.autonomous_hours)}
          />
          <Pill
            icon={trend?.direction === 'up' ? <ArrowUp size={14} /> : <ArrowDown size={14} />}
            label="Trend (24h)"
            value={trend ? `${trend.delta >= 0 ? '+' : ''}${trend.delta.toFixed(2)}h` : 'N/A'}
          />
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
                <article key={dimension.kind} className="space-y-2 rounded-lg border border-theme bg-surface-inset p-3">
                  <div className="flex items-center justify-between gap-2 text-sm">
                    <span className="text-primary font-medium">
                      {meta.label}
                      <span className="text-tertiary ml-2">({meta.weight})</span>
                    </span>
                    <span className="text-tertiary">
                    {dimension.score.toFixed(1)} / 100 · {confidencePct}% conf
                    </span>
                  </div>
                  <p className="text-xs text-tertiary">{meta.description}</p>
                  <div className="h-2 bg-surface rounded-full overflow-hidden">
                    <div className="h-full rounded-full bg-accent/90" style={{ width: `${pct}%` }} />
                  </div>
                  <p className="text-xs text-secondary">
                    Summary value: <span className="text-primary">{dimension.summary_value.toFixed(2)}</span>
                  </p>
                </article>
              );
            })}
            {report.dimensions.length === 0 && (
              <p className="text-sm text-secondary">No dimension data yet.</p>
            )}
          </div>
        </div>

        <div className="glass-panel p-5">
          <div className="flex items-center gap-2 mb-3">
            <BookOpenText size={16} className="text-secondary" />
            <h3 className="text-sm font-semibold text-primary">Score Path</h3>
          </div>
          <p className="text-sm text-secondary">
            This score follows the 4-step leadership chain of span, leverage, orchestration and autonomy.
            It reflects only data quality-filtered evidence and excludes estimated confidence-only evidence from score
            contribution.
          </p>
          <div className="mt-4 grid grid-cols-2 gap-2">
            <Pill icon={<TrendingUp size={14} />} label="Core score" value={formatCoreScore(report.core_score)} />
            <Pill icon={<Eye size={14} />} label="Maturity" value={report.maturity.toFixed(1)} />
            <Pill icon={<BadgeCheck size={14} />} label="Evidence" value={`${confidence}%`} />
            <Pill
              icon={<Calendar size={14} />}
              label="Active window"
              value={`${report.active_day_count} days`}
            />
          </div>

          {latest ? (
            <div className="mt-4 p-3 rounded-lg border border-theme bg-surface-inset text-sm">
              <p className="text-primary font-medium">Latest day signal</p>
              <p className="text-xs text-secondary mt-1">
                {formatPointDate(latest.day)} · {latest.agent_count} agents, {latest.ai_hours.toFixed(1)}h AI hours,
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
              {sortedProjects.map((project, index) => (
                <div
                  key={`${project.project_id}-${project.agent_count}-${index}`}
                  className="rounded-lg border border-theme bg-surface-inset p-3 text-sm"
                >
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-primary font-medium truncate">
                      #{index + 1} {project.project_name || 'Unknown'}
                    </span>
                    <span className="text-tertiary text-xs">#{project.project_id}</span>
                  </div>
                  <p className="text-xs text-secondary mt-1">
                    Agents {project.agent_count} · AI Hours {project.ai_hours.toFixed(1)} · Autonomous{' '}
                    {project.autonomous_hours.toFixed(1)}h
                  </p>
                  <div className="mt-2 h-1.5 bg-surface rounded-full overflow-hidden">
                    <div
                      className="h-full rounded-full bg-accent/80"
                      style={{ width: `${Math.min(100, (project.ai_hours / Math.max(...report.projects.map((p) => p.ai_hours), 1)) * 100)}%` }}
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
                  <div
                    key={point.day}
                    className="grid grid-cols-4 items-center text-sm text-secondary"
                  >
                    <span className="text-xs sm:text-sm">{formatPointDate(point.day)}</span>
                    <span>{point.agent_count} agents</span>
                    <span>{point.ai_hours.toFixed(1)}h</span>
                    <span>parallel x{point.peak_concurrency}</span>
                  </div>
                ))}
            </div>
          )}
          <p className="text-xs text-tertiary mt-3">
            Avg parallelism: {formatRatio(report.average_parallelism)}
          </p>
          {trend ? (
            <p className="text-xs text-secondary mt-1">
              {trend.direction === 'up' ? 'Momentum ↑' : 'Momentum ↓'} {trend.delta >= 0 ? '+' : ''}
              {trend.delta.toFixed(2)}h vs previous sample
            </p>
          ) : null}
        </div>
      </section>
    </div>
  );
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

function buildScoreBand(score: number): string {
  if (score >= 90) return 'Tier: Architect';
  if (score >= 75) return 'Tier: Operator';
  if (score >= 60) return 'Tier: Navigator';
  if (score >= 45) return 'Tier: Co-Pilot';
  if (score >= 30) return 'Tier: Starter';
  return 'Tier: Rookie';
}

function sortProjects(projects: LeadershipProjectContribution[], field: SortField): LeadershipProjectContribution[] {
  return [...projects].sort((a, b) => {
    const left = getProjectSortValue(a, field);
    const right = getProjectSortValue(b, field);
    if (right !== left) return right - left;
    return b.agent_count - a.agent_count;
  });
}

function getProjectSortValue(project: LeadershipProjectContribution, field: SortField): number {
  if (field === 'agent_count') return project.agent_count;
  if (field === 'autonomous_hours') return project.autonomous_hours;
  return project.ai_hours;
}

function buildTrendSummary(points: LeadershipDayPoint[]): { direction: 'up' | 'down'; delta: number } | null {
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
  if (value == null || !Number.isFinite(value)) return 'N/A';
  return `${value.toFixed(1)}h`;
}

function formatRatio(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return 'N/A';
  return `${value.toFixed(2)}x`;
}
