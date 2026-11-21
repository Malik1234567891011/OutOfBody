import { useMemo, useState } from 'react'
import type { Answers } from './calc'
import { buildFlow } from './screens'
import { PaywallP1, PaywallP2, PaywallP3 } from './paywall'
import { StatusBar } from './ui'
import { PRESETS } from './presets'
import { AppRoot } from './app/AppShell'
import { SCENARIOS } from './app/scenarios'

const PW = ['pw1', 'pw2', 'pw3']

export default function App() {
  const qs = new URLSearchParams(location.search)
  const preset = qs.get('preset')
  const [a, setA] = useState<Answers>(preset ? PRESETS[preset] ?? {} : {})
  const flow = useMemo(() => buildFlow(a), [a])
  const ids = [...flow.map((s) => s.id), ...PW]
  const startId = qs.get('s')
  const [idx, setIdx] = useState(() => {
    if (!startId) return 0
    const i = ids.indexOf(startId)
    return i >= 0 ? i : Number(startId) || 0
  })
  const [dir, setDir] = useState(1)
  const [done, setDone] = useState(false)
  const appMode = qs.has('app') || done

  const go = (n: number) => { setDir(n > idx ? 1 : -1); setIdx(Math.max(0, Math.min(ids.length - 1, n))) }
  const next = () => go(idx + 1)
  const back = idx > 0 ? () => go(idx - 1) : undefined
  const set = (p: Partial<Answers>) => setA((x) => ({ ...x, ...p }))

  const id = ids[idx]
  const scored = flow.filter((s) => s.id !== 'welcome')
  const pos = scored.findIndex((s) => s.id === id)
  const progress = pos >= 0 ? (pos + 1) / scored.length : undefined

  if (appMode) {
    const answers = preset || done ? a : PRESETS.disposable
    const pick = (sc: string) => { const q = new URLSearchParams(location.search); q.set('app', '1'); if (sc) q.set('scenario', sc); else q.delete('scenario'); q.delete('screen'); location.search = q.toString() }
    return (
      <div className="stage">
        <div className="device">
          <AppRoot a={answers} fromPurchase={done} />
          <div className="home-ind" />
        </div>
        {!qs.has('bare') && (
          <div className="devnav">
            <span>app</span>
            <select value={qs.get('scenario') ?? ''} onChange={(e) => pick(e.target.value)}>
              <option value="">my data</option>
              {SCENARIOS.map((x) => <option key={x}>{x}</option>)}
            </select>
            <button onClick={() => { location.href = location.pathname }}>Onboarding</button>
          </div>
        )}
      </div>
    )
  }

  let body
  if (id === 'pw1') body = <PaywallP1 a={a} next={next} close={() => go(ids.indexOf('pw3'))} />
  else if (id === 'pw2') body = <PaywallP2 next={next} back={() => go(idx - 1)} />
  else if (id === 'pw3') body = <PaywallP3 a={a} back={() => go(idx - 1)} close={() => setDone(true)} buy={() => setDone(true)} />
  else body = flow[idx].render({ a, set, next, back, progress })

  return (
    <div className="stage">
      <div className="device">
        <StatusBar />
        <div key={id + (done ? 'd' : '')} className={`slide ${dir > 0 ? 'in-r' : 'in-l'}`}>{body}</div>
        <div className="home-ind" />
      </div>
      {!qs.has('bare') && (
        <div className="devnav">
          <span>{idx + 1}/{ids.length} · {id}</span>
          <select value={id} onChange={(e) => go(ids.indexOf(e.target.value))}>{ids.map((x) => <option key={x}>{x}</option>)}</select>
          <button onClick={() => { setA({}); go(0); setDone(false) }}>Restart</button>
        </div>
      )}
    </div>
  )
}
