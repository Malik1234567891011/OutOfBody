import { useEffect, useRef, useState } from 'react'
import { fmtDate } from '../calc'
import { Icon, isStill } from '../ui'
import { useStore, uid, now } from './store'
import { Ring, Confetti, Sheet, Signature, haptic } from './bits'
import type { Nav } from './AppShell'

export type SosStep = 'interrupt' | 'breathe' | 'pass' | 'notyet' | 'win' | 'reasons' | 'myreasons' | 'anyway'

const TOTAL = 90
const SKIP_AFTER = 20
// in 4 · hold 4 · out 6
function phaseAt(t: number) {
  const p = t % 14
  if (p < 4) return { ph: 'in' as const, left: 4 - p, label: 'Breathe in' }
  if (p < 8) return { ph: 'hold' as const, left: 8 - p, label: 'Hold' }
  return { ph: 'out' as const, left: 14 - p, label: 'Breathe out' }
}

export function Sos({ step: step0, nav }: { step: SosStep; nav: Nav }) {
  const { s, d, update } = useStore()
  const [step, setStep] = useState<SosStep>(step0)
  const [method, setMethod] = useState<'breathe' | 'reasons'>(step0 === 'reasons' ? 'reasons' : 'breathe')
  const [round, setRound] = useState(0)
  const close = () => nav.open(null)
  const markTried = () => update((x) => (x.setup.sos ? x : { ...x, setup: { ...x.setup, sos: true } }))
  const reason = s.reasons[0] ?? 'Get my day back'

  if (step === 'interrupt') return (
    <Sheet className="sos-sheet" onClose={close} tone="calm">
      <div className="sos-glow" />
      <div className="sos-body">
        <p className="eyebrow center">Craving SOS</p>
        <h1 className="sos-h">Breathe. This craving will pass in a few minutes.</h1>
        <div className="sos-reason">
          <div className="sr-k">Your #1 reason</div>
          <div className="sr-v">"{reason}"</div>
        </div>
      </div>
      <div className="sheet-bottom">
        <button className="cta cta-primary" onClick={() => { haptic(14); setMethod('breathe'); setStep('breathe') }}>Breathe with me</button>
        <button className="cta cta-ghost2" onClick={() => { setMethod('reasons'); setStep('reasons') }}>Read my reasons</button>
        <button className="link" onClick={() => setStep('anyway')}>I'm going to vape anyway</button>
      </div>
    </Sheet>
  )

  if (step === 'breathe') return <Breathe key={round} onDone={() => { markTried(); setStep('pass') }} onClose={close} />

  if (step === 'pass') return (
    <Sheet className="sos-sheet" onClose={close} tone="calm">
      <div className="sos-glow" />
      <div className="sos-body mid">
        <div className="pass-orb"><Icon name="wind" size={40} /></div>
        <h1 className="sos-h center">Did it pass?</h1>
        <p className="sub center">Be honest. Either answer is fine.</p>
      </div>
      <div className="sheet-bottom">
        <button className="cta cta-primary" onClick={() => {
          haptic(30); markTried()
          update((x) => ({ ...x, cravings: [...x.cravings, { id: uid(), at: now(), outcome: 'beaten', method }] }))
          setStep('win')
        }}>Yes, it passed</button>
        <button className="cta cta-ghost2" onClick={() => setStep('notyet')}>Not yet</button>
      </div>
    </Sheet>
  )

  if (step === 'notyet') return (
    <Sheet className="sos-sheet" onClose={close} tone="calm">
      <div className="sos-glow" />
      <div className="sos-body mid">
        <h1 className="sos-h center">That's okay.<br />Cravings come in waves.</h1>
        <p className="sub center">The next wave is usually smaller. Stay with it a little longer.</p>
      </div>
      <div className="sheet-bottom">
        <button className="cta cta-primary" onClick={() => { setMethod('breathe'); setRound((r) => r + 1); setStep('breathe') }}>Another round</button>
        <button className="cta cta-ghost2" onClick={() => { setMethod('reasons'); setStep('reasons') }}>Read my reasons</button>
        <button className="link" onClick={() => setStep('anyway')}>I'm going to vape anyway</button>
      </div>
    </Sheet>
  )

  if (step === 'win') {
    const n = d.beaten
    return (
      <Sheet className="sos-sheet win" tone="calm">
        <Confetti top={230} />
        <div className="sos-body mid">
          <div className="win-badge"><Icon name="check" size={40} /></div>
          <h1 className="sos-h center">Craving beaten.<br />That's {n}.</h1>
          <p className="sub center">{n === 1 ? 'Your first one. Now you know it passes.' : n % 10 === 0 ? `${n} times you rode it out. That's a pattern now.` : 'It passed, like they do. That one counts.'}</p>
        </div>
        <div className="sheet-bottom"><button className="cta cta-primary" onClick={close}>Back to today</button></div>
      </Sheet>
    )
  }

  if (step === 'reasons' || step === 'myreasons') return <Reasons sos={step === 'reasons'} onPass={() => setStep('pass')} onClose={close} />

  // anyway: harm reduction, no shame
  return (
    <Sheet className="sos-sheet" onClose={close} tone="calm">
      <div className="sos-body mid">
        <div className="pass-orb soft"><Icon name="heart" size={36} /></div>
        <h1 className="sos-h center">Okay. Make it a small one.</h1>
        <p className="sub center">Log it so the plan stays honest. One {d.one} doesn't undo your progress.</p>
      </div>
      <div className="sheet-bottom">
        <button className="cta cta-primary" onClick={() => {
          markTried()
          update((x) => ({ ...x, cravings: [...x.cravings, { id: uid(), at: now(), outcome: 'gaveIn', method }] }))
          nav.logHit('sos'); close()
        }}>Log 1 {d.one}</button>
        <button className="link" onClick={() => { setMethod('breathe'); setStep('breathe') }}>Actually, breathe with me first</button>
      </div>
    </Sheet>
  )
}

function Breathe({ onDone, onClose }: { onDone: () => void; onClose: () => void }) {
  const still = isStill()
  const [t, setT] = useState(still ? 33.4 : 0)
  const t0 = useRef(performance.now())
  const last = useRef('')
  useEffect(() => {
    if (still) return
    let raf = 0
    const tick = () => {
      const e = (performance.now() - t0.current) / 1000
      if (e >= TOTAL) { onDone(); return }
      setT(e)
      raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [])
  const { ph, left, label } = phaseAt(t)
  useEffect(() => { if (last.current && last.current !== ph) haptic(ph === 'hold' ? 6 : 14); last.current = ph }, [ph])
  const p = t % 14
  // orb size follows the breath: grows on in, holds, shrinks on out
  const scale = ph === 'in' ? 0.72 + 0.38 * ease(p / 4) : ph === 'hold' ? 1.1 : 1.1 - 0.38 * ease((p - 8) / 6)
  const remain = Math.ceil(TOTAL - t)
  return (
    <Sheet className="sos-sheet breathe" onClose={onClose} tone="calm">
      <div className="br-top">
        <p className="eyebrow center">Breathe with me</p>
        <p className="br-sub">In through your nose, out slowly through your mouth.</p>
      </div>
      <div className="br-stage">
        <Ring size={316} stroke={5} frac={(TOTAL - t) / TOTAL} color="rgba(79,227,184,.75)" track="rgba(255,255,255,.06)">
          <div className={`br-orb ${ph}`} style={{ transform: `scale(${scale})` }} />
          <div className="br-label">
            <div className="br-ph">{label}</div>
            <div className="br-n">{Math.ceil(left)}</div>
          </div>
        </Ring>
      </div>
      <div className="br-steps">
        {(['in', 'hold', 'out'] as const).map((x) => <span key={x} className={x === ph ? 'on' : ''}>{x === 'in' ? 'In 4' : x === 'hold' ? 'Hold 4' : 'Out 6'}</span>)}
      </div>
      <div className="sheet-bottom">
        <div className="br-time">{Math.floor(remain / 60)}:{String(remain % 60).padStart(2, '0')} left</div>
        <button className={`link br-skip ${t >= SKIP_AFTER ? '' : 'hidden'}`} disabled={t < SKIP_AFTER} onClick={onDone}>Skip to the end</button>
      </div>
    </Sheet>
  )
}
const ease = (x: number) => 0.5 - Math.cos(Math.PI * Math.max(0, Math.min(1, x))) / 2

export function Reasons({ sos, onPass, onClose }: { sos: boolean; onPass?: () => void; onClose: () => void }) {
  const { s, update } = useStore()
  useEffect(() => { update((x) => (x.setup.reasons ? x : { ...x, setup: { ...x.setup, reasons: true } })) }, [])
  return (
    <Sheet className="sos-sheet reasons-sheet" onClose={onClose}>
      <div className="rs-scroll">
        <p className="eyebrow">Why you're doing this</p>
        <h1 className="title" style={{ marginBottom: 18 }}>Your reasons</h1>
        <div className="rs-list">
          {s.reasons.map((r, i) => (
            <div className="rs-item" key={r}><span className="rs-n">{i + 1}</span><span>{r}</span></div>
          ))}
          {!s.reasons.length && <p className="sub">Add your reasons in the You tab.</p>}
        </div>
        <div className="pledge-card">
          <p className="pc-t">"I{s.answers.name ? `, ${s.answers.name},` : ''} am done letting nicotine run my day. I'll follow my plan and be nicotine-free."</p>
          <div className="pc-sig"><Signature src={s.signature ?? s.answers.signature} name={s.answers.name} /></div>
          <div className="pc-date">You signed this {fmtDate(new Date(s.start))}</div>
        </div>
      </div>
      <div className="sheet-bottom">
        {sos ? <button className="cta cta-primary" onClick={onPass}>Did it pass?</button> : <button className="cta cta-primary" onClick={onClose}>Done</button>}
      </div>
    </Sheet>
  )
}
