import { useEffect, useMemo, useRef, useState } from 'react'
import type { Answers } from '../calc'
import { APP_NAME, Icon, StatusBar } from '../ui'
import { type AppState, type Source, StoreCtx, derive, earned, freshState, load, save, now, setClock, midnight, dayKey, uid, erase } from './store'
import { scenario } from './scenarios'
import { haptic, Confetti, clockStr } from './bits'
import { Today } from './Today'
import { Plan } from './Plan'
import { You } from './You'
import { Welcome } from './Welcome'
import { Sos, type SosStep } from './Sos'
import { Review } from './Review'
import { QuitDay } from './Free'
import { WidgetGuide } from './Welcome'
import './app.css'

export type Tab = 'today' | 'plan' | 'you'
export type Overlay =
  | { kind: 'welcome'; step: number }
  | { kind: 'sos'; step: SosStep }
  | { kind: 'review' }
  | { kind: 'quitday' }
  | { kind: 'widgetguide' }
  | { kind: 'permission' }

export interface Nav {
  tab: Tab
  setTab: (t: Tab) => void
  open: (o: Overlay | null) => void
  logHit: (source?: Source) => void
  toast: (text: string, undo?: () => void) => void
  askPermission: () => void
}

const SCREEN_OVERLAY: Record<string, Overlay> = {
  welcome1: { kind: 'welcome', step: 1 }, welcome2: { kind: 'welcome', step: 2 }, welcome3: { kind: 'welcome', step: 3 },
  welcome4: { kind: 'welcome', step: 4 }, welcome5: { kind: 'welcome', step: 5 },
  sos1: { kind: 'sos', step: 'interrupt' }, sos2: { kind: 'sos', step: 'breathe' }, sos3: { kind: 'sos', step: 'pass' }, sos4: { kind: 'sos', step: 'win' },
  reasons: { kind: 'sos', step: 'reasons' }, vapeanyway: { kind: 'sos', step: 'anyway' },
  review: { kind: 'review' }, quitday: { kind: 'quitday' }, widgetguide: { kind: 'widgetguide' },
}
const SCREEN_SCENARIO: Record<string, string> = { review: 'stepdown', quitday: 'quitday', welcome1: 'day1', welcome2: 'day1', welcome3: 'day1', welcome4: 'day1', welcome5: 'day1' }

// Picks the starting state: fresh after purchase, a seeded scenario, or what's saved on this device.
export function AppRoot({ a, fromPurchase }: { a: Answers; fromPurchase?: boolean }) {
  const qs = new URLSearchParams(location.search)
  const screen = qs.get('screen') ?? undefined
  const [boot] = useState(() => {
    if (fromPurchase) return { state: freshState(a), persist: true }
    const sc = qs.get('scenario') ?? (screen ? SCREEN_SCENARIO[screen] ?? 'midweek' : null)
    if (sc) {
      const r = scenario(sc, a)
      if (r) {
        let st = r.state, clock = r.clock
        if (screen?.startsWith('welcome')) st = { ...st, welcomed: false }
        if (screen === 'checkin-morning' || screen === 'checkin-evening') {
          const morning = screen === 'checkin-morning'
          clock = midnight(clock) + (morning ? 8.33 : 21.17) * 36e5
          const k = dayKey(clock)
          st = { ...st, logs: st.logs.filter((l) => l.at <= clock), checkins: st.checkins.filter((c) => c.date !== k || (!morning && c.kind === 'morning')) }
        }
        setClock(clock)
        return { state: st, persist: false }
      }
    }
    return { state: load() ?? freshState(a), persist: true }
  })
  return <AppShell initial={boot.state} persist={boot.persist} screen={screen} tab={(qs.get('tab') as Tab) ?? 'today'} />
}

function AppShell({ initial, persist, screen, tab: tab0 }: { initial: AppState; persist: boolean; screen?: string; tab: Tab }) {
  const [s, setS] = useState(initial)
  const [, setTick] = useState(0)
  const [tab, setTab] = useState<Tab>(tab0)
  const [overlay, setOverlay] = useState<Overlay | null>(() => {
    if (screen && SCREEN_OVERLAY[screen]) return SCREEN_OVERLAY[screen]
    if (screen) return null
    const d = derive(initial)
    if (!initial.welcomed) return { kind: 'welcome', step: 1 }
    if (d.free && !initial.quitSeen) return { kind: 'quitday' }
    if (d.reviewWeek !== undefined) return { kind: 'review' }
    return null
  })
  const [toastMsg, setToast] = useState<{ text: string; undo?: () => void; id: number } | null>(null)
  const [banner, setBanner] = useState<string | null>(null)
  const toastTimer = useRef(0)

  useEffect(() => { const id = setInterval(() => setTick((x) => x + 1), 15000); return () => clearInterval(id) }, [])
  useEffect(() => { if (persist) save(s) }, [s, persist])

  const d = derive(s)
  const update = (f: (x: AppState) => AppState) => setS(f)

  const toast = (text: string, undo?: () => void) => {
    clearTimeout(toastTimer.current)
    setToast({ text, undo, id: Date.now() })
    toastTimer.current = window.setTimeout(() => setToast(null), 5000)
  }

  const nav: Nav = {
    tab, setTab: (t) => { haptic(6); setTab(t) },
    open: setOverlay,
    toast,
    askPermission: () => setOverlay({ kind: 'permission' }),
    logHit: (source = 'app') => {
      haptic(18)
      const id = uid()
      const before = d.budget ? d.used / d.budget : 1
      const after = d.budget ? (d.used + 1) / d.budget : 1
      setS((x) => ({ ...x, logs: [...x.logs, { id, at: now(), source }] }))
      toast(`Logged · ${d.left - 1 >= 0 ? `${d.left - 1} left` : `${d.over + 1} over`}`, () => setS((x) => ({ ...x, logs: x.logs.filter((l) => l.id !== id) })))
      const heads = s.notifs.find((n) => n.id === 'heads')
      if (before < 0.8 && after >= 0.8 && after <= 1 && d.budget > 0 && s.notifsAllowed && heads?.on) {
        setTimeout(() => setBanner(`You've used ${Math.round(after * 100)}% of today's budget. ${d.left - 1} left. Spread them out.`), 700)
        setTimeout(() => setBanner(null), 5200)
      }
    },
  }

  // earned celebrations show one at a time, only when nothing else is on screen
  const pending = useMemo(() => earned(s, d), [s, d.t])
  const celebrate = !overlay && !screen ? pending[0] : undefined

  return (
    <StoreCtx.Provider value={{ s, d, update, haptic }}>
      <StatusBar time={clockStr(d.t)} />
      <div className="app">
        <div className="app-scroll" key={tab}>
          {tab === 'today' && <Today nav={nav} focus={screen?.startsWith('checkin') ? 'checkin' : undefined} />}
          {tab === 'plan' && <Plan nav={nav} />}
          {tab === 'you' && <You nav={nav} />}
        </div>
        <button className="sos-pill" onClick={() => { haptic(20); setOverlay({ kind: 'sos', step: 'interrupt' }) }}>
          <Icon name="wind" size={19} /> SOS
        </button>
        <nav className="tabbar">
          {(['today', 'plan', 'you'] as Tab[]).map((t) => (
            <button key={t} className={`tab ${tab === t ? 'on' : ''}`} onClick={() => nav.setTab(t)}>
              <Icon name={t === 'plan' ? 'chart' : t} size={23} />
              <span>{t === 'today' ? 'Today' : t === 'plan' ? 'Plan' : 'You'}</span>
            </button>
          ))}
        </nav>
        {toastMsg && (
          <div className="toast" key={toastMsg.id}>
            <span>{toastMsg.text}</span>
            {toastMsg.undo && <button onClick={() => { toastMsg.undo!(); setToast(null); haptic(8) }}>Undo</button>}
          </div>
        )}
        {banner && (
          <div className="ios-banner" onClick={() => setBanner(null)}>
            <div className="notif-app">{APP_NAME.slice(0, 1)}</div>
            <div><div className="notif-h"><b>{APP_NAME}</b><span className="muted">now</span></div><div className="notif-b">{banner}</div></div>
          </div>
        )}
        {celebrate && (
          <div className="celebrate-dim">
            <Confetti top={250} />
            <div className="celebrate">
              <div className="cel-badge"><Icon name="star" size={26} /></div>
              <div className="cel-t">{celebrate.title}</div>
              <div className="cel-s">{celebrate.sub}</div>
              <button className="cta cta-primary" onClick={() => setS((x) => ({ ...x, celebrated: [...x.celebrated, celebrate.key] }))}>Nice</button>
            </div>
          </div>
        )}
        <div id="app-layer" />
        {overlay?.kind === 'welcome' && <Welcome step={overlay.step} nav={nav} />}
        {overlay?.kind === 'sos' && <Sos step={overlay.step} nav={nav} />}
        {overlay?.kind === 'review' && <Review nav={nav} />}
        {overlay?.kind === 'quitday' && <QuitDay nav={nav} />}
        {overlay?.kind === 'widgetguide' && <WidgetGuide nav={nav} />}
        {overlay?.kind === 'permission' && (
          <div className="sys-dim">
            <div className="sys-alert">
              <div className="sys-t">"{APP_NAME}" Would Like to Send You Notifications</div>
              <div className="sys-b">Notifications may include alerts, sounds, and icon badges. These can be configured in Settings.</div>
              <div className="sys-btns">
                <button onClick={() => setOverlay(null)}>Don't Allow</button>
                <button onClick={() => { setS((x) => ({ ...x, notifsAllowed: true, setup: { ...x.setup, checkins: true } })); setOverlay(null); toast('Check-ins are on') }}><b>Allow</b></button>
              </div>
            </div>
          </div>
        )}
      </div>
    </StoreCtx.Provider>
  )
}

export function eraseAndRestart() { erase(); location.href = location.pathname }
