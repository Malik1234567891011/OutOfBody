import { useState } from 'react'
import { APP_NAME, Icon, isStill } from '../ui'
import { useStore, dayKey, unitWord } from './store'
import { Confetti, Sheet, Ring, haptic } from './bits'
import type { Nav } from './AppShell'

export function Welcome({ step: step0, nav }: { step: number; nav: Nav }) {
  const { s, d, update } = useStore()
  const [step, setStep] = useState(step0)
  const [guide, setGuide] = useState(false)
  const next = () => { haptic(8); setStep((x) => x + 1) }
  const name = s.answers.name

  if (guide) return <WidgetGuide nav={nav} onDone={() => { setGuide(false); setStep(5) }} />

  const dots = step > 1 && <div className="w-dots">{[2, 3, 4, 5].map((i) => <i key={i} className={i === step ? 'on' : i < step ? 'past' : ''} />)}</div>

  return (
    <Sheet className="welcome-sheet">
      <div key={step} className="w-step in-r">
        {step === 1 && <>
          <Confetti top={222} n={44} spread={0.75} around />
          <div className="breath-orb small" style={{ top: 222 }} />
          <div className="w-center">
            <div className="ready-check big"><Icon name="check" size={44} /></div>
            <h1 className="hero w-h1">You're in{name ? `, ${name}` : ''}.</h1>
            <p className="sub center">Your plan starts today. Here's how it works.</p>
          </div>
        </>}
        {step === 2 && <>
          {dots}
          <h1 className="title w-title">How a day works</h1>
          <div className="w-rows">
            <WRow n={1} icon="plus" t={`Tap every time you pick it up`} d="From the lock screen widget or the app. One tap, no unlocking." />
            <WRow n={2} icon="today" t="Stay under today's budget" d={`It starts at ${d.budget} ${unitWord(d, d.budget)} and gets smaller every week.`} />
            <WRow n={3} icon="wind" t="Hit SOS when a craving hits" d="Breathe with us for 90 seconds. Most cravings pass in minutes." danger />
          </div>
        </>}
        {step === 3 && <>
          {dots}
          <h1 className="title w-title">Some days will be easy. Some won't.</h1>
          <p className="sub w-sub">Going over isn't failure; it's data. We adjust, you keep going.</p>
          <Bumps budget={d.budget} />
        </>}
        {step === 4 && <>
          {dots}
          <h1 className="title w-title">Add the widget. It's the whole habit.</h1>
          <p className="sub w-sub">Seeing the number every time you pick up your phone is half the work.</p>
          <LockAnim />
        </>}
        {step === 5 && <>
          {dots}
          <div className="w-center w5">
            <p className="eyebrow center">Day 1 · your first commitment</p>
            <h1 className="title center">Today's budget</h1>
            <Ring size={210} stroke={16} frac={1} color="var(--accent)" glow>
              <div className="ring-num">{d.budget}</div>
              <div className="ring-l">{unitWord(d, d.budget)} today</div>
            </Ring>
            <p className="sub center" style={{ maxWidth: 300 }}>Down from about {d.startAmt} a day. Log each one and stay under it. That's all today asks.</p>
          </div>
        </>}
      </div>
      <div className="sheet-bottom">
        {step < 4 && <button className="cta cta-primary" onClick={next}>Continue</button>}
        {step === 4 && <>
          <button className="cta cta-primary" onClick={() => setGuide(true)}>Show me how</button>
          <button className="link" onClick={next}>I'll do it later</button>
        </>}
        {step === 5 && <button className="cta cta-primary" onClick={() => {
          haptic(24)
          update((x) => ({ ...x, welcomed: true, checkins: [...x.checkins.filter((c) => !(c.date === dayKey(d.t) && c.kind === 'morning')), { date: dayKey(d.t), kind: 'morning' }] }))
          nav.open(null)
        }}>I'm in for today</button>}
      </div>
    </Sheet>
  )
}

const WRow = ({ n, icon, t, d, danger }: { n: number; icon: string; t: string; d: string; danger?: boolean }) => (
  <div className="w-row">
    <div className={`w-ic ${danger ? 'danger' : ''}`}><Icon name={icon} size={22} /><span>{n}</span></div>
    <div><div className="w-rt">{t}</div><div className="w-rd">{d}</div></div>
  </div>
)

// A week that wobbles but trends down; two days go over the line, and that's fine.
function Bumps({ budget }: { budget: number }) {
  const vals = [0.92, 1.12, 0.85, 0.95, 1.18, 0.8, 0.74]
  const max = 1.3, H = 170, Wd = 320
  return (
    <div className="card bumps">
      <svg viewBox={`0 0 ${Wd} ${H + 26}`} width="100%">
        <line x1="0" x2={Wd} y1={H - (1 / max) * H} y2={H - (1 / max) * H} stroke="var(--muted)" strokeDasharray="5 5" strokeWidth="1.5" />
        <text x={Wd} y={H - (1 / max) * H - 8} textAnchor="end" className="bump-l">budget {budget}</text>
        {vals.map((v, i) => {
          const x = 14 + i * ((Wd - 28) / 6), h = (v / max) * H
          return <g key={i}>
            <rect x={x - 15} y={H - h} width="30" height={h} rx="8" fill={v > 1 ? 'var(--warn)' : 'var(--accent)'} opacity={v > 1 ? 0.9 : 0.85} />
            <text x={x} y={H + 20} textAnchor="middle" className="bump-x">{['M', 'T', 'W', 'T', 'F', 'S', 'S'][i]}</text>
          </g>
        })}
      </svg>
      <div className="legend"><span><i style={{ background: 'var(--accent)' }} />Under</span><span><i style={{ background: 'var(--warn)' }} />Over: still a good week</span></div>
    </div>
  )
}

function WidgetDemo({ left = 14 }: { left?: number }) {
  return (
    <div className="lw-rect">
      <Ring size={40} stroke={5} frac={0.6} color="#fff" track="rgba(255,255,255,.25)"><span className="lwr-n">{left}</span></Ring>
      <div><div className="lwr-k">{left} left</div><div className="lwr-l">tap to log</div></div>
    </div>
  )
}

function LockAnim() {
  return (
    <div className={`lock-anim ${isStill() ? 'still' : ''}`}>
      <div className="la-screen">
        <div className="lock-date">{new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })}</div>
        <div className="lock-time">9:41</div>
        <div className="la-slot"><div className="la-widget"><WidgetDemo /></div></div>
        <div className="la-press" />
      </div>
      <div className="la-customize">Customize</div>
      <div className="la-caption">
        <span className="c1">Long-press</span><span className="c2">Customize</span><span className="c3">Add {APP_NAME}</span>
      </div>
    </div>
  )
}

export function WidgetGuide({ nav, onDone }: { nav: Nav; onDone?: () => void }) {
  const { d, update } = useStore()
  const done = () => { update((x) => ({ ...x, setup: { ...x.setup, widget: true } })); haptic(14); if (onDone) onDone(); else { nav.open(null); nav.toast('Widget added. Tap it each time.') } }
  return (
    <Sheet className="guide-sheet" onClose={onDone ? undefined : () => nav.open(null)}>
      <div className="guide-scroll">
        <p className="eyebrow">Lock-screen widget</p>
        <h1 className="title">Three taps to set it up</h1>
        <div className="guide-steps">
          <GStep n={1} t="Long-press your lock screen" d="Unlock with Face ID first, but stay on the lock screen." />
          <GStep n={2} t="Tap Customize, then Lock Screen" d="Then tap the box under the clock." />
          <GStep n={3} t={`Pick ${APP_NAME}`} d="Choose the ring or the “left · tap to log” widget." />
        </div>
        <div className="guide-preview">
          <div className="gp-lock">
            <div className="gp-time">9:41</div>
            <div className="gp-row">
              <div className="gp-circ"><Ring size={52} stroke={6} frac={0.6} color="#fff" track="rgba(255,255,255,.25)"><span className="lwr-n">14</span></Ring></div>
              <WidgetDemo />
            </div>
          </div>
          <p className="fine center">Tapping it logs a {d.one}. No unlocking, no app to open.</p>
        </div>
      </div>
      <div className="sheet-bottom">
        <button className="cta cta-primary" onClick={done}>I added it</button>
        {onDone && <button className="link" onClick={onDone}>Skip for now</button>}
      </div>
    </Sheet>
  )
}
const GStep = ({ n, t, d }: { n: number; t: string; d: string }) => (
  <div className="g-step"><span className="g-n">{n}</span><div><div className="g-t">{t}</div><div className="g-d">{d}</div></div></div>
)
