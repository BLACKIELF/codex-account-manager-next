import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const componentPath = new URL('../src/components/LeadershipPanel.tsx', import.meta.url);
const stylesheetPath = new URL('../src/index.css', import.meta.url);

test('uses one shared coordinate domain for seven stage lockups and the score track', async () => {
  const [component, stylesheet] = await Promise.all([
    readFile(componentPath, 'utf8'),
    readFile(stylesheetPath, 'utf8'),
  ]);

  assert.match(component, /className="leadership-rail-stage-layer"/, 'stages should render in their own layer');
  assert.match(component, /className="leadership-rail-track-layer"/, 'track should render in its own layer');
  assert.match(component, /className="leadership-rail-stage"/, 'each band should render a fixed stage lockup');

  assert.match(stylesheet, /--leadership-rail-inset:\s*38px/, 'both layers need the macOS safe inset');
  const sharedCoordinateRule =
    stylesheet.match(
      /\.leadership-rail-stage-layer,\s*\.leadership-rail-track-layer\s*\{([\s\S]*?)\n\s*\}/,
    )?.[1] ?? '';
  assert.match(
    sharedCoordinateRule,
    /margin-inline:\s*var\(--leadership-rail-inset\)/,
    'stage and track coordinates should start and end at the shared inset',
  );
  assert.match(
    stylesheet,
    /\.leadership-rail-stage\s*\{[\s\S]*?width:\s*62px/,
    'each stage should reserve the fixed macOS lockup width',
  );
  assert.match(
    stylesheet,
    /\.leadership-rail-stage-badge-slot\s*\{[\s\S]*?width:\s*33px[\s\S]*?height:\s*33px/,
    'active and inactive badges should share one fixed baseline slot',
  );

  assert.doesNotMatch(component, /leadership-threshold-points|leadership-rail-score-stem|leadership-rail-score-pin/);
  assert.doesNotMatch(stylesheet, /leadership-rail-badge-(large|left-edge)|leadership-rail-node-left-edge/);
});
