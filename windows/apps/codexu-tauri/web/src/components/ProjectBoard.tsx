import { Activity, Folder } from 'lucide-react';
import { useState } from 'react';
import type { ProjectBoard as ProjectBoardData, ProjectUsage } from '../types/models';
import { useI18n } from '../i18n/I18nProvider';

type ProjectTimeframe = 'recent' | 'all';

interface ProjectBoardProps {
  projectBoard: ProjectBoardData | null;
}

export function ProjectBoard({ projectBoard }: ProjectBoardProps) {
  const { t } = useI18n();
  const [timeframe, setTimeframe] = useState<ProjectTimeframe>('recent');
  const projects = timeframe === 'recent' ? projectBoard?.recent_projects ?? [] : projectBoard?.all_projects ?? [];
  const visibleProjects = projects.slice(0, 8);
  const maxTokens = Math.max(...visibleProjects.map((project) => Math.max(project.tokens, 0)), 1);

  return (
    <section className="glass-panel p-4 sm:p-5" aria-label={t('projects.ranking')}>
      <div className="flex items-start justify-between gap-3 mb-4">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <Folder size={15} className="text-secondary shrink-0" aria-hidden="true" />
            <h3 className="text-sm font-semibold text-primary">{t('projects.ranking')}</h3>
          </div>
          <p className="mt-1 text-xs text-tertiary">{t('projects.sortedByUsage')}</p>
        </div>
        <div className="flex gap-1 glass-toolbar p-0.5 rounded-full shrink-0" role="group" aria-label={t('projects.rankingAria')}>
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
              {option === 'recent' ? t('projects.sevenDays') : t('common.all')}
            </button>
          ))}
        </div>
      </div>

      {visibleProjects.length === 0 ? (
        <ProjectEmptyState
          icon={<Folder size={20} aria-hidden="true" />}
          title={t('projects.noRecords')}
          detail={
            timeframe === 'recent'
              ? t('projects.noActivityDetail')
              : t('projects.noRecords')
          }
        />
      ) : (
        <div className="space-y-2.5">
          {visibleProjects.map((project) => (
            <ProjectRankingRow key={project.id} project={project} maxTokens={maxTokens} t={t} />
          ))}
        </div>
      )}
    </section>
  );
}

interface ProjectRankingRowProps {
  project: ProjectUsage;
  maxTokens: number;
  t: ReturnType<typeof useI18n>['t'];
}

function ProjectRankingRow({ project, maxTokens, t }: ProjectRankingRowProps) {
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
            {t('projects.threads', { count: project.thread_count })} · {formatLastActive(project.last_active_at, t)}
          </p>
        </div>
        <div className="shrink-0 text-right">
          <p className="text-sm font-semibold tabular-nums text-primary">{formatNumber(project.tokens)}</p>
          <p className="mt-0.5 text-[11px] text-tertiary">{formatProjectSecondaryValue(project, t)}</p>
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
  const { t } = useI18n();
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
    <section className="glass-panel p-4 sm:p-5" aria-label={t('projects.activity')}>
      <div className="flex items-start justify-between gap-3 mb-4">
        <div className="flex items-center gap-2">
          <Activity size={15} className="text-secondary shrink-0" aria-hidden="true" />
          <h3 className="text-sm font-semibold text-primary">{t('projects.activity')}</h3>
        </div>
        <span className="chip-like text-[11px] text-tertiary">{t('projects.recentPeriod', { count: recentProjects.length })}</span>
      </div>

      {recentProjects.length === 0 ? (
        <ProjectEmptyState
          icon={<Activity size={20} aria-hidden="true" />}
          title={t('projects.noActivity')}
          detail={t('projects.noActivityDetail')}
        />
      ) : (
        <>
          <div className="grid grid-cols-2 gap-2">
            <ProjectMetric label={t('projects.sevenDayProjects')} value={String(recentProjects.length)} />
            <ProjectMetric label={t('projects.recordedTokens')} value={formatNumber(recentTokenTotal)} />
            <ProjectMetric label={t('projects.topOneShare')} value={formatShare(recentProjects[0]?.tokens ?? 0, recentTokenTotal)} />
            <ProjectMetric
              label={t('projects.topThreeShare')}
              value={formatShare(
                recentProjects.slice(0, 3).reduce((total, project) => total + Math.max(project.tokens, 0), 0),
                recentTokenTotal,
              )}
            />
          </div>

          <div className="mt-4">
            <p className="text-xs font-semibold text-secondary">{t('projects.recentActivity')}</p>
            <div className="mt-2 space-y-2">
              {recentActivity.map((project) => (
                <div key={project.id} className="flex items-center gap-2.5 rounded-xl border border-theme bg-surface-inset px-2.5 py-2">
                  <span className="inline-flex h-6 w-6 items-center justify-center rounded-lg bg-data-secondary/12 text-data-secondary shrink-0">
                    <Folder size={12} aria-hidden="true" />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-xs font-semibold text-primary">{project.name}</p>
                    <p className="mt-0.5 truncate text-[11px] text-tertiary">
                      {t('projects.threads', { count: project.thread_count })} · {formatLastActive(project.last_active_at, t)}
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

function formatProjectSecondaryValue(project: ProjectUsage, t: ReturnType<typeof useI18n>['t']): string {
  if (project.estimated_cost_usd !== null && Number.isFinite(project.estimated_cost_usd)) {
    return t('projects.estimatedCost', { value: project.estimated_cost_usd.toFixed(2) });
  }
  return project.source_quality === 'approximate' ? t('projects.approximateRecord') : t('projects.costUnavailable');
}

function formatLastActive(timestamp: number | null, t: ReturnType<typeof useI18n>['t']): string {
  if (timestamp === null || !Number.isFinite(timestamp)) return t('projects.lastActiveUnavailable');

  const age = Math.max(0, Date.now() - timestamp);
  if (age < 60_000) return t('projects.lastActiveNow');
  if (age < 3_600_000) return t('projects.lastActive', { value: `${Math.floor(age / 60_000)}m` });
  if (age < 86_400_000) return t('projects.lastActive', { value: `${Math.floor(age / 3_600_000)}h` });
  return t('projects.lastActive', { value: `${Math.floor(age / 86_400_000)}d` });
}

function formatShare(tokens: number, total: number): string {
  if (total <= 0 || tokens <= 0) return '--';
  return `${Math.round((tokens / total) * 100)}%`;
}
