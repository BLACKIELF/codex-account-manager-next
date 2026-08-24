import { CheckCircle2, Gauge, RefreshCw, ShieldAlert } from 'lucide-react';
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
    <article className="quota-overview-window">
      <div className="quota-overview-window-heading">
        <span>{label}</span>
        <strong>{t('quota.used', { value: percent })}</strong>
      </div>
      <div
        className="quota-overview-track"
        role="meter"
        aria-label={label}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={percent}
      >
        <span className="quota-overview-fill" style={{ width: `${percent}%` }} />
      </div>
      <div className="quota-overview-window-meta">
        <span>{formatDuration(window.window_duration_mins, t)}</span>
        <span>{formatQuotaReset(window.resets_at, t)}</span>
      </div>
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
  const hasAuthoritativeEmptyQuota = snapshot?.quota_read_succeeded === true;
  const hasQuota = quotaWindows.length > 0;

  return (
    <section className="dashboard-home-quota dashboard-home-primary-card glass-panel p-4" aria-label={t('quota.availability')} aria-live="polite">
      <div className="dashboard-overview-header">
        <div className="dashboard-overview-heading">
          <span className="dashboard-overview-icon" aria-hidden="true">
            <Gauge size={15} />
          </span>
          <div>
            <h3>{t('quota.title')}</h3>
            <p>{sourceLabel ?? t('quota.officialSource')}</p>
          </div>
        </div>
        <span className={`dashboard-overview-status ${hasQuota ? 'dashboard-overview-status-confirmed' : ''}`}>
          {hasQuota ? t('quota.officialSource') : hasAuthoritativeEmptyQuota ? t('quota.noActive') : t('quota.checking')}
        </span>
      </div>

      {hasQuota ? (
        <>
          <div className="quota-overview-state quota-overview-state-confirmed">
            <div className="quota-overview-state-copy">
              <CheckCircle2 size={18} aria-hidden="true" />
              <div>
              <strong>{t('quota.officialSource')}</strong>
              <p>{t('quota.confirmedOnly')}</p>
              </div>
            </div>
          </div>
          <div className="quota-overview-windows">
            {quotaWindows.map(({ label, window }) => (
              <QuotaWindow key={label} label={label} window={window} t={t} />
            ))}
          </div>
        </>
      ) : (
        <div className="quota-overview-state quota-overview-state-empty">
          <div className="quota-overview-state-copy">
            <ShieldAlert size={18} aria-hidden="true" />
            <div>
              <strong>{hasAuthoritativeEmptyQuota ? t('quota.noActive') : t('quota.checking')}</strong>
              <p>{t('quota.confirmedOnly')}</p>
            </div>
          </div>
          {!hasAuthoritativeEmptyQuota ? (
            <button onClick={onRefresh} className="quota-overview-refresh glass-button" type="button">
              <RefreshCw size={13} aria-hidden="true" />
              {t('quota.retry')}
            </button>
          ) : null}
        </div>
      )}
    </section>
  );
}
