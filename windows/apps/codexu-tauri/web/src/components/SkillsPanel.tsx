import { Eye, Puzzle } from 'lucide-react';
import type { SkillUsage } from '../types/models';

interface SkillsPanelProps {
  skills: SkillUsage[];
}

export function SkillsPanel({ skills }: SkillsPanelProps) {
  if (skills.length === 0) {
    return (
      <section className="glass-panel p-5 sm:p-6 text-center" aria-label="Local Skill observations">
        <Puzzle size={20} className="mx-auto text-secondary" aria-hidden="true" />
        <h3 className="mt-3 text-sm font-semibold text-primary">No local Skill reads observed</h3>
        <p className="mt-2 text-sm text-secondary">
          This snapshot has no recorded <code>SKILL.md</code> reads yet.
        </p>
        <p className="mt-2 text-xs text-tertiary">
          Paths, prompts, tool input, and source contents stay local.
        </p>
      </section>
    );
  }

  return (
    <section className="glass-panel p-4 sm:p-5" aria-label="Local Skill observations">
      <header className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div className="flex items-start gap-3">
          <span className="mt-0.5 inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-accent/12 text-accent">
            <Puzzle size={16} aria-hidden="true" />
          </span>
          <div>
            <h3 className="text-sm font-semibold text-primary">Skills</h3>
            <p className="mt-1 text-xs text-secondary">Skills reflect local SKILL.md reads only.</p>
          </div>
        </div>
        <span className="inline-flex items-center gap-1.5 self-start chip-like text-tertiary">
          <Eye size={12} aria-hidden="true" /> Privacy filtered
        </span>
      </header>

      <div className="mt-4 divide-y divide-theme rounded-xl border border-theme bg-surface-inset" role="list">
        {skills.slice(0, 20).map((skill) => (
          <article key={skill.id} className="flex items-center justify-between gap-4 px-3 py-3 sm:px-4" role="listitem">
            <div className="min-w-0">
              <p className="truncate text-sm font-medium text-primary">{skill.name}</p>
              <p className="mt-0.5 text-xs text-tertiary">
                {skill.source_label} · {formatThreadCount(skill.thread_count)}
                {skill.last_loaded_at == null ? '' : ` · ${formatObservedAt(skill.last_loaded_at)}`}
              </p>
            </div>
            <p className="shrink-0 text-right text-sm font-semibold tabular-nums text-primary">
              {formatReadCount(skill.load_count)}
              <span className="mt-0.5 block text-xs font-normal text-tertiary">local reads</span>
            </p>
          </article>
        ))}
      </div>

      <p className="mt-3 text-xs text-tertiary">
        Paths, prompts, tool input, and source contents stay local.
      </p>
    </section>
  );
}

function formatReadCount(value: number): string {
  return Math.max(0, Math.round(value)).toLocaleString();
}

function formatThreadCount(value: number): string {
  const count = Math.max(0, Math.round(value));
  return `${count} ${count === 1 ? 'session' : 'sessions'}`;
}

function formatObservedAt(value: number): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'time unavailable';

  return new Intl.DateTimeFormat(undefined, {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(date);
}
