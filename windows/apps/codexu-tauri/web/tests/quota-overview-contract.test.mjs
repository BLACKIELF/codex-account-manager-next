import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const quotaPath = new URL('../src/components/QuotaOverview.tsx', import.meta.url);
const homePath = new URL('../src/components/DashboardHome.tsx', import.meta.url);
const dashboardPath = new URL('../src/windows/Dashboard.tsx', import.meta.url);

test('renders every returned official quota window and exposes a retryable first-read state', async () => {
  const [quota, home, dashboard] = await Promise.all([
    readFile(quotaPath, 'utf8'),
    readFile(homePath, 'utf8'),
    readFile(dashboardPath, 'utf8'),
  ]);

  assert.match(quota, /snapshot\?\.five_hour_quota/);
  assert.match(quota, /snapshot\?\.seven_day_quota/);
  assert.match(quota, /snapshot\?\.monthly_quota/);
  assert.match(quota, /quota\.checking/);
  assert.match(quota, /quota\.retry/);
  assert.doesNotMatch(
    quota,
    /snapshot\?\.five_hour_quota\s*!=\s*null\s*&&\s*snapshot\?\.seven_day_quota\s*!=\s*null/,
  );
  assert.match(home, /<QuotaOverview snapshot=\{snapshot\} sourceLabel=\{quotaSourceLabel\} onRefresh=\{onQuotaRefresh\}/);
  assert.match(dashboard, /onQuotaRefresh=\{refresh\}/);
  assert.match(dashboard, /const quotaStatusLabel/);
  assert.match(dashboard, /dashboard\.status\.officialQuotaActive/);
  assert.doesNotMatch(quota, /today_tokens|seven_day_tokens|lifetime_tokens/);
});
