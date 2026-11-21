// Seeded, realistic histories for screenshots (?app=1&scenario=<id>). All times are relative to now.
import type { Answers } from '../calc'
import { type AppState, type LogEntry, type Craving, type CheckIn, freshState, derive, earned, addDays, midnight, dayKey } from './store'

function rng(seed: number) {
  return () => { seed |= 0; seed = (seed + 0x6d2b79f5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296 }
}

// Hour weights: busy after lunch and late evening, like the spec's example pattern.
const W = [0.3, 0.1, 0, 0, 0, 0, 0, 0.4, 1, 0.8, 0.8, 0.9, 1.8, 1.9, 1, 0.9, 1, 0.9, 1, 0.9, 1.1, 1.7, 1.9, 1.2]

function dayLogs(day: number, n: number, r: () => number, untilHour = 24): LogEntry[] {
  const w = W.map((x, h) => (h < untilHour ? x : 0))
  const sum = w.reduce((a, b) => a + b, 0)
  const out: LogEntry[] = []
  for (let i = 0; i < n; i++) {
    let x = r() * sum, h = 0
    while (h < 23 && x > w[h]) { x -= w[h]; h++ }
    const maxMin = h === Math.floor(untilHour) ? Math.max(1, (untilHour - h) * 60 - 2) : 59
    out.push({ id: `l${day}-${i}`, at: day + h * 36e5 + Math.floor(r() * maxMin) * 6e4, source: r() < 0.7 ? 'widget' : 'app' })
  }
  return out.sort((a, b) => a.at - b.at)
}

interface Spec {
  daysAgo: number // day 1 was this many days before today
  hour: number // clock time today
  used: number[] // per completed day
  today: number
  beaten?: number
  gaveIn?: number
  setup?: Partial<AppState['setup']>
  allowed?: boolean
  reviewed?: number[]
  quitSeen?: boolean
  morning?: boolean
  weeks?: number
}

function build(a: Answers, sp: Spec): { state: AppState; clock: number } {
  const today = midnight(Date.now())
  const clock = today + sp.hour * 36e5
  const r = rng(7 + sp.daysAgo * 31 + sp.today)
  const answers = sp.weeks ? { ...a, weeks: sp.weeks } : a
  const s = freshState(answers, addDays(today, -sp.daysAgo))
  s.welcomed = true
  s.signature = undefined
  const logs: LogEntry[] = []
  sp.used.forEach((n, d) => logs.push(...dayLogs(addDays(s.start, d), n, r)))
  logs.push(...dayLogs(today, sp.today, r, sp.hour))
  s.logs = logs.filter((l) => l.at <= clock)

  const cr: Craving[] = []
  const span = Math.max(1, (clock - s.start) / 36e5)
  const kinds: Craving['outcome'][] = [...Array(sp.beaten ?? 0).fill('beaten'), ...Array(sp.gaveIn ?? 0).fill('gaveIn')]
  for (let i = kinds.length - 1; i > 0; i--) { const j = Math.floor(r() * (i + 1)); [kinds[i], kinds[j]] = [kinds[j], kinds[i]] }
  kinds.forEach((outcome, i) => {
    const at = s.start + Math.floor(((i + 0.3 + r() * 0.4) / kinds.length) * span) * 36e5 + Math.floor(r() * 50) * 6e4
    cr.push({ id: 'c' + i, at: Math.min(at, clock - 6e5), outcome, method: r() < 0.75 ? 'breathe' : 'reasons' })
  })
  s.cravings = cr

  const ci: CheckIn[] = []
  const moods = ['good', 'ok', 'hard'] as const
  for (let d = 0; d < sp.used.length; d++) {
    const k = dayKey(addDays(s.start, d) + 12 * 36e5)
    ci.push({ date: k, kind: 'morning' })
    const bud = s.budgets[Math.floor(d / 7)] ?? 0
    ci.push({ date: k, kind: 'evening', mood: sp.used[d] <= bud ? moods[d % 2] : 'hard' })
  }
  if (sp.morning ?? sp.hour >= 11) ci.push({ date: dayKey(clock), kind: 'morning' })
  s.checkins = ci

  s.setup = { ...s.setup, ...sp.setup }
  s.notifsAllowed = sp.allowed ?? !!sp.setup?.checkins
  s.reviewed = sp.reviewed ?? []
  s.quitSeen = sp.quitSeen ?? false
  // celebrations already earned before "now" were seen on earlier days
  s.celebrated = earned(s, derive(s, clock)).map((c) => c.key)
  return { state: s, clock }
}

// a gently realistic taper: usually a little under budget, sometimes over
function taper(a: Answers, days: number, seed: number, weeks?: number) {
  const s = freshState(weeks ? { ...a, weeks } : a)
  const r = rng(seed)
  return [...Array(days).keys()].map((d) => {
    const bud = s.budgets[Math.floor(d / 7)] ?? 0
    if (bud === 0) return d % 7 < 2 ? 2 - (d % 7) : 0
    return Math.max(0, Math.round(bud * (0.82 + r() * 0.26)))
  })
}

export const SCENARIOS = ['day1', 'midweek', 'near', 'over', 'stepdown', 'adaptive', 'free', 'quitday', 'rough'] as const

export function scenario(id: string, a: Answers): { state: AppState; clock: number } | null {
  const b = freshState(a).budgets
  const b0 = b[0], b1 = b[1] ?? b0
  switch (id) {
    case 'day1': return build(a, { daysAgo: 0, hour: 9.2, used: [], today: 0, morning: false })
    case 'midweek': return build(a, { daysAgo: 3, hour: 15.33, used: [b0 - 1, b0 + 2, b0 - 3], today: Math.round(b0 * 0.6), beaten: 4, gaveIn: 1, setup: { widget: true, sos: true } })
    case 'near': return build(a, { daysAgo: 3, hour: 18.67, used: [b0 - 1, b0 + 2, b0 - 3], today: Math.round(b0 * 0.86), beaten: 5, gaveIn: 1, setup: { widget: true, sos: true, checkins: true } })
    case 'over': return build(a, { daysAgo: 4, hour: 21.25, used: [b0 - 1, b0 + 2, b0 - 3, b0], today: b0 + 4, beaten: 5, gaveIn: 2, setup: { widget: true, sos: true, checkins: true } })
    case 'stepdown': return build(a, { daysAgo: 7, hour: 8.5, used: [b0 - 1, b0 + 1, b0 - 2, b0 + 2, b0 - 3, b0 - 4, b0 - 5], today: 0, beaten: 9, gaveIn: 2, morning: false, setup: { widget: true, sos: true, checkins: true, reasons: true } })
    case 'adaptive': return build(a, { daysAgo: 11, hour: 13, used: [b0 - 1, b0, b0 - 2, b0 + 1, b0 - 3, b0 - 1, b0 - 4, b1 + 4, b1 + 2, b1 - 1, b1 + 3], today: Math.round(b1 * 0.5), beaten: 11, gaveIn: 3, reviewed: [1], setup: { widget: true, sos: true, checkins: true, reasons: true } })
    case 'free': { const n = b.length * 7; return build(a, { daysAgo: n + 4, hour: 14, used: [...taper(a, n, 3), 0, 0, 0, 0], today: 0, beaten: 31, gaveIn: 6, reviewed: b.map((_, i) => i), quitSeen: true, setup: { widget: true, sos: true, checkins: true, reasons: true } }) }
    case 'quitday': { const n = b.length * 7; return build(a, { daysAgo: n, hour: 10.5, used: taper(a, n, 5), today: 0, beaten: 28, gaveIn: 6, reviewed: b.map((_, i) => i), quitSeen: false, setup: { widget: true, sos: true, checkins: true, reasons: true } }) }
    case 'rough': return build(a, { daysAgo: 7, hour: 8.5, used: [b0 + 3, b0 + 1, b0 - 1, b0 + 4, b0 + 2, b0 + 2, b0 - 2], today: 0, beaten: 3, gaveIn: 5, morning: false, setup: { widget: true, sos: true, checkins: true } })
    default: return null
  }
}
