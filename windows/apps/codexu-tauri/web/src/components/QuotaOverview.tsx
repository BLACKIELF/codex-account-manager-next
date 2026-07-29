import { type RateWindow, type UsageSnapshot } from '../types/models';

interface QuotaOverviewProps {
  snapshot: UsageSnapshot | null | undefined;
  sourceLabel: string | null | undefined;
  onRefresh: () => void;
}

function formatQuotaReset(value: number | null | undefined): string {
  return value == null ? 'Reset time not provided' : `Resets ${new Date(value).toLocaleString()}`;
}

function formatDuration(value: number | null | undefined): string {
  return value == null ? 'Window length not provided' : `${value} min`;
}

function clampPercent(value: number | null | undefined): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(100, Math.round(value)));
}

function QuotaWindow({ label, window }: { label: string; window: RateWindow }) {
  const percent = clampPercent(window.used_percent);
  return (
    <article className="rounded-lg border border-theme bg-surface-inset p-2">
      <p className="text-xs font-medium text-primary">{label}</p>
      <p className="mt-1 text-lg font-semibold text-primary">{percent}% used</p>
      <p className="mt-1 text-xs text-tertiary">{formatDuration(window.window_duration_mins)}</p>
      <p className="mt-1 text-xs text-tertiary">{formatQuotaReset(window.resets_at)}</p>
    </article>
  );
}

export function QuotaOverview({ snapshot, sourceLabel, onRefresh }: QuotaOverviewProps) {
  const quotaWindows = [
    { label: '5h', window: snapshot?.five_hour_quota },
    { label: '7d', window: snapshot?.seven_day_quota },
    { label: 'Monthly', window: snapshot?.monthly_quota },
  ].filter((entry): entry is { label: string; window: RateWindow } => entry.window != null);

  if (quotaWindows.length === 0) {
    const hasAuthoritativeEmptyQuota = snapshot?.quota_read_succeeded === true;
    return (
      <section className="dashboard-home-quota glass-panel p-4" aria-label="Quota availability" aria-live="polite">
        <h3 className="text-sm font-semibold text-primary">Quota</h3>
        {hasAuthoritativeEmptyQuota ? (
          <p className="mt-2 text-sm text-secondary">No active official quota limits were returned.</p>
        ) : (
          <>
            <p className="mt-2 text-sm text-secondary">Checking official Codex quota</p>
            <p className="mt-1 text-xs text-tertiary">Only confirmed account windows are shown here.</p>
            <button onClick={onRefresh} className="mt-3 px-3 py-1.5 rounded-full glass-button text-xs">
              Retry quota check
            </button>
          </>
        )}
      </section>
    );
  }

  return (
    <section className="dashboard-home-quota glass-panel p-4" aria-label="Quota availability">
      <h3 className="text-sm font-semibold text-primary">Quota</h3>
      <p className="mt-1 text-xs text-tertiary">{sourceLabel ?? 'Official Codex quota'}</p>
      <div className="mt-3 grid grid-cols-1 sm:grid-cols-2 gap-2">
        {quotaWindows.map(({ label, window }) => (
          <QuotaWindow key={label} label={label} window={window} />
        ))}
      </div>
    </section>
  );
}
