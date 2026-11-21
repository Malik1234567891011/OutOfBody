import { useMemo, useState } from 'react'
import type { Answers } from './calc'
import { buildFlow } from './screens'
import { PaywallP1, PaywallP2, PaywallP3 } from './paywall'
import { StatusBar } from './ui'

// Presets let screenshots jump straight to any screen with realistic answers.
const PRESETS: Record<string, Answers> = {
  disposable: { device: 'disposable', duration: '1to3y', dispSize: 6000, dispDays: 5, strength: 50, hitsPerDay: 30, firstHit: '5to30', triggers: ['meals', 'stress', 'bored'], weeklySpend: 22, tried: 'few', hardParts: ['cravings', 'irritable'], reasons: ['money', 'breathe', 'control'], name: 'Malik', age: '18–24' },
  pod: { device: 'pod', duration: '3to5y', podsPerDay: 1, strength: 50, hitsPerDay: 50, firstHit: 'lt5', triggers: ['wake', 'drive', 'work'], weeklySpend: 40, tried: 'once', hardParts: ['stress'], reasons: ['health', 'fit'], name: 'Sam', age: '25–34' },
  pouch: { device: 'pouch', duration: '1to3y', pouchesPerDay: 12, pouchMg: 6, firstHit: '5to30', triggers: ['work', 'meals'], weeklySpend: 40, tried: 'never', reasons: ['money', 'anxiety'], name: 'Jordan', age: '25–34' },
  combo: { device: 'combo', duration: '3to5y', dispSize: 6000, dispDays: 5, strength: 50, pouchesPerDay: 7, pouchMg: 6, hitsPerDay: 30, firstHit: 'lt5', triggers: ['wake', 'stress', 'drink'], weeklySpend: 62, tried: 'lost', hardParts: ['cravings', 'friends'], reasons: ['control', 'money'], name: 'Alex', age: '18–24' },
}

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

  const go = (n: number) => { setDir(n > idx ? 1 : -1); setIdx(Math.max(0, Math.min(ids.length - 1, n))) }
  const next = () => go(idx + 1)
  const back = idx > 0 ? () => go(idx - 1) : undefined
  const set = (p: Partial<Answers>) => setA((x) => ({ ...x, ...p }))

  const id = ids[idx]
  const scored = flow.filter((s) => s.id !== 'welcome')
  const pos = scored.findIndex((s) => s.id === id)
  const progress = pos >= 0 ? (pos + 1) / scored.length : undefined

  let body
  if (done) body = <div className="screen"><div className="center-stack" style={{ marginTop: 260 }}><h1 className="title center">Welcome in.</h1><p className="sub center">(Prototype ends here. The real app opens on your plan.)</p></div></div>
  else if (id === 'pw1') body = <PaywallP1 a={a} next={next} close={() => go(ids.indexOf('pw3'))} />
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
