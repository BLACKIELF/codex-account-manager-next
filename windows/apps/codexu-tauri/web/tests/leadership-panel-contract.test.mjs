import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const dashboardPath = new URL('../src/components/DashboardHome.tsx', import.meta.url);
const panelPath = new URL('../src/components/LeadershipPanel.tsx', import.meta.url);
const stylesheetPath = new URL('../src/index.css', import.meta.url);

test('keeps the leadership identity, rail, and facts as one focused visual stack', async () => {
  const [dashboard, panel, stylesheet] = await Promise.all([
    readFile(dashboardPath, 'utf8'),
    readFile(panelPath, 'utf8'),
    readFile(stylesheetPath, 'utf8'),
  ]);

  assert.match(dashboard, /<LeadershipOverviewCard/, 'the overview should use the leadership-specific identity card');
  assert.match(panel, /className="glass-panel leadership-panel-primary/, 'details need one primary leadership surface');
  assert.match(panel, /className="leadership-identity-card"/, 'the score and title need a single identity lockup');
  assert.match(panel, /className="leadership-overview-facts"/, 'overview facts need their own stable hierarchy');
  assert.match(panel, /leadership-rail-stage-title/, 'rail stages should show their localised titles');
  assert.match(panel, /band\.zhName/, 'rail titles must come from the existing leadership band data');
  assert.match(panel, /band\.enName/, 'rail titles must retain the existing English data');
  assert.match(panel, /formatPeriod\(report\.period,\s*t\)/, 'period metadata should use user-facing wording');
  assert.doesNotMatch(panel, /Period \{report\.period\}/, 'internal period identifiers must not reach the UI');

  assert.match(stylesheet, /\.leadership-panel-primary\s*\{/, 'the primary panel needs a focused layout token');
  assert.match(
    stylesheet,
    /\.leadership-overview-facts\s*\{[\s\S]*?grid-template-columns:\s*repeat\(2,/,
    'facts should use a stable 2x2 hierarchy',
  );
  assert.match(
    stylesheet,
    /\.leadership-identity-card\s*\{[\s\S]*?min-width:\s*0/,
    'identity content must be allowed to contract without moving the rail',
  );
});
