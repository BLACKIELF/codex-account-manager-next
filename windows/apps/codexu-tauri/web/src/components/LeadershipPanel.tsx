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
import { type CSSProperties, type ReactNode } from 'react';
import type {
  CodexLeadershipSignal,
  LeadershipDayPoint,
  LeadershipDimension,
  LeadershipProjectContribution,
  LeadershipReport,
} from '../types/models';
import { LEADERSHIP_BANDS, type LeadershipBand, resolveLeadershipBand } from '../utils/leadershipTitles';
import { useI18n } from '../i18n/I18nProvider';
import type { MessageKey } from '../i18n/messages';

interface LeadershipPanelProps {
  signal: CodexLeadershipSignal | null;
}

type DimensionKind = LeadershipDimension['kind'];

type SortField = 'ai_hours' | 'agent_count' | 'autonomous_hours';

interface DimensionMeta {
  labelKey: MessageKey;
  weight: string;
  descriptionKey: MessageKey;
}

const DIMENSION_META: Record<DimensionKind, DimensionMeta> = {
  span: {
    labelKey: 'leadership.span',
    weight: '30%',
    descriptionKey: 'leadership.spanDescription',
  },
  leverage: {
    labelKey: 'leadership.leverage',
    weight: '30%',
    descriptionKey: 'leadership.leverageDescription',
  },
  orchestration: {
    labelKey: 'leadership.orchestration',
    weight: '25%',
    descriptionKey: 'leadership.orchestrationDescription',
  },
  autonomy: {
    labelKey: 'leadership.autonomy',
    weight: '15%',
    descriptionKey: 'leadership.autonomyDescription',
  },
};

export function LeadershipOverviewCard({
  signal,
  hasUsage,
  onOpen,
}: {
  signal: CodexLeadershipSignal | null;
  hasUsage: boolean;
  onOpen: () => void;
}) {
  const { t, language } = useI18n();
  const report = signal ? getReportFromSignal(signal) : null;
  const score = signal?.score ?? null;
  const evidenceRatio = signal?.evidence_coverage ?? 0;
  const activeBand = resolveLeadershipBand(score, evidenceRatio, signal?.active_day_count ?? 0);
  const hasSignal = score !== null && activeBand !== null;
  const scoreForVisual = hasSignal ? Math.max(0, Math.min(100, Math.round(score ?? 0))) : 0;
  const title = hasSignal && activeBand
    ? `L${activeBand.level} · ${language === 'zh-Hans' ? activeBand.zhName : activeBand.enName}`
    : t('leadership.recordBuilding');
  const accessibilityLabel = hasSignal && activeBand
    ? `${t('leadership.title')}, ${t('leadership.score')} ${scoreForVisual}, ${title}, ${formatNumberish(report?.agent_count)} ${t('leadership.agents', { value: '' }).trim()} over ${t('leadership.period')}, ${formatHours(report?.ai_hours)} ${t('leadership.aiHours')} over ${t('leadership.period')}`
    : hasUsage
      ? `${t('leadership.title')}, ${t('leadership.recordInsufficient')}`
      : `${t('leadership.title')}, ${t('leadership.noSnapshot')}`;

  return (
    <button
      className="dashboard-home-command glass-panel p-4 leadership-overview-card"
      type="button"
      onClick={onOpen}
      aria-controls="dashboard-home-panel-leadership"
      aria-label={accessibilityLabel}
    >
      <div className="leadership-overview-header">
        <span>{t('leadership.title')}</span>
        <span className="leadership-period-badge">{t('leadership.period')}</span>
      </div>
      <div className="leadership-overview-lockup">
        <LeadershipOrbit
          score={scoreForVisual}
          activeBand={activeBand}
          hasSignal={hasSignal}
          showScore={false}
        />
        <div className="leadership-overview-identity">
          <strong>{title}</strong>
          <span>{hasSignal && activeBand ? t('leadership.bandLabel') : hasUsage ? t('leadership.recordInsufficient') : t('leadership.noSnapshot')}</span>
        </div>
      </div>
      <div className="leadership-overview-facts">
        <OverviewFact icon={<Brain size={13} />} label={t('leadership.score')} value={formatScore(hasSignal ? scoreForVisual : null)} />
        <OverviewFact icon={<Calendar size={13} />} label={t('leadership.ledAgents')} value={formatNumberish(report?.agent_count)} />
        <OverviewFact icon={<Globe size={13} />} label={t('leadership.aiHours')} value={formatHours(report?.ai_hours)} />
        <OverviewFact icon={<TrendingUp size={13} />} label={t('leadership.peak')} value={formatNumberish(report?.peak_concurrency)} />
      </div>
    </button>
  );
}

export function LeadershipPanel({ signal }: LeadershipPanelProps) {
  const { t, language } = useI18n();
  if (!signal) {
    return (
      <section className="glass-panel p-6 sm:p-7 space-y-3">
        <h2 className="text-lg font-semibold text-primary">{t('leadership.title')}</h2>
        <p className="text-sm text-secondary">
          {t('leadership.noSnapshotDetail')}
        </p>
      </section>
    );
  }

  const report = getReportFromSignal(signal);
  if (!report) {
    return (
      <section className="glass-panel p-6 sm:p-7 space-y-3">
        <h2 className="text-lg font-semibold text-primary">{t('leadership.title')}</h2>
        <p className="text-sm text-secondary">
          {t('leadership.reportNotReady', { period: formatPeriod(signal.period, t) })}
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
              <p className="font-semibold text-primary">{t('leadership.fallbackMode')}</p>
              <p className="text-xs text-tertiary mt-1">
                {t('leadership.fallbackDetail', { source: signal.model_version })}
              </p>
            </div>
          </div>
        </section>
      ) : null}

      <section className="glass-panel leadership-panel-primary p-5">
        <div className="leadership-panel-identity">
          <div className="leadership-identity-card">
            <LeadershipOrbit
              score={scoreForVisual}
              activeBand={activeBand}
              hasSignal={hasSignal}
              showScore={false}
            />
            <div className="leadership-identity-copy">
              <div className="leadership-identity-eyebrow">
                <span>{t('leadership.title')}</span>
                <span className="leadership-period-badge">{t('leadership.period')}</span>
              </div>
              <h2 className="leadership-identity-title">
                {hasSignal && activeBand
                  ? `L${activeBand.level} · ${bandName(activeBand, language)}`
                  : t('leadership.scorePending')}
              </h2>
              <p className="leadership-identity-subtitle">
                {hasSignal ? t('leadership.bandLabel') : t('leadership.authoritativeTitleUnavailable')}
              </p>
              <p className="leadership-identity-meta">
                {t('leadership.periodMeta', {
                  period: formatPeriod(report.period, t),
                  days: report.active_day_count,
                  confidence,
                })}
              </p>
            </div>
          </div>
          <div className="leadership-identity-score">
            <span>{t('leadership.leadershipScore')}</span>
            <strong>{formatScore(hasSignal ? scoreForVisual : null)}</strong>
          </div>
        </div>

        <LeadershipCommandRail
          bands={LEADERSHIP_BANDS}
          hasSignal={hasSignal}
          score={hasSignal ? scoreForVisual : 0}
        />

        <div className="leadership-panel-facts">
          <Pill icon={<Brain size={14} />} label={t('leadership.leadershipScore')} value={formatScore(hasSignal ? scoreForVisual : null)} />
          <Pill icon={<Calendar size={14} />} label={t('leadership.ledAgents')} value={formatNumberish(report.agent_count)} />
          <Pill icon={<Globe size={14} />} label={t('leadership.aiHours')} value={formatHours(report.ai_hours)} />
          <Pill icon={<TrendingUp size={14} />} label={t('leadership.peak')} value={formatNumberish(report.peak_concurrency)} />
        </div>
      </section>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="glass-panel p-5">
          <div className="flex items-center gap-2 mb-3">
            <Brain size={16} className="text-secondary" />
            <h3 className="text-sm font-semibold text-primary">{t('leadership.dimensionScores')}</h3>
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
                      {t(meta.labelKey)}
                      <span className="text-tertiary ml-2">({meta.weight})</span>
                    </span>
                    <span className="text-tertiary">
                      {dimension.score.toFixed(1)} / 100 | {t('leadership.conf', { value: confidencePct })}
                    </span>
                  </div>
                  <p className="text-xs text-tertiary">{t(meta.descriptionKey)}</p>
                  <div className="h-2 bg-surface rounded-full overflow-hidden">
                    <div className="h-full rounded-full bg-accent/90" style={{ width: `${pct}%` }} />
                  </div>
                  <p className="text-xs text-secondary">
                    {t('leadership.value')}: <span className="text-primary">{dimension.summary_value.toFixed(2)}</span>
                  </p>
                </article>
              );
            })}
            {report.dimensions.length === 0 && <p className="text-sm text-secondary">{t('common.noRecords')}</p>}
          </div>
        </div>

        <div className="glass-panel p-5">
          <div className="flex items-center gap-2 mb-3">
            <BookOpenText size={16} className="text-secondary" />
            <h3 className="text-sm font-semibold text-primary">{t('leadership.scorePath')}</h3>
          </div>
          <p className="text-sm text-secondary">{t('leadership.scorePathDetail')}</p>
          <div className="mt-4 grid grid-cols-2 gap-2">
            <Pill icon={<Globe size={14} />} label={t('leadership.coreScore')} value={formatCoreScore(report.core_score)} />
            <Pill icon={<Eye size={14} />} label={t('leadership.maturity')} value={report.maturity.toFixed(1)} />
            <Pill icon={<Cpu size={14} />} label={t('leadership.evidence')} value={`${confidence}%`} />
            <Pill icon={<Calendar size={14} />} label={t('leadership.activeWindow')} value={t('leadership.days', { value: report.active_day_count })} />
          </div>
          {latest ? (
            <div className="mt-4 p-3 rounded-lg border border-theme bg-surface-inset text-sm">
              <p className="text-primary font-medium">{t('leadership.latestDaySignal')}</p>
              <p className="text-xs text-secondary mt-1">
                {formatPointDate(latest.day)} | {latest.agent_count} agents, {latest.ai_hours.toFixed(1)}h AI hours,
                peak {latest.peak_concurrency}
              </p>
            </div>
          ) : (
            <p className="text-xs text-tertiary mt-4">{t('leadership.noDailyTrend')}</p>
          )}
        </div>
      </section>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="glass-panel p-5">
          <div className="flex items-center justify-between mb-3">
            <h3 className="text-sm font-semibold text-primary">{t('leadership.leadingProjects')}</h3>
            <span className="text-xs text-tertiary">{t('leadership.sortedByAiHours')}</span>
          </div>
          {sortedProjects.length === 0 ? (
            <p className="text-sm text-secondary">{t('leadership.noProjectContribution')}</p>
          ) : (
            <div className="space-y-2">
              {sortedProjects.slice(0, 5).map((project, index) => (
                <div
                  key={`${project.project_id}-${project.agent_count}-${index}`}
                  className="rounded-lg border border-theme bg-surface-inset p-3 text-sm"
                >
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-primary font-medium truncate">{project.project_name || t('common.unknown')}</span>
                    <span className="text-tertiary text-xs">#{index + 1}</span>
                  </div>
                  <p className="text-xs text-secondary mt-1">
                    {t('leadership.projectFacts', {
                      agents: project.agent_count,
                      hours: project.ai_hours.toFixed(1),
                      autonomous: project.autonomous_hours.toFixed(1),
                    })}
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
            <h3 className="text-sm font-semibold text-primary">{t('leadership.trendSnapshot')}</h3>
          </div>
          {report.daily_points.length === 0 ? (
            <p className="text-sm text-secondary">{t('leadership.noTrendPoints')}</p>
          ) : (
            <div className="space-y-2">
              {report.daily_points
                .slice(-8)
                .map((point) => (
                  <div key={point.day} className="grid grid-cols-4 items-center text-sm text-secondary">
                    <span className="text-xs sm:text-sm">{formatPointDate(point.day)}</span>
                    <span>{t('leadership.agents', { value: point.agent_count })}</span>
                    <span>{point.ai_hours.toFixed(1)}h</span>
                    <span>{t('leadership.parallel', { value: point.peak_concurrency })}</span>
                  </div>
                ))}
            </div>
          )}
          <p className="text-xs text-tertiary mt-3">{t('leadership.averageParallelism', { value: formatRatio(report.average_parallelism) })}</p>
          {trend ? (
            <p className="text-xs text-secondary mt-1">
              {t('leadership.momentum', {
                direction: trend.direction === 'up' ? 'up' : 'down',
                delta: `${trend.delta >= 0 ? '+' : ''}${trend.delta.toFixed(2)}`,
              })}
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
  showScore = true,
}: {
  score: number;
  hasSignal: boolean;
  activeBand: LeadershipBand | null;
  showScore?: boolean;
}) {
  const { t } = useI18n();
  const radius = 56;
  const circumference = Math.round(2 * Math.PI * radius);
  const safeScore = hasSignal ? clampPercent(score) : 0;
  const dashOffset = circumference - (safeScore / 100) * circumference;

  return (
    <div className="leadership-orbit-wrap">
      <div className="leadership-orbit" role="img" aria-label={t('leadership.orbit')}>
        {hasSignal && activeBand ? (
            <img src={activeBand.badge} alt={t('leadership.badge')} className="leadership-orbit-badge" />
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
      {showScore ? (
        <div className={`leadership-orbit-score ${!hasSignal ? 'leadership-orbit-score-empty' : ''}`}>
          {hasSignal ? `${safeScore}` : '--'}
        </div>
      ) : null}
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
  const { t, language } = useI18n();
  const safeScore = clampPercent(score);
  const currentBand = bands.find((band) => safeScore >= band.scoreMin && safeScore <= band.scoreMax) ?? null;
  const hasInteractive = typeof onOpenLeadership === 'function';
  const signalLabel = currentBand
    ? `${t('leadership.openDetail')} ${safeScore}, L${currentBand.level} ${bandName(currentBand, language)}`
    : t('leadership.openDetail');
  const trackStyle = {
    ['--rail-progress' as keyof CSSProperties]: `${safeScore}%`,
  } as CSSProperties;
  const railContent = (
    <>
      <div className="leadership-rail-stage-layer" aria-hidden="true">
        {hasSignal
          ? bands.map((band) => {
              const isCurrent = safeScore >= band.scoreMin && safeScore <= band.scoreMax;
              const thresholdPercent = clampPercent(band.scoreMin);

              return (
                <div key={band.id} className="leadership-rail-stage" style={{ left: `${thresholdPercent}%` }}>
                  <span className="leadership-rail-stage-badge-slot">
                    <img
                      src={band.badge}
                      alt=""
                      className={`leadership-rail-badge ${isCurrent ? 'leadership-rail-badge-current' : ''}`}
                    />
                  </span>
                  <span
                    className={`leadership-rail-stage-title ${isCurrent ? 'leadership-rail-stage-title-current' : ''}`}
                    title={bandName(band, language)}
                    aria-label={bandName(band, language)}
                  >
                    L{band.level} · {bandName(band, language)}
                  </span>
                </div>
              );
            })
          : null}
      </div>

      <div className="leadership-rail-track-layer" style={trackStyle}>
        <div className="leadership-rail-track" />
        {hasSignal ? <div className="leadership-rail-fill" /> : null}
        {hasSignal
          ? bands.map((band) => {
              const isCurrent = safeScore >= band.scoreMin && safeScore <= band.scoreMax;
              const isReached = safeScore >= band.scoreMin;
              const thresholdPercent = clampPercent(band.scoreMin);

              return (
                <span
                  key={band.id}
                  className={[
                    'leadership-rail-dot',
                    isReached ? 'leadership-rail-dot-reached' : '',
                    isCurrent ? 'leadership-rail-dot-current' : '',
                  ]
                    .filter(Boolean)
                    .join(' ')}
                  style={{ left: `${thresholdPercent}%` }}
                  aria-hidden="true"
                />
              );
            })
          : null}
        {hasSignal ? (
          <span className={`leadership-rail-score-text ${safeScore < 9 ? 'leadership-rail-score-text-low' : ''}`}>
            {`${safeScore} / 100`}
          </span>
        ) : null}
      </div>
    </>
  );

  if (!hasInteractive) {
    return (
      <div className="leadership-command-rail" aria-label={t('leadership.title')}>
        {railContent}
        <span className="sr-only">{t('leadership.title')}</span>
      </div>
    );
  }

  return (
    <button
      type="button"
      onClick={onOpenLeadership}
      className="leadership-command-rail leadership-command-rail-button leadership-command-rail-clickable"
      aria-label={hasSignal ? signalLabel : t('leadership.openDetail')}
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

function bandName(band: LeadershipBand, language: 'zh-Hans' | 'en'): string {
  return language === 'zh-Hans' ? band.zhName : band.enName;
}

function OverviewFact({
  icon,
  label,
  value,
}: {
  icon: ReactNode;
  label: string;
  value: number | string;
}) {
  return (
    <div className="leadership-overview-fact">
      <p>
        <span>{icon}</span>
        {label}
      </p>
      <strong>{value}</strong>
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

function formatPeriod(period: string, t: ReturnType<typeof useI18n>['t']): string {
  if (period === 'today') return t('leadership.todayPeriod');
  if (period === 'sevenDays') return t('leadership.sevenDaysPeriod');
  if (period === 'twentyEightDays') return t('leadership.twentyEightDaysPeriod');
  return t('leadership.selectedPeriod');
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
