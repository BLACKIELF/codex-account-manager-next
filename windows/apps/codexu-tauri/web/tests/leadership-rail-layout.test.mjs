import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const componentPath = new URL('../src/components/LeadershipPanel.tsx', import.meta.url);
const stylesheetPath = new URL('../src/index.css', import.meta.url);

function matchingDivEnd(source, start) {
  const tagPattern = /<\/?div\b[^>]*>/g;
  tagPattern.lastIndex = start;
  let depth = 0;

  for (let match = tagPattern.exec(source); match; match = tagPattern.exec(source)) {
    depth += match[0].startsWith('</') ? -1 : 1;
    if (depth === 0) return match.index + match[0].length;
  }

  throw new Error('Unclosed div in LeadershipCommandRail');
}

test('keeps the score pin and threshold dots in the exact same rail coordinate frame', async () => {
  const [component, stylesheet] = await Promise.all([
    readFile(componentPath, 'utf8'),
    readFile(stylesheetPath, 'utf8'),
  ]);
  const thresholdStart = component.indexOf('<div className="leadership-threshold-points">');
  const scoreMarker = component.indexOf('<div className="leadership-rail-score-marker"');

  assert.notEqual(thresholdStart, -1, 'threshold frame should be rendered');
  assert.notEqual(scoreMarker, -1, 'score marker should be rendered');
  assert.ok(
    scoreMarker < matchingDivEnd(component, thresholdStart),
    'score marker must be inside the threshold frame so it shares the rail width with the dots',
  );

  const thresholdRule = stylesheet.match(/\.leadership-threshold-points\s*\{([\s\S]*?)\n\s*\}/)?.[1] ?? '';
  assert.match(thresholdRule, /left:\s*0\.6rem;/, 'threshold frame must use the track start inset');
  assert.match(thresholdRule, /right:\s*0\.6rem;/, 'threshold frame must use the track end inset');
});
