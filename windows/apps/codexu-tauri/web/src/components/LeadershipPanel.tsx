import { Brain, Clock3, Cpu, Globe, Lightbulb, Sparkles, TrendingUp, Users } from 'lucide-react';
import type { ReactNode } from 'react';
import type { LeadershipDashboardSnapshot, LeadershipDimension } from '../types/models';

interface LeadershipPanelProps {
  snapshot: LeadershipDashboardSnapshot | null;
}

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
  const score = report.score ?? 0;
  const confidence = Math.round(report.evidence_coverage * 100);

  return (
    <div className="space-y-6">
      <section className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="glass-panel p-5">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs text-tertiary uppercase tracking-wide">AI Leadership</p>
              <h2 className="text-xl sm:text-2xl font-semibold mt-1 text-primary">{title}</h2>
              <p className="text-sm text-secondary mt-1">
                {report.period} - v{snapshot.model_version}
              </p>
            </div>
            <div className="w-20 h-20 rounded-full bg-surface-inset border border-theme flex items-center justify-center text-center">
              <div>
                <p className="text-xs text-tertiary">Score</p>
                <p className="text-2xl font-semibold text-primary leading-none">{score}</p>
              </div>
            </div>
          </div>
          <div className="mt-4 grid grid-cols-2 sm:grid-cols-3 gap-2">
            <Pill icon={<Users size={14} />} label="Active Days" value={report.active_day_count} />
            <Pill icon={<Cpu size={14} />} label="Projects" value={report.project_count} />
            <Pill icon={<Sparkles size={14} />} label="Evidence Confidence" value={`${confidence}%`} />
            <Pill
              icon={<Clock3 size={14} />}
              label="Peak Concurrency"
              value={report.peak_concurrency ?? 'N/A'}
            />
            <Pill icon={<Globe size={14} />} label="AI Hours" value={formatHours(report.ai_hours)} />
            <Pill
              icon={<Lightbulb size={14} />}
              label="Autonomous Hours"
              value={formatHours(report.autonomous_hours)}
            />
          </div>
        </div>

        <div className="glass-panel p-5">
          <div className="flex items-center gap-2 mb-3">
            <Brain size={16} className="text-secondary" />
            <h3 className="text-sm font-semibold text-primary">Dimension Scores</h3>
          </div>
          <div className="space-y-3">
            {report.dimensions.map((dimension) => {
              const pct = clampPercent(dimension.score);
              const confidencePct = Math.round(dimension.confidence * 100);
              return (
                <div key={dimension.kind}>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-primary capitalize">{formatDimensionLabel(dimension.kind)}</span>
                    <span className="text-tertiary">
                      {dimension.score.toFixed(1)} / 100 - c {confidencePct}%
                    </span>
                  </div>
                  <div className="h-2 bg-surface-inset rounded-full overflow-hidden mt-1">
                    <div
                      className="h-full rounded-full bg-accent transition-[width]"
                      style={{ width: `${pct}%` }}
                    />
                  </div>
                </div>
              );
            })}
            {report.dimensions.length === 0 && <p className="text-sm text-secondary">No dimension data yet.</p>}
          </div>
          <div className="flex items-center gap-2 mt-4">
            <TrendingUp size={14} className="text-secondary" />
            <p className="text-xs text-tertiary">
              Core score: {typeof report.core_score === 'number' ? report.core_score.toFixed(1) : 'N/A'}
            </p>
          </div>
        </div>
      </section>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="glass-panel p-5">
          <h3 className="text-sm font-semibold text-primary mb-3">Leading Projects</h3>
          {report.projects.length === 0 ? (
            <p className="text-sm text-secondary">No project contribution available.</p>
          ) : (
            <div className="space-y-3">
              {report.projects.slice(0, 8).map((project) => (
                <div
                  key={`${project.project_id}-${project.agent_count}`}
                  className="rounded-lg border border-theme bg-surface-inset p-3 text-sm"
                >
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-primary font-medium truncate">{project.project_name || 'Unknown'}</span>
                    <span className="text-tertiary text-xs">#{project.project_id}</span>
                  </div>
                  <p className="text-xs text-secondary mt-1">
                    Agents {project.agent_count} / AI Hours {project.ai_hours.toFixed(1)} / Autonomous{' '}
                    {project.autonomous_hours.toFixed(1)}h
                  </p>
                </div>
              ))}
            </div>
          )}
        </div>
        <div className="glass-panel p-5">
          <h3 className="text-sm font-semibold text-primary mb-3">Recent 28-Day Snapshot</h3>
          {report.daily_points.length === 0 ? (
            <p className="text-sm text-secondary">No trend points available.</p>
          ) : (
            <div className="space-y-2">
              {report.daily_points.slice(-8).map((point) => (
                <div
                  key={point.day}
                  className="grid grid-cols-3 items-center text-sm text-secondary"
                >
                  <span>{formatPointDate(point.day)}</span>
                  <span>Agents {point.agent_count}</span>
                  <span>{point.ai_hours.toFixed(1)}h</span>
                </div>
              ))}
            </div>
          )}
          <p className="text-xs text-tertiary mt-3">Avg parallelism {formatRatio(report.average_parallelism)}</p>
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

function formatPointDate(ms: number): string {
  const d = new Date(ms);
  return `${d.getMonth() + 1}/${d.getDate()}`;
}

function formatDimensionLabel(kind: LeadershipDimension['kind']): string {
  return kind;
}

function formatHours(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return 'N/A';
  return `${value.toFixed(1)}h`;
}

function formatRatio(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return 'N/A';
  return `${value.toFixed(2)}x`;
}

