import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const usagePanelPath = new URL('../src/components/UsagePanel.tsx', import.meta.url);
const trendChartPath = new URL('../src/components/TrendChart.tsx', import.meta.url);
const heatmapPath = new URL('../src/components/UsageHeatmap.tsx', import.meta.url);

test('builds Usage around local source quality, token layers, and the existing trend contract', async () => {
  const [usagePanel, trendChart, heatmap] = await Promise.all([
    readFile(usagePanelPath, 'utf8'),
    readFile(trendChartPath, 'utf8'),
    readFile(heatmapPath, 'utf8'),
  ]);

  assert.match(usagePanel, /<UsageHeatmap trend=\{trend\} \/>/);
  assert.match(usagePanel, /useI18n/);
  assert.match(usagePanel, /usage\.estimate/);
  assert.match(usagePanel, /usage\.notOfficial/);
  assert.match(usagePanel, /TokenBreakdownBar/);
  assert.match(usagePanel, /source_quality/);

  assert.match(trendChart, /visibleTotalTokens/);
  assert.match(trendChart, /summary\.seven_day/);
  assert.match(trendChart, /daily_average_tokens/);
  assert.match(trendChart, /change_percent/);

  assert.match(heatmap, /heatmap_weeks/);
  assert.match(heatmap, /heatmap_thresholds/);
  assert.match(heatmap, /is_future/);
  assert.match(heatmap, /usage\.noRecordedUsage/);
});
