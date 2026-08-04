import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const dashboardPath = new URL('../src/windows/Dashboard.tsx', import.meta.url);
const homePath = new URL('../src/components/DashboardHome.tsx', import.meta.url);
const stylesheetPath = new URL('../src/index.css', import.meta.url);

test('keeps one macOS-ordered Dashboard tab system and relegates Leadership to its panel', async () => {
  const [dashboard, home, stylesheet] = await Promise.all([
    readFile(dashboardPath, 'utf8'),
    readFile(homePath, 'utf8'),
    readFile(stylesheetPath, 'utf8'),
  ]);

  assert.doesNotMatch(dashboard, /type DashboardTab\s*=/);
  assert.doesNotMatch(dashboard, /<LeadershipPanel\b/);
  assert.doesNotMatch(dashboard, /<ThreadList\b/);
  assert.match(dashboard, /<DashboardHome[\s\S]*?snapshot=\{dashboard\?\.codex\?\.snapshot\}/);

  assert.match(
    home,
    /type DashboardContentTab\s*=\s*'tasks'\s*\|\s*'leadership'\s*\|\s*'usage'\s*\|\s*'projects'\s*\|\s*'skills'/,
  );
  assert.match(home, /useState<DashboardContentTab>\('tasks'\)/);
  assert.match(
    home,
    /\{ id: 'tasks', title: 'Tasks', titleKey: 'dashboard\.tabs\.tasks' \}[\s\S]*\{ id: 'leadership', title: 'AI Leadership', titleKey: 'dashboard\.tabs\.leadership' \}[\s\S]*\{ id: 'usage', title: 'Usage', titleKey: 'dashboard\.tabs\.usage' \}[\s\S]*\{ id: 'projects', title: 'Projects', titleKey: 'dashboard\.tabs\.projects' \}[\s\S]*\{ id: 'skills', title: 'Skills', titleKey: 'dashboard\.tabs\.skills' \}/,
  );
  assert.match(home, /useI18n/);
  assert.match(home, /activeDashboardTab === 'leadership'[\s\S]*?<LeadershipPanel signal=\{signal\}/);
  assert.match(home, /setActiveDashboardTab\('leadership'\)/);
  assert.doesNotMatch(home, /<LeadershipCommandRail\b/);
  assert.doesNotMatch(home, /Leadership facts/);

  assert.match(home, /className="dashboard-home-overview"/);
  assert.match(home, /<LeadershipOverviewCard/);
  assert.match(home, /className="dashboard-home-monthly"/);
  assert.match(
    stylesheet,
    /\.dashboard-home-overview\s*\{[\s\S]*?grid-template-areas:\s*"command"\s*"quota"\s*"metrics"\s*"month"/,
  );
  assert.match(
    stylesheet,
    /@media \(min-width: 930px\)\s*\{[\s\S]*?grid-template-areas:\s*"command quota metrics"\s*"command quota month"/,
  );
  assert.match(stylesheet, /\.dashboard-home-command\s*\{[\s\S]*?grid-area:\s*command/);
  assert.match(stylesheet, /\.dashboard-home-quota\s*\{[\s\S]*?grid-area:\s*quota/);
  assert.match(stylesheet, /\.dashboard-home-metrics\s*\{[\s\S]*?grid-area:\s*metrics/);
  assert.match(stylesheet, /\.dashboard-home-monthly\s*\{[\s\S]*?grid-area:\s*month/);
});
