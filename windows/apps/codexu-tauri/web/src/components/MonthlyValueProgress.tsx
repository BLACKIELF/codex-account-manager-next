import { BadgeDollarSign } from 'lucide-react';
import type { LocalUsage } from '../types/models';

interface MonthlyValueProgressProps {
  usage: LocalUsage | null | undefined;
}

const REFERENCE_CAP = 46500;
const FLAT_THRESHOLD = 200;
const BASE_PROGRESS = 0.28;
const CAP_PROGRESS = 1;

export function MonthlyValueProgress({ usage }: MonthlyValueProgressProps) {
  const detailed = usage?.detailed_usage ?? null;

  if (detailed === null) {
    return (
      <section className="glass-panel p-4 sm:p-5 dashboard-home-monthly-progress">
        <h3 className="text-sm font-semibold text-primary">Monthly value progress</h3>
        <p className="text-xs text-tertiary mt-1">Local API-equivalent cost estimate - Record insufficient</p>
        <p className="mt-3 text-xs text-tertiary">No detailed monthly data available in local snapshot yet.</p>
      </section>
    );
  }

  const monthCost = safeNonNegativeNumber(detailed.month?.estimated_cost_usd);
  if (monthCost === null) {
    return (
      <section className="glass-panel p-4 sm:p-5 dashboard-home-monthly-progress">
        <h3 className="text-sm font-semibold text-primary">Monthly value progress</h3>
        <p className="text-xs text-tertiary mt-1">Local API-equivalent cost estimate - Record insufficient</p>
        <p className="mt-3 text-xs text-tertiary">No detailed monthly cost available.</p>
      </section>
    );
  }

  const markers = getMonthlyMarkers();
  const progressPercent = clamp(computeMonthlyProgress(monthCost), 0, 1) * 100;
  const progressValue = `${progressPercent.toFixed(1)}%`;

  return (
    <section className="glass-panel p-4 sm:p-5 dashboard-home-monthly-progress" aria-label="Monthly value progress">
      <div className="flex items-start justify-between gap-3 flex-wrap">
        <div>
          <h3 className="text-sm font-semibold text-primary">Monthly value progress</h3>
          <p className="text-xs text-tertiary mt-1">Local API-equivalent estimate - Not official quota or allowance</p>
        </div>
        <p className="text-xs text-tertiary text-right">Reference: Plus $20, Pro100 $100, Pro200 $200, Cap $46.5K</p>
      </div>

      <div className="h-2 rounded-full mt-3 bg-surface border border-theme overflow-visible relative mb-7">
        <div
          className="h-full rounded-full"
          style={{
            width: progressValue,
            background: 'linear-gradient(90deg, var(--data-primary), var(--data-secondary), var(--data-tertiary))',
            borderRight: '1px solid color-mix(in oklab, var(--data-tertiary) 65%, transparent)',
          }}
        />

        {markers.map((marker) => (
          <Marker key={marker.label} label={marker.label} positionPercent={marker.positionPercent} />
        ))}
      </div>

      <div className="mt-1 text-xs text-tertiary">
        {monthCost > 0
          ? `Mapped with non-linear local estimate: first $0-$${FLAT_THRESHOLD} maps to first 28%, remaining uses log1p to cap ${REFERENCE_CAP}.`
          : 'This month has no detailed monthly usage yet; only local snapshot structure is present.'}
      </div>

      <p className="mt-2 text-xs text-primary">
        <span className="inline-flex items-center gap-1.5">
          <BadgeDollarSign size={14} />
          {`Estimated: $${formatUSD(monthCost)}${monthCost === 0 ? ' (no usage yet this month)' : ''}`}
        </span>
      </p>
    </section>
  );
}

function safeNonNegativeNumber(value: number | null | undefined): number | null {
  if (value == null || !Number.isFinite(value) || value < 0) return null;
  return value;
}

function computeMonthlyProgress(monthCost: number): number {
  const v = clamp(monthCost, 0, REFERENCE_CAP);
  if (v <= FLAT_THRESHOLD) {
    return BASE_PROGRESS * (v / FLAT_THRESHOLD);
  }

  const numerator = Math.log1p((v - FLAT_THRESHOLD) / FLAT_THRESHOLD);
  const denominator = Math.log1p((REFERENCE_CAP - FLAT_THRESHOLD) / FLAT_THRESHOLD);
  const curved = numerator / Math.max(denominator, 1);
  return BASE_PROGRESS + (CAP_PROGRESS - BASE_PROGRESS) * clamp(curved, 0, 1);
}

function getMonthlyMarkers() {
  return [
    { label: 'Plus $20', positionPercent: computeMonthlyProgress(20) * 100 },
    { label: 'Pro100 $100', positionPercent: computeMonthlyProgress(100) * 100 },
    { label: 'Pro200 $200', positionPercent: computeMonthlyProgress(200) * 100 },
    { label: 'Cap $46.5K', positionPercent: computeMonthlyProgress(REFERENCE_CAP) * 100 },
  ];
}

function Marker({ label, positionPercent }: { label: string; positionPercent: number }) {
  const left = `${clamp(positionPercent, 0, 100)}%`;
  return (
    <div
      className="absolute flex flex-col items-center"
      style={{ left, transform: 'translateX(-50%)', top: '0.45rem' }}
      aria-hidden="true"
    >
      <span className="h-2 w-px" style={{ backgroundColor: 'var(--text-tertiary)' }} />
      <span className="mt-1 text-[10px] text-tertiary whitespace-nowrap">{label}</span>
    </div>
  );
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function formatUSD(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return '--';
  return value.toFixed(2);
}
