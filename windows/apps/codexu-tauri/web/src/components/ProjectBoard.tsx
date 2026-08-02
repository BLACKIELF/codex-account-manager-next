import { Activity, Folder } from 'lucide-react';
import { useState } from 'react';
import type { ProjectBoard as ProjectBoardData, ProjectUsage } from '../types/models';

type ProjectTimeframe = 'recent' | 'all';

interface ProjectBoardProps {
  projectBoard: ProjectBoardData | null;
}

export function ProjectBoard({ projectBoard }: ProjectBoardProps) {
  const [timeframe, setTimeframe] = useState<ProjectTimeframe>('recent');
  const projects = timeframe === 'recent' ? projectBoard?.recent_projects ?? [] : projectBoard?.all_projects ?? [];
  const visibleProjects = projects.slice(0, 8);
  const maxTokens = Math.max(...visibleProjects.map((project) => Math.max(project.tokens, 0)), 1);

  return (
    <section className="glass-panel p-4 sm:p-5" aria-label="Project ranking">
      <div className="flex items-start justify-between gap-3 mb-4">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <Folder size={15} className="text-secondary shrink-0" aria-hidden="true" />
            <h3 className="text-sm font-semibold text-primary">Project ranking</h3>
          </div>
          <p className="mt-1 text-xs text-tertiary">Sorted by local token usage</p>
        </div>
        <div className="flex gap-1 glass-toolbar p-0.5 rounded-full shrink-0" role="group" aria-label="Project ranking timeframe">
          {(['recent', 'all'] as const).map((option) => (
            <button
              key={option}
              type="button"
              aria-pressed={timeframe === option}
              onClick={() => setTimeframe(option)}
              className={`px-2.5 py-1 rounded-full text-[11px] transition-all ${
                timeframe === option ? 'glass-button-solid' : 'text-secondary glass-button'
              }`}
            >
              {option === 'recent' ? '7 days' : 'All'}
            </button>
          ))}
        </div>
      </div>

      {visibleProjects.length === 0 ? (
        <ProjectEmptyState
          icon={<Folder size={20} aria-hidden="true" />}
          title="No project records"
          detail={
            timeframe === 'recent'
              ? 'No local project usage can be grouped in the last 7 days.'
              : 'No local project usage can be grouped yet.'
          }
        />
      ) : (
        <div className="space-y-2.5">
          {visibleProjects.map((project) => (
            <ProjectRankingRow key={project.id} project={project} maxTokens={maxTokens} />
          ))}
        </div>
      )}
    </section>
  );
}

interface ProjectRankingRowProps {
  project: ProjectUsage;
  maxTokens: number;
}

function ProjectRankingRow({ project, maxTokens }: ProjectRankingRowProps) {
  const progress = Math.max(0, Math.min(1, project.tokens / maxTokens));

  return (
    <div className="rounded-2xl border border-theme bg-surface-inset p-3 space-y-2">
      <div className="flex items-start gap-3">
        <span className="mt-0.5 inline-flex h-7 w-7 items-center justify-center rounded-lg bg-data-secondary/12 text-data-secondary shrink-0">
          <Folder size={13} aria-hidden="true" />
        </span>
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-semibold text-primary">{project.name}</p>
          <p className="mt-0.5 truncate text-xs text-secondary">
            {project.thread_count} threads · {formatLastActive(project.last_active_at)}
          </p>
        </div>
        <div className="shrink-0 text-right">
          <p className="text-sm font-semibold tabular-nums text-primary">{formatNumber(project.tokens)}</p>
          <p className="mt-0.5 text-[11px] text-tertiary">{formatProjectSecondaryValue(project)}</p>
        </div>
      </div>
      <div className="h-1.5 w-full overflow-hidden rounded-full bg-surface-inset" aria-hidden="true">
        <div className="h-full rounded-full bg-data-secondary" style={{ width: `${progress * 100}%` }} />
      </div>
    </div>
  );
}

interface ProjectEmptyStateProps {
  icon: React.ReactNode;
  title: string;
  detail: string;
}

function ProjectEmptyState({ icon, title, detail }: ProjectEmptyStateProps) {
  return (
    <div className="flex min-h-[214px] flex-col items-center justify-center rounded-2xl border border-theme bg-surface-inset px-5 text-center">
      <span className="text-secondary">{icon}</span>
      <h4 className="mt-3 text-sm font-semibold text-primary">{title}</h4>
      <p className="mt-2 max-w-sm text-sm text-secondary">{detail}</p>
    </div>
  );
}

export function ProjectActivityOverview({ projectBoard }: ProjectBoardProps) {
  const recentProjects = projectBoard?.recent_projects ?? [];
  const recentTokenTotal = recentProjects.reduce((total, project) => total + Math.max(project.tokens, 0), 0);
  const recentActivity = [...recentProjects]
    .sort((left, right) => {
      const leftActivity = left.last_active_at ?? 0;
      const rightActivity = right.last_active_at ?? 0;
      if (leftActivity !== rightActivity) return rightActivity - leftActivity;
      return right.tokens - left.tokens;
    })
    .slice(0, 5);

  return (
    <section className="glass-panel p-4 sm:p-5" aria-label="Project activity">
      <div className="flex items-start justify-between gap-3 mb-4">
        <div className="flex items-center gap-2">
          <Activity size={15} className="text-secondary shrink-0" aria-hidden="true" />
          <h3 className="text-sm font-semibold text-primary">Project activity</h3>
        </div>
        <span className="chip-like text-[11px] text-tertiary">7 days · {recentProjects.length}</span>
      </div>

      {recentProjects.length === 0 ? (
        <ProjectEmptyState
          icon={<Activity size={20} aria-hidden="true" />}
          title="No project activity"
          detail="No local project activity can be grouped in the last 7 days."
        />
      ) : (
        <>
          <div className="grid grid-cols-2 gap-2">
            <ProjectMetric label="7d projects" value={String(recentProjects.length)} />
            <ProjectMetric label="Recorded tokens" value={formatNumber(recentTokenTotal)} />
            <ProjectMetric label="Top 1 share" value={formatShare(recentProjects[0]?.tokens ?? 0, recentTokenTotal)} />
            <ProjectMetric
              label="Top 3 share"
              value={formatShare(
                recentProjects.slice(0, 3).reduce((total, project) => total + Math.max(project.tokens, 0), 0),
                recentTokenTotal,
              )}
            />
          </div>

          <div className="mt-4">
            <p className="text-xs font-semibold text-secondary">Recent activity</p>
            <div className="mt-2 space-y-2">
              {recentActivity.map((project) => (
                <div key={project.id} className="flex items-center gap-2.5 rounded-xl border border-theme bg-surface-inset px-2.5 py-2">
                  <span className="inline-flex h-6 w-6 items-center justify-center rounded-lg bg-data-secondary/12 text-data-secondary shrink-0">
                    <Folder size={12} aria-hidden="true" />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-xs font-semibold text-primary">{project.name}</p>
                    <p className="mt-0.5 truncate text-[11px] text-tertiary">
                      {project.thread_count} threads · {formatLastActive(project.last_active_at)}
                    </p>
                  </div>
                  <span className="shrink-0 text-xs font-semibold tabular-nums text-primary">{formatNumber(project.tokens)}</span>
                </div>
              ))}
            </div>
          </div>
        </>
      )}
    </section>
  );
}

function ProjectMetric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-theme bg-surface-inset px-2.5 py-2">
      <p className="text-[11px] text-tertiary">{label}</p>
      <p className="mt-1 text-sm font-semibold tabular-nums text-primary">{value}</p>
    </div>
  );
}

function formatNumber(value: number): string {
  if (!Number.isFinite(value)) return '--';
  return Math.round(value).toLocaleString();
}

function formatProjectSecondaryValue(project: ProjectUsage): string {
  if (project.estimated_cost_usd !== null && Number.isFinite(project.estimated_cost_usd)) {
    return `Est. $${project.estimated_cost_usd.toFixed(2)}`;
  }
  return project.source_quality === 'approximate' ? 'Approximate record' : 'Cost unavailable';
}

function formatLastActive(timestamp: number | null): string {
  if (timestamp === null || !Number.isFinite(timestamp)) return 'Last active unavailable';

  const age = Math.max(0, Date.now() - timestamp);
  if (age < 60_000) return 'Last active now';
  if (age < 3_600_000) return `Last active ${Math.floor(age / 60_000)}m ago`;
  if (age < 86_400_000) return `Last active ${Math.floor(age / 3_600_000)}h ago`;
  return `Last active ${Math.floor(age / 86_400_000)}d ago`;
}

function formatShare(tokens: number, total: number): string {
  if (total <= 0 || tokens <= 0) return '--';
  return `${Math.round((tokens / total) * 100)}%`;
}
