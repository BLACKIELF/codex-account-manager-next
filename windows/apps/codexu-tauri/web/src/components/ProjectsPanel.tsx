import type { ProjectUsage, ToolUsage } from '../types/models';
import { ProjectBoard } from './ProjectBoard';
import { ToolUsageList } from './ToolUsageList';

interface ProjectsPanelProps {
  projects: ProjectUsage[];
  tools: ToolUsage[];
}

export function ProjectsPanel({ projects, tools }: ProjectsPanelProps) {
  return (
    <section className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <ProjectBoard projects={projects} />
      <ToolUsageList tools={tools} />
    </section>
  );
}
