// All the nicotine math lives here so the Swift port can copy it 1:1.
// Every number is an estimate and the UI says so.

export type Device = 'disposable' | 'pod' | 'refill' | 'pouch' | 'combo'

export interface Answers {
  device?: Device
  duration?: string
  strength?: number // mg/mL of e-liquid (5% ≈ 50)
  dispSize?: number // claimed puffs per disposable
  dispDays?: number // days one disposable lasts
  podsPerDay?: number
  hitsPerDay?: number // times they pick it up a day
  mlPerDay?: number
  pouchesPerDay?: number
  pouchMg?: number
  firstHit?: 'lt5' | '5to30' | '31to60' | 'gt60'
  triggers?: string[]
  weeklySpend?: number
  tried?: 'never' | 'once' | 'few' | 'lost'
  hardParts?: string[]
  reasons?: string[]
  name?: string
  age?: string
  weeks?: number
  signed?: boolean
}

export const usesVape = (a: Answers) => a.device !== 'pouch'
export const usesPouch = (a: Answers) => a.device === 'pouch' || a.device === 'combo'

// Reference point: Juul says one 0.7 mL, 5% pod (~41 mg) ≈ a pack of 20.
// So ~2 mg of nicotine in e-liquid ≈ 1 cigarette.
const LIQUID_MG_PER_CIG = 2.05
// A ~6 mg pouch delivers roughly what one cigarette does.
const POUCH_MG_PER_CIG = 6
// Typical e-liquid inside a disposable, by the puff count on the box.
const DISP_ML: Record<number, number> = { 800: 2, 3000: 8, 6000: 13, 12000: 18 }

export function liquidMlPerDay(a: Answers): number {
  if (!usesVape(a)) return 0
  switch (a.device) {
    case 'disposable':
    case 'combo':
      return (DISP_ML[a.dispSize ?? 6000] ?? 13) / (a.dispDays ?? 5)
    case 'pod':
      return (a.podsPerDay ?? 1) * 0.8
    case 'refill':
      return a.mlPerDay ?? 3
    default:
      return 0
  }
}

export function nicotineMgPerDay(a: Answers): number {
  const vapeMg = liquidMlPerDay(a) * (a.strength ?? 50)
  const pouchMg = usesPouch(a) ? (a.pouchesPerDay ?? 0) * (a.pouchMg ?? 6) : 0
  return Math.round(vapeMg + pouchMg)
}

export function cigsPerDay(a: Answers): number {
  const fromVape = (liquidMlPerDay(a) * (a.strength ?? 50)) / LIQUID_MG_PER_CIG
  const fromPouch = usesPouch(a) ? ((a.pouchesPerDay ?? 0) * (a.pouchMg ?? 6)) / POUCH_MG_PER_CIG : 0
  return fromVape + fromPouch
}

export const packsPerDay = (a: Answers) => Math.round((cigsPerDay(a) / 20) * 10) / 10

export const yearlySpend = (a: Answers) => Math.round((a.weeklySpend ?? 30) * 52)

// Dependence: time to first use after waking is the single strongest
// question in the Fagerström test; amount per day is the second.
export function dependence(a: Answers): { score: number; label: string; level: number } {
  const t = { lt5: 3, '5to30': 2, '31to60': 1, gt60: 0 }[a.firstHit ?? '5to30']
  const c = cigsPerDay(a)
  const amt = c > 30 ? 3 : c > 20 ? 2 : c > 10 ? 1 : 0
  const score = t + amt // 0..6
  const level = score >= 5 ? 3 : score >= 3 ? 2 : score >= 2 ? 1 : 0
  const label = ['Low', 'Moderate', 'High', 'Very high'][level]
  return { score, label, level }
}

export function recommendedWeeks(a: Answers): number {
  return [2, 4, 6, 6][dependence(a).level]
}

// Daily budget per week, stepping down to zero in the last week.
// The unit is what they actually count: puffs, or pouches if pouch-only.
export function budgetUnit(a: Answers): 'hits' | 'pouches' {
  return a.device === 'pouch' ? 'pouches' : 'hits'
}

export function startAmount(a: Answers): number {
  return budgetUnit(a) === 'pouches' ? a.pouchesPerDay ?? 8 : a.hitsPerDay ?? 30
}

export function plan(a: Answers): number[] {
  const weeks = a.weeks ?? recommendedWeeks(a)
  const start = startAmount(a)
  const steps: number[] = []
  for (let w = 0; w < weeks; w++) {
    const frac = 1 - (w + 1) / weeks
    const v = w === weeks - 1 ? 0 : start * Math.max(0.1, 0.85 * frac + 0.05)
    steps.push(Math.round(v))
  }
  return steps
}

export function quitDate(a: Answers, from = new Date()): Date {
  const d = new Date(from)
  d.setDate(d.getDate() + 7 * (a.weeks ?? recommendedWeeks(a)))
  return d
}

export const fmtDate = (d: Date, withYear = false) =>
  d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', ...(withYear ? { year: 'numeric' } : {}) })

export const money = (n: number) => '$' + n.toLocaleString('en-US')

export function savedByQuit(a: Answers): number {
  // first-year saving: a full year of spend minus roughly half spend during the taper
  return Math.round(yearlySpend(a) - (a.weeklySpend ?? 30) * (a.weeks ?? recommendedWeeks(a)) * 0.5)
}
