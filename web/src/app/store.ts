// App state after the paywall: everything lives on the device (here: memory + localStorage).
// Every number on screen is derived from this state by derive(); nothing is hard-coded.
import { createContext, useContext } from 'react'
import { type Answers, plan, budgetUnit, startAmount, yearlySpend, nicotineMgPerDay } from '../calc'
import { REASONS } from '../screens'

export type Source = 'app' | 'widget' | 'control' | 'sos'
export interface LogEntry { id: string; at: number; source: Source }
export interface Craving { id: string; at: number; outcome: 'beaten' | 'gaveIn'; method: 'breathe' | 'reasons' }
export type Mood = 'good' | 'ok' | 'hard'
export interface CheckIn { date: string; kind: 'morning' | 'evening'; mood?: Mood; note?: string }
export interface Slip { at: number }
export interface Notif { id: string; label: string; detail: string; time?: string; when?: string; on: boolean }
export interface Setup { widget: boolean; checkins: boolean; sos: boolean; reasons: boolean }

export interface AppState {
  v: 1
  answers: Answers
  start: number // local midnight of day 1
  budgets: number[] // daily budget per week (adaptive weeks are inserted here)
  extraWeeks: number
  logs: LogEntry[]
  cravings: Craving[]
  checkins: CheckIn[]
  slips: Slip[]
  reasons: string[]
  setup: Setup
  notifsAllowed: boolean
  notifs: Notif[]
  reviewed: number[] // weeks whose step-down review was handled
  adaptiveDone: number[] // weeks where the adaptive card was answered
  quitSeen: boolean
  welcomed: boolean
  celebrated: string[]
  signature?: string
}

export const DAY = 864e5
const HOUR = 36e5

// ---------- clock (scenarios pin "now" to a time of day; it still ticks) ----------
let offset = 0
export const now = () => Date.now() + offset
export function setClock(ms: number) { offset = ms - Date.now() }

export function midnight(t: number) { const d = new Date(t); d.setHours(0, 0, 0, 0); return d.getTime() }
export function addDays(t: number, n: number) { const d = new Date(t); d.setDate(d.getDate() + n); return d.getTime() }
export const dayKey = (t: number) => { const d = new Date(t); return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}` }
export const dayIndex = (s: AppState, t: number) => Math.round((midnight(t) - s.start) / DAY)
export const uid = () => Math.random().toString(36).slice(2, 10)

// ---------- notifications ----------
const TRIGGER_NOTIFS: Record<string, { label: string; time: string; when?: string; detail: string }[]> = {
  wake: [{ label: 'Waking up', time: '07:30', detail: 'Breakfast first, first hit after.' }],
  meals: [{ label: 'After lunch', time: '12:30', detail: 'Walk for 3 minutes before you decide.' }, { label: 'After dinner', time: '18:30', detail: 'Walk for 3 minutes before you decide.' }],
  stress: [{ label: 'Afternoon stress', time: '15:00', detail: 'Stressful moment? Hit SOS.' }],
  bored: [{ label: 'Bored moment', time: '15:00', detail: '10 slow breaths before you reach for it.' }],
  drive: [{ label: 'Commute', time: '17:30', detail: 'Leave it in the bag until you park.' }],
  work: [{ label: 'Work break', time: '10:30', detail: "A look at today's budget." }],
  drink: [{ label: 'Going out', time: '21:00', when: 'Fri', detail: 'Decide your budget before the first drink.' }],
  social: [{ label: 'Friends who vape', time: '20:00', when: 'Sat', detail: 'Hold off 5 minutes. No need to explain.' }],
  bed: [{ label: 'Before bed', time: '22:00', detail: 'The last one of the night counts too.' }],
}

export function defaultNotifs(a: Answers, budget: number, unit: string): Notif[] {
  const out: Notif[] = [{ id: 'morning', label: 'Morning budget', time: '08:00', detail: `"Today's budget: ${budget} ${unit}."`, on: true }]
  const seen = new Set<string>()
  for (const t of a.triggers ?? []) {
    for (const n of TRIGGER_NOTIFS[t] ?? []) {
      const key = n.label
      if (seen.has(n.time + (n.when ?? ''))) continue
      seen.add(n.time + (n.when ?? ''))
      out.push({ id: 'trig-' + key.toLowerCase().replace(/\s+/g, '-'), label: n.label, time: n.time, when: n.when, detail: n.detail, on: true })
    }
  }
  out.push(
    { id: 'evening', label: 'Evening check-in', time: '21:00', detail: 'How did today go?', on: true },
    { id: 'heads', label: '80% heads-up', detail: 'Right after a log that passes 80% of today.', on: true },
    { id: 'stepeve', label: 'Step-down eve', time: '20:00', detail: 'The night before your budget drops.', on: true },
    { id: 'trial', label: 'Trial reminder', detail: 'Day 5 of your free trial, as promised.', on: true },
  )
  return out.sort((x, y) => (x.time ?? '99') < (y.time ?? '99') ? -1 : 1)
}

// ---------- fresh state ----------
export function freshState(a: Answers, t = now()): AppState {
  const budgets = plan(a)
  return {
    v: 1, answers: a, start: midnight(t), budgets, extraWeeks: 0,
    logs: [], cravings: [], checkins: [], slips: [],
    reasons: (a.reasons ?? []).map((r) => REASONS.find((x) => x.id === r)?.label ?? r),
    setup: { widget: false, checkins: false, sos: false, reasons: false },
    notifsAllowed: false,
    notifs: defaultNotifs(a, budgets[0], budgetUnit(a)),
    reviewed: [], adaptiveDone: [], quitSeen: false, welcomed: false, celebrated: [],
    signature: a.signature,
  }
}

// ---------- derived numbers ----------
export interface Derived {
  t: number
  name: string
  unit: 'hits' | 'pouches'
  one: string // "hit" | "pouch"
  startAmt: number
  dayIdx: number
  weekIdx: number
  totalWeeks: number
  budget: number
  prevBudget?: number
  nextBudget?: number
  used: number
  left: number
  over: number
  pctUsed: number
  todayLogs: LogEntry[]
  quitAt: number
  daysToQuit: number
  free: boolean
  progress: number
  history: { d: number; used: number; budget: number; at: number }[] // completed + today
  underDays: number
  underStreak: number
  moneyKept: number
  mgAvoided: number
  beaten: number
  hourHist: number[]
  daysWithLogs: number
  pattern?: string
  adaptive: boolean
  reviewWeek?: number // week index to review (the one just finished is reviewWeek - 1)
  stepDownToday: boolean
  hour: number
  morningDone: boolean
  eveningDone?: CheckIn
  // free mode
  runStart: number
  freeMs: number
  bestRunDays: number
  slippedToday: boolean
}

function fmtHour(h: number) { const x = ((h % 24) + 24) % 24; return x === 0 ? '12 am' : x === 12 ? '12 pm' : x < 12 ? `${x} am` : `${x - 12} pm` }
const ampm = (h: number) => (((h % 24) + 24) % 24) < 12 ? 'am' : 'pm'

// "Most hits 12–2 pm and after 9 pm": the two busiest 2-hour windows.
function describePattern(h: number[], unit: string): string | undefined {
  const total = h.reduce((x, y) => x + y, 0)
  if (!total) return undefined
  const win = (i: number) => h[i % 24] + h[(i + 1) % 24]
  const order = [...Array(24).keys()].sort((x, y) => win(y) - win(x))
  const first = order[0]
  const dist = (i: number) => Math.min(Math.abs(i - first), 24 - Math.abs(i - first))
  const second = order.find((i) => dist(i) >= 3 && win(i) >= win(first) * 0.6)
  const label = (i: number) => {
    if (i >= 20) return `after ${fmtHour(i)}`
    if (i < 5) return 'late at night'
    const a = fmtHour(i), b = fmtHour(i + 2)
    return ampm(i) === ampm(i + 2) ? `${a.split(' ')[0]}–${b}` : `${a}–${b}`
  }
  const ws = second !== undefined ? [first, second].sort((x, y) => (x < 5 ? x + 24 : x) - (y < 5 ? y + 24 : y)) : [first]
  return `Most ${unit} ${ws.map(label).join(' and ')}`
}

export function derive(s: AppState, t = now()): Derived {
  const a = s.answers
  const unit = budgetUnit(a)
  const one = unit === 'pouches' ? 'pouch' : 'hit'
  const startAmt = startAmount(a)
  const totalWeeks = s.budgets.length
  const quitAt = addDays(s.start, totalWeeks * 7)
  const free = t >= quitAt
  const dayIdx = dayIndex(s, t)
  const planDays = totalWeeks * 7
  const weekIdx = Math.max(0, Math.min(Math.floor(dayIdx / 7), totalWeeks - 1))
  const budget = free ? 0 : s.budgets[weekIdx] ?? 0
  const prevBudget = weekIdx > 0 ? s.budgets[weekIdx - 1] : undefined
  const nextBudget = weekIdx < totalWeeks - 1 ? s.budgets[weekIdx + 1] : undefined

  const byDay = new Map<number, number>()
  const hourHist = new Array(24).fill(0)
  for (const l of s.logs) {
    if (l.at > t) continue
    const d = dayIndex(s, l.at)
    byDay.set(d, (byDay.get(d) ?? 0) + 1)
    hourHist[new Date(l.at).getHours()]++
  }
  const todayKey = midnight(t)
  const todayLogs = s.logs.filter((l) => l.at >= todayKey && l.at <= t)
  const used = todayLogs.length
  const left = budget - used

  const history: Derived['history'] = []
  const lastDay = Math.min(dayIdx, planDays - 1)
  for (let d = 0; d <= lastDay; d++) {
    history.push({ d, used: byDay.get(d) ?? 0, budget: s.budgets[Math.floor(d / 7)] ?? 0, at: addDays(s.start, d) })
  }
  const completed = history.filter((h) => h.d < dayIdx)
  const underDays = completed.filter((h) => h.used <= h.budget).length
  let underStreak = 0
  for (let i = completed.length - 1; i >= 0 && completed[i].used <= completed[i].budget; i--) underStreak++

  // money kept = (yearly/365) × days × (1 − used/start). Today counts for the part of the day gone by.
  const perDay = yearlySpend(a) / 365
  const mgDay = nicotineMgPerDay(a)
  const frac = (t - todayKey) / DAY
  let keptDays = 0
  for (const h of history) {
    const share = Math.max(0, 1 - h.used / startAmt)
    keptDays += h.d === dayIdx ? share * frac : share
  }
  if (free) keptDays += (t - quitAt) / DAY
  const moneyKept = perDay * keptDays
  const mgAvoided = mgDay * keptDays
  const beaten = s.cravings.filter((c) => c.outcome === 'beaten' && c.at <= t).length

  const daysWithLogs = byDay.size
  const pattern = daysWithLogs >= 2 ? describePattern(hourHist, unit) : undefined

  const last4 = completed.slice(-4)
  const overCount = last4.filter((h) => h.used > h.budget).length
  const adaptive = !free && last4.length === 4 && overCount >= 3 && nextBudget !== undefined && budget > 0 && !s.adaptiveDone.includes(weekIdx)

  const reviewWeek = !free && weekIdx >= 1 && dayIdx < planDays && !s.reviewed.includes(weekIdx) ? weekIdx : undefined
  const stepDownToday = !free && weekIdx > 0 && dayIdx % 7 === 0 && prevBudget !== undefined && budget < prevBudget

  const hour = new Date(t).getHours()
  const k = dayKey(t)
  const morningDone = s.checkins.some((c) => c.date === k && c.kind === 'morning')
  const eveningDone = s.checkins.find((c) => c.date === k && c.kind === 'evening')

  // free mode runs: a slip ends a run; the next run starts the following midnight
  const slips = s.slips.filter((x) => x.at >= quitAt && x.at <= t).map((x) => x.at).sort((x, y) => x - y)
  const lastSlip = slips[slips.length - 1]
  const runStart = lastSlip ? Math.max(quitAt, addDays(midnight(lastSlip), 1)) : quitAt
  const freeMs = free ? Math.max(0, t - runStart) : 0
  let best = 0, from = quitAt
  for (const sl of slips) { best = Math.max(best, sl - from); from = addDays(midnight(sl), 1) }
  best = Math.max(best, t - from)
  const slippedToday = !!lastSlip && midnight(lastSlip) === todayKey

  return {
    t, name: a.name ?? '', unit, one, startAmt, dayIdx, weekIdx, totalWeeks, budget, prevBudget, nextBudget,
    used, left, over: Math.max(0, -left), pctUsed: budget ? used / budget : used ? 1.5 : 0, todayLogs,
    quitAt, daysToQuit: Math.max(0, Math.ceil((quitAt - t) / DAY)), free,
    progress: Math.max(0, Math.min(1, (t - s.start) / (quitAt - s.start))),
    history, underDays, underStreak, moneyKept, mgAvoided, beaten, hourHist, daysWithLogs, pattern,
    adaptive, reviewWeek, stepDownToday, hour, morningDone, eveningDone,
    runStart, freeMs, bestRunDays: Math.floor(Math.max(0, best) / DAY), slippedToday,
  }
}

// Stats for the step-down review of week w-1.
export function weekStats(s: AppState, w: number, t = now()) {
  const from = (w - 1) * 7
  const d = derive(s, t)
  const days = d.history.filter((h) => h.d >= from && h.d < from + 7)
  const total = days.reduce((x, h) => x + h.used, 0)
  const ws = addDays(s.start, from), we = addDays(s.start, from + 7)
  return {
    avg: days.length ? Math.round(total / days.length) : 0,
    under: days.filter((h) => h.used <= h.budget).length,
    days: days.length,
    beaten: s.cravings.filter((c) => c.outcome === 'beaten' && c.at >= ws && c.at < we).length,
    budget: s.budgets[w - 1],
    next: s.budgets[w],
  }
}

// ---------- celebrations (small, earned) ----------
export interface Celebration { key: string; title: string; sub: string }
export function earned(s: AppState, d: Derived): Celebration[] {
  const out: Celebration[] = []
  if (d.underDays >= 1) out.push({ key: 'under1', title: 'First day under budget', sub: 'That is the whole method, done once. Now again.' })
  if (d.underStreak >= 3) out.push({ key: 'under3-' + (d.dayIdx - d.underStreak), title: '3 days in a row under budget', sub: 'You are making this look normal.' })
  if (d.beaten >= 1) out.push({ key: 'crave1', title: 'First craving beaten', sub: 'Now you know it passes.' })
  for (let n = 10; n <= d.beaten; n += 10) out.push({ key: 'crave' + n, title: `${n} cravings beaten`, sub: 'Each one you ride out makes the next one easier to ride out.' })
  if (d.progress >= 0.5 && !d.free) out.push({ key: 'half', title: 'Halfway there', sub: `Half your plan is done. ${d.daysToQuit} days to go.` })
  if (d.free && d.freeMs >= 72 * HOUR) out.push({ key: 'free72', title: '72 hours nicotine-free', sub: 'Nicotine is out of your body. What is left is habit, and habits fade.' })
  if (d.free && d.freeMs >= 30 * DAY) out.push({ key: 'free30', title: '30 days nicotine-free', sub: 'A whole month. Look how far you came.' })
  return out.filter((c) => !s.celebrated.includes(c.key))
}

// ---------- free-mode milestones (honest, general timelines) ----------
export const MILESTONES = [
  { h: 72, t: '72 h', d: 'Nicotine is out of your body' },
  { h: 14 * 24, t: '2 weeks', d: 'Cravings start to fade' },
  { h: 30 * 24, t: '30 days', d: 'A full month free' },
  { h: 60 * 24, t: '1–3 months', d: 'Breathing tends to feel easier' },
]

// ---------- persistence ----------
const KEY = 'oob.app.v1'
export function load(): AppState | null {
  try { const raw = localStorage.getItem(KEY); if (!raw) return null; const s = JSON.parse(raw); return s?.v === 1 ? s : null } catch { return null }
}
export function save(s: AppState) { try { localStorage.setItem(KEY, JSON.stringify(s)) } catch { /* private mode */ } }
export function erase() { try { localStorage.removeItem(KEY) } catch { /* ignore */ } }

// ---------- context ----------
export interface Store {
  s: AppState
  d: Derived
  update: (f: (s: AppState) => AppState) => void
  haptic: () => void
}
export const StoreCtx = createContext<Store | null>(null)
export const useStore = () => useContext(StoreCtx)!

export const fmtMoney = (n: number) => '$' + Math.round(n).toLocaleString('en-US')
export const plural = (n: number, w: string, p = w + 's') => `${n} ${n === 1 ? w : p}`
export const unitWord = (d: Derived, n: number) => (n === 1 ? d.one : d.unit)
