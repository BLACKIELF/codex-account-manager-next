import { type RateWindow, type UsageSnapshot } from '../types/models';
import { useI18n } from '../i18n/I18nProvider';

interface QuotaOverviewProps {
  snapshot: UsageSnapshot | null | undefined;
  sourceLabel: string | null | undefined;
  onRefresh: () => void;
}

function formatQuotaReset(value: number | null | undefined, t: ReturnType<typeof useI18n>['t']): string {
  return value == null ? t('quota.resetTimeNotProvided') : t('quota.resets', { time: new Date(value).toLocaleString() });
}

function formatDuration(value: number | null | undefined, t: ReturnType<typeof useI18n>['t']): string {
  return value == null ? t('common.notAvailable') : t('quota.windowMinutes', { value });
}

function clampPercent(value: number | null | undefined): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(100, Math.round(value)));
}

function QuotaWindow({ label, window, t }: { label: string; window: RateWindow; t: ReturnType<typeof useI18n>['t'] }) {
  const percent = clampPercent(window.used_percent);
  return (
    <article className="rounded-lg border border-theme bg-surface-inset p-2">
      <p className="text-xs font-medium text-primary">{label}</p>
      <p className="mt-1 text-lg font-semibold text-primary">{t('quota.used', { value: percent })}</p>
      <p className="mt-1 text-xs text-tertiary">{formatDuration(window.window_duration_mins, t)}</p>
      <p className="mt-1 text-xs text-tertiary">{formatQuotaReset(window.resets_at, t)}</p>
    </article>
  );
}

export function QuotaOverview({ snapshot, sourceLabel, onRefresh }: QuotaOverviewProps) {
  const { t } = useI18n();
  const quotaWindows = [
    { label: t('quota.fiveHour'), window: snapshot?.five_hour_quota },
    { label: t('quota.sevenDay'), window: snapshot?.seven_day_quota },
    { label: t('quota.monthly'), window: snapshot?.monthly_quota },
  ].filter((entry): entry is { label: string; window: RateWindow } => entry.window != null);

  if (quotaWindows.length === 0) {
    const hasAuthoritativeEmptyQuota = snapshot?.quota_read_succeeded === true;
    return (
      <section className="dashboard-home-quota glass-panel p-4" aria-label={t('quota.availability')} aria-live="polite">
        <h3 className="text-sm font-semibold text-primary">{t('quota.title')}</h3>
        {hasAuthoritativeEmptyQuota ? (
          <p className="mt-2 text-sm text-secondary">{t('quota.noActive')}</p>
        ) : (
          <>
            <p className="mt-2 text-sm text-secondary">{t('quota.checking')}</p>
            <p className="mt-1 text-xs text-tertiary">{t('quota.confirmedOnly')}</p>
            <button onClick={onRefresh} className="mt-3 px-3 py-1.5 rounded-full glass-button text-xs">
              {t('quota.retry')}
            </button>
          </>
        )}
      </section>
    );
  }

  return (
    <section className="dashboard-home-quota glass-panel p-4" aria-label={t('quota.availability')}>
      <h3 className="text-sm font-semibold text-primary">{t('quota.title')}</h3>
      <p className="mt-1 text-xs text-tertiary">{sourceLabel ?? t('quota.officialSource')}</p>
      <div className="mt-3 grid grid-cols-1 sm:grid-cols-2 gap-2">
        {quotaWindows.map(({ label, window }) => (
          <QuotaWindow key={label} label={label} window={window} t={t} />
        ))}
      </div>
    </section>
  );
}
