import type { ProjectBoard as ProjectBoardData, ToolUsage } from '../types/models';
import { ProjectActivityOverview, ProjectBoard } from './ProjectBoard';
import { ToolUsageList } from './ToolUsageList';

interface ProjectsPanelProps {
  projectBoard: ProjectBoardData | null;
  tools: ToolUsage[];
}

export function ProjectsPanel({ projectBoard, tools }: ProjectsPanelProps) {
  return (
    <section className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <ProjectBoard projectBoard={projectBoard} />
      <ProjectActivityOverview projectBoard={projectBoard} />
      <div className="lg:col-span-2">
        <ToolUsageList tools={tools} />
      </div>
    </section>
  );
}
