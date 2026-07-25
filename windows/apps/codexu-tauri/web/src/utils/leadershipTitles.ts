import l7Badge from '../../../../../../Resources/LeadershipBadges/leadership-badge-l7.png';
import l6Badge from '../../../../../../Resources/LeadershipBadges/leadership-badge-l6.png';
import l5Badge from '../../../../../../Resources/LeadershipBadges/leadership-badge-l5.png';
import l4Badge from '../../../../../../Resources/LeadershipBadges/leadership-badge-l4.png';
import l3Badge from '../../../../../../Resources/LeadershipBadges/leadership-badge-l3.png';
import l2Badge from '../../../../../../Resources/LeadershipBadges/leadership-badge-l2.png';
import l1Badge from '../../../../../../Resources/LeadershipBadges/leadership-badge-l1.png';

export type LeadershipBandId = 'l1' | 'l2' | 'l3' | 'l4' | 'l5' | 'l6' | 'l7';

export interface LeadershipBand {
  id: LeadershipBandId;
  level: 1 | 2 | 3 | 4 | 5 | 6 | 7;
  scoreMin: number;
  scoreMax: number;
  zhName: string;
  enName: string;
  badge: string;
}

export const LEADERSHIP_BANDS: readonly LeadershipBand[] = [
  {
    id: 'l1',
    level: 1,
    scoreMin: 0,
    scoreMax: 19,
    zhName: '碳基牛马',
    enName: 'Carbon Laborer',
    badge: l1Badge,
  },
  {
    id: 'l2',
    level: 2,
    scoreMin: 20,
    scoreMax: 34,
    zhName: '赛博监工',
    enName: 'Cyber Overseer',
    badge: l2Badge,
  },
  {
    id: 'l3',
    level: 3,
    scoreMin: 35,
    scoreMax: 49,
    zhName: '分身队长',
    enName: 'Clone Captain',
    badge: l3Badge,
  },
  {
    id: 'l4',
    level: 4,
    scoreMin: 50,
    scoreMax: 64,
    zhName: '硅基领主',
    enName: 'Silicon Lord',
    badge: l4Badge,
  },
  {
    id: 'l5',
    level: 5,
    scoreMin: 65,
    scoreMax: 79,
    zhName: '硅基统帅',
    enName: 'Silicon Marshal',
    badge: l5Badge,
  },
  {
    id: 'l6',
    level: 6,
    scoreMin: 80,
    scoreMax: 92,
    zhName: '超级个体',
    enName: 'Super Individual',
    badge: l6Badge,
  },
  {
    id: 'l7',
    level: 7,
    scoreMin: 93,
    scoreMax: 100,
    zhName: '人类最强者',
    enName: "Humanity's Apex",
    badge: l7Badge,
  },
] as const;

export interface LeadershipSignalState {
  score: number;
  evidenceRatio: number;
  activeDays: number;
}

export function hasLeadershipSignal(state: LeadershipSignalState): boolean {
  const { score, evidenceRatio, activeDays } = state;

  if (!Number.isFinite(score)) {
    return false;
  }
  const rounded = Math.max(0, Math.min(100, Math.round(score)));
  if (rounded < 0 || rounded > 100) {
    return false;
  }

  return activeDays > 0 && evidenceRatio > 0;
}

export function resolveLeadershipBand(
  score: number | null | undefined,
  evidenceRatio: number,
  activeDays: number,
): LeadershipBand | null {
  if (!hasLeadershipSignal({ score: score ?? NaN, evidenceRatio, activeDays })) {
    return null;
  }

  const value = Math.max(0, Math.min(100, Math.round(score ?? 0)));
  return LEADERSHIP_BANDS.find((tier) => value >= tier.scoreMin && value <= tier.scoreMax) ?? null;
}
