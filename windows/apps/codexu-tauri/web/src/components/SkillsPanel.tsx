import { Activity, Eye, Puzzle } from 'lucide-react';
import type { CSSProperties } from 'react';
import type { SkillUsage } from '../types/models';

interface SkillsPanelProps {
  skills: SkillUsage[];
}

type SkillActivityStyle = CSSProperties & {
  '--skill-intensity': string;
};

const MAX_VISIBLE_SKILLS = 20;

export function SkillsPanel({ skills }: SkillsPanelProps) {
  if (skills.length === 0) {
    return (
      <section
        className="glass-panel flex min-h-[190px] flex-col items-center justify-center p-5 text-center sm:p-6"
        aria-label="Local Skill usage"
        aria-live="polite"
      >
        <Puzzle size={20} className="text-secondary" aria-hidden="true" />
        <h3 className="mt-3 text-sm font-semibold text-primary">Skills</h3>
        <p className="mt-2 text-sm text-secondary">No local Skill reads observed in this snapshot.</p>
        <p className="mt-2 max-w-md text-xs text-tertiary">
          Skill activity will appear after a local <code>SKILL.md</code> read. Paths, prompts, tool input, and source
          contents stay local.
        </p>
      </section>
    );
  }

  const summary = summarizeSkills(skills);
  const rankedSkills = [...skills].sort(compareSkillUsage).slice(0, MAX_VISIBLE_SKILLS);

  return (
    <section className="glass-panel p-4 sm:p-5" aria-label="Local Skill usage">
      <header className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div className="flex items-start gap-3">
          <span className="mt-0.5 inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-accent/12 text-accent">
            <Puzzle size={16} aria-hidden="true" />
          </span>
          <div>
            <h3 className="text-sm font-semibold text-primary">Skills</h3>
            <p className="mt-1 text-xs text-secondary">Local Skill usage</p>
          </div>
        </div>
        <span className="inline-flex items-center gap-1.5 self-start chip-like text-tertiary">
          <Eye size={12} aria-hidden="true" /> Privacy filtered
        </span>
      </header>

      <div className="mt-4 grid grid-cols-1 gap-2 sm:grid-cols-3" aria-label="Skills summary">
        <SummaryMetric label="Tracked Skills" value={formatCount(summary.trackedSkills)} />
        <SummaryMetric label="Local reads" value={formatCount(summary.totalReads)} />
        <SummaryMetric label="Sessions" value={formatCount(summary.totalSessions)} />
      </div>

      <div className="mt-4 overflow-hidden rounded-xl border border-theme bg-surface-inset" role="list">
        <div className="hidden items-center gap-4 border-b border-theme px-3 py-2 text-[11px] font-medium uppercase tracking-[0.08em] text-tertiary sm:flex sm:px-4">
          <span className="min-w-0 flex-1">Skill</span>
          <span className="w-48 text-right">Relative activity</span>
          <span className="w-20 text-right">Reads</span>
        </div>
        {rankedSkills.map((skill) => {
          const reads = safeCount(skill.load_count);
          const intensity = Math.round((reads / summary.maxReads) * 100);

          return (
            <article
              key={skill.id}
              className="flex flex-col gap-3 border-b border-theme px-3 py-3 last:border-b-0 sm:flex-row sm:items-center sm:gap-4 sm:px-4"
              role="listitem"
            >
              <div className="min-w-0 flex-1">
                <p className="break-words text-sm font-medium leading-snug text-primary" title={skill.name}>
                  {skill.name}
                </p>
                <p className="mt-1 text-xs text-tertiary">
                  {skill.source_label || 'Local source'} · {formatThreadCount(skill.thread_count)} ·{' '}
                  {formatObservedAt(skill.last_loaded_at)}
                </p>
              </div>

              <div className="flex items-center gap-3 sm:w-48 sm:shrink-0">
                <div className="min-w-0 flex-1">
                  <div
                    className="skill-activity-bar"
                    role="img"
                    aria-label={`Relative activity ${intensity}%`}
                    style={{ '--skill-intensity': `${intensity}%` } as SkillActivityStyle}
                  />
                  <p className="mt-1 text-[11px] text-tertiary sm:text-right">{intensity}% of top Skill</p>
                </div>
                <div className="w-20 shrink-0 text-right">
                  <p className="text-sm font-semibold tabular-nums text-primary">{formatCount(reads)}</p>
                  <p className="mt-0.5 text-[11px] text-tertiary">local reads</p>
                </div>
              </div>
            </article>
          );
        })}
      </div>

      <p className="mt-3 flex items-center gap-1.5 text-xs text-tertiary">
        <Activity size={13} aria-hidden="true" />
        Local observations only; source contents stay on this device.
      </p>
    </section>
  );
}

function SummaryMetric({ label, value }: { label: string; value: string }): JSX.Element {
  return (
    <div className="rounded-xl border border-theme bg-surface-inset px-3 py-2.5">
      <p className="text-[11px] font-medium uppercase tracking-[0.08em] text-tertiary">{label}</p>
      <p className="mt-1 text-lg font-semibold tabular-nums text-primary">{value}</p>
    </div>
  );
}

function summarizeSkills(skills: SkillUsage[]) {
  const totalReads = skills.reduce((sum, skill) => sum + safeCount(skill.load_count), 0);
  const totalSessions = skills.reduce((sum, skill) => sum + safeCount(skill.thread_count), 0);
  const maxReads = Math.max(1, ...skills.map((skill) => safeCount(skill.load_count)));

  return {
    trackedSkills: skills.length,
    totalReads,
    totalSessions,
    maxReads,
  };
}

function compareSkillUsage(left: SkillUsage, right: SkillUsage): number {
  const readDifference = safeCount(right.load_count) - safeCount(left.load_count);
  if (readDifference !== 0) return readDifference;

  const leftTimestamp = validTimestamp(left.last_loaded_at);
  const rightTimestamp = validTimestamp(right.last_loaded_at);
  if (leftTimestamp === null && rightTimestamp !== null) return 1;
  if (leftTimestamp !== null && rightTimestamp === null) return -1;
  if (leftTimestamp !== null && rightTimestamp !== null && leftTimestamp !== rightTimestamp) {
    return rightTimestamp - leftTimestamp;
  }

  return left.id.localeCompare(right.id);
}

function safeCount(value: number): number {
  return Number.isFinite(value) ? Math.max(0, Math.round(value)) : 0;
}

function formatCount(value: number): string {
  return safeCount(value).toLocaleString();
}

function formatThreadCount(value: number): string {
  const count = safeCount(value);
  return `${count} ${count === 1 ? 'session' : 'sessions'}`;
}

function validTimestamp(value: number | null): number | null {
  if (value == null || !Number.isFinite(value)) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : value;
}

function formatObservedAt(value: number | null): string {
  const timestamp = validTimestamp(value);
  if (timestamp === null) return 'Not observed';

  return new Intl.DateTimeFormat(undefined, {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(new Date(timestamp));
}
