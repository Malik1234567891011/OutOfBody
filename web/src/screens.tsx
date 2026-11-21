import { useEffect, useRef, useState, type ReactNode } from 'react'
import {
  type Answers, usesVape, usesPouch, nicotineMgPerDay, packsPerDay, cigsPerDay, yearlySpend,
  dependence, recommendedWeeks, plan, quitDate, fmtDate, money, budgetUnit, startAmount, savedByQuit,
} from './calc'
import { APP_NAME, Icon, TopBar, Title, Options, CTA, Bottom, type Opt, useCountUp, isStill } from './ui'

export interface Ctx {
  a: Answers
  set: (p: Partial<Answers>) => void
  next: () => void
  back?: () => void
  progress?: number
}

export interface Screen { id: string; quiz?: boolean; render: (c: Ctx) => ReactNode }

// ---------- generic question screen ----------
function Single({ c, title, sub, field, opts }: { c: Ctx; title: ReactNode; sub?: ReactNode; field: keyof Answers; opts: (Opt & { value?: unknown })[] }) {
  const cur = c.a[field]
  const pick = (id: string) => {
    const o = opts.find((x) => x.id === id)!
    c.set({ [field]: o.value ?? id } as Partial<Answers>)
    setTimeout(c.next, 260)
  }
  const value = opts.find((o) => (o.value ?? o.id) === cur)?.id
  return (
    <div className="screen">
      <TopBar progress={c.progress} onBack={c.back} />
      <Title sub={sub}>{title}</Title>
      <Options opts={opts} value={value} onPick={pick} />
    </div>
  )
}

function Multi({ c, title, sub, field, opts, cta = 'Continue' }: { c: Ctx; title: ReactNode; sub?: ReactNode; field: 'triggers' | 'hardParts' | 'reasons'; opts: Opt[]; cta?: string }) {
  const cur = (c.a[field] as string[] | undefined) ?? []
  const toggle = (id: string) => c.set({ [field]: cur.includes(id) ? cur.filter((x) => x !== id) : [...cur, id] })
  return (
    <div className="screen">
      <TopBar progress={c.progress} onBack={c.back} />
      <Title sub={sub ?? 'Pick all that apply.'}>{title}</Title>
      <div className="scroll"><Options opts={opts} value={cur} onPick={toggle} multi /></div>
      <Bottom><CTA disabled={!cur.length} onClick={c.next}>{cta}</CTA></Bottom>
    </div>
  )
}

const what = (a: Answers) => (a.device === 'pouch' ? 'pouches' : a.device === 'combo' ? 'nicotine' : 'vape')

// ---------- 1. welcome ----------
function Welcome({ c }: { c: Ctx }) {
  return (
    <div className="screen welcome">
      <div className="welcome-mark">{APP_NAME.toLowerCase()}</div>
      <div className="breath-orb" />
      <img src="/img/lungs-after.jpg" alt="" className="welcome-lungs" />
      <div className="welcome-body">
        <h1 className="hero">Get nicotine<br />out of your body.</h1>
        <p className="sub center">Answer a few quick questions. We'll show you what your vape is really doing, then step you down to zero.</p>
      </div>
      <Bottom>
        <CTA onClick={c.next}>Start the quiz</CTA>
        <p className="fine center">Takes about a minute · 100% private, no account</p>
      </Bottom>
    </div>
  )
}

// ---------- disposable size + how long it lasts (one screen) ----------
function DisposableQ({ c }: { c: Ctx }) {
  const sizes = [{ v: 800, l: '≤1k' }, { v: 3000, l: '2–4k' }, { v: 6000, l: '5–8k' }, { v: 12000, l: '10k+' }]
  const days = [{ v: 1, l: '1 day' }, { v: 2.5, l: '2–3 days' }, { v: 5, l: '4–6 days' }, { v: 7, l: 'A week' }, { v: 14, l: '2+ weeks' }]
  const ready = c.a.dispSize && c.a.dispDays
  return (
    <div className="screen">
      <TopBar progress={c.progress} onBack={c.back} />
      <Title sub="Two taps. This is how we work out your real nicotine.">Tell us about your disposable</Title>
      <label className="field-l">Puffs on the box</label>
      <div className="seg">
        {sizes.map((x) => <button key={x.v} className={`seg-b ${c.a.dispSize === x.v ? 'on' : ''}`} onClick={() => c.set({ dispSize: x.v })}>{x.l}</button>)}
      </div>
      <label className="field-l" style={{ marginTop: 28 }}>One lasts me about</label>
      <div className="opts">
        {days.map((x) => (
          <button key={x.v} className={`opt ${c.a.dispDays === x.v ? 'opt-on' : ''}`} onClick={() => c.set({ dispDays: x.v })}>
            <span className="opt-text"><span className="opt-label">{x.l}</span></span>
            <span className="opt-mark">{c.a.dispDays === x.v && <Icon name="check" size={14} />}</span>
          </button>
        ))}
      </div>
      <Bottom><CTA disabled={!ready} onClick={c.next}>Continue</CTA></Bottom>
    </div>
  )
}

// ---------- pouch strength + count (one screen) ----------
function PouchQ({ c }: { c: Ctx }) {
  const mgs = [{ v: 3, l: '3 mg' }, { v: 6, l: '6 mg' }, { v: 9, l: '8–10' }, { v: 13, l: '11+ mg' }]
  const counts = [{ v: 3, l: '1–4 a day' }, { v: 7, l: '5–9 a day' }, { v: 12, l: '10–14 a day' }, { v: 18, l: '15 or more a day' }]
  const ready = c.a.pouchMg && c.a.pouchesPerDay
  return (
    <div className="screen">
      <TopBar progress={c.progress} onBack={c.back} />
      <Title sub="Check the can if you're not sure.">Tell us about your pouches</Title>
      <label className="field-l">Strength</label>
      <div className="seg">
        {mgs.map((x) => <button key={x.v} className={`seg-b ${c.a.pouchMg === x.v ? 'on' : ''}`} onClick={() => c.set({ pouchMg: x.v })}>{x.l}</button>)}
      </div>
      <label className="field-l" style={{ marginTop: 28 }}>How many</label>
      <div className="opts">
        {counts.map((x) => (
          <button key={x.v} className={`opt ${c.a.pouchesPerDay === x.v ? 'opt-on' : ''}`} onClick={() => c.set({ pouchesPerDay: x.v })}>
            <span className="opt-text"><span className="opt-label">{x.l}</span></span>
            <span className="opt-mark">{c.a.pouchesPerDay === x.v && <Icon name="check" size={14} />}</span>
          </button>
        ))}
      </div>
      <Bottom><CTA disabled={!ready} onClick={c.next}>Continue</CTA></Bottom>
    </div>
  )
}

// ---------- cost reveal ----------
function CostReveal({ c }: { c: Ctx }) {
  const yr = yearlySpend(c.a)
  const v = useCountUp(yr, 1400)
  return (
    <div className="screen">
      <TopBar progress={c.progress} onBack={c.back} />
      <div className="center-stack">
        <p className="eyebrow danger">At your current pace</p>
        <div className="mega danger">{money(Math.round(v))}</div>
        <p className="mega-sub">a year goes into your {what(c.a)}</p>
        <div className="card cum-card">
          <div className="cum-bars">
            {[1, 2, 3, 5, 10].map((y) => (
              <div key={y} className="cum-col">
                <div className="cum-v">{money(Math.round(yr * y / 100) * 100 >= 10000 ? Math.round(yr * y / 1000) * 1000 : yr * y).replace(/,000$/, 'k')}</div>
                <div className="cum-bar" style={{ height: `${(y / 10) * 120 + 6}px` }} />
                <div className="cum-x">{y} yr</div>
              </div>
            ))}
          </div>
        </div>
        <div className="card list-card" style={{ marginTop: 10 }}>
          <Row l="Every month" r={money(Math.round(yr / 12))} />
          <Row l="Already spent since you started" r={'≈ ' + money(Math.round(yr * durationYears(c.a.duration)))} />
        </div>
      </div>
      <Bottom><CTA onClick={c.next}>I want that money back</CTA></Bottom>
    </div>
  )
}
const durationYears = (d?: string) => ({ lt6m: 0.3, '6to12m': 0.75, '1to3y': 2, '3to5y': 4, '5y': 6 } as Record<string, number>)[d ?? '1to3y'] ?? 2
const Row = ({ l, r }: { l: ReactNode; r: ReactNode }) => (
  <div className="row"><span className="muted">{l}</span><span className="row-r">{r}</span></div>
)

// ---------- reframe after failed attempts ----------
function Reframe({ c }: { c: Ctx }) {
  const tried = c.a.tried !== 'never'
  return (
    <div className="screen">
      <TopBar progress={c.progress} onBack={c.back} />
      <Title sub={tried
        ? 'Going from your usual dose to zero overnight is when cravings, irritability and bad sleep hit hardest. Most people need more than one try. That isn\'t failure, it\'s withdrawal.'
        : 'Going from your usual dose to zero overnight is when cravings, irritability and bad sleep hit hardest. That is why so many first attempts end in a few days.'}>
        {tried ? <>It wasn't a willpower problem.</> : <>Cold turkey is the hard way.</>}
      </Title>
      <div className="card chart-card">
        <TaperCompare />
        <div className="legend">
          <span><i style={{ background: 'var(--danger)' }} />Cold turkey</span>
          <span><i style={{ background: 'var(--accent)' }} />Step-down plan</span>
        </div>
      </div>
      <p className="sub small">This time your body steps down a little each week, so no single day is a cliff.</p>
      <Bottom><CTA onClick={c.next}>That makes sense</CTA></Bottom>
    </div>
  )
}

function TaperCompare() {
  const still = isStill()
  return (
    <svg viewBox="0 0 300 150" className={`taper-svg ${still ? 'still' : ''}`}>
      <text x="4" y="12" className="ax">nicotine</text>
      <text x="262" y="146" className="ax">weeks</text>
      <line x1="4" y1="132" x2="296" y2="132" className="axis" />
      <path className="draw d1" d="M8 30 H70 V128 H292" stroke="var(--danger)" />
      <path className="draw d2" d="M8 30 H70 V54 H120 V78 H170 V100 H220 V118 H270 V128 H292" stroke="var(--accent)" />
      <circle cx="70" cy="128" r="4" fill="var(--danger)" className="pop" />
      <text x="78" y="122" className="lbl danger-t">the crash</text>
    </svg>
  )
}

// ---------- loading / analysis ----------
function Analyzing({ c }: { c: Ctx }) {
  const still = isStill()
  const [pct, setPct] = useState(still ? 100 : 0)
  const steps = [
    `Converting your ${what(c.a)} into cigarettes`,
    'Measuring your dependence',
    'Mapping your trigger moments',
    'Building your step-down plan',
  ]
  useEffect(() => {
    if (still) return
    const id = setInterval(() => setPct((p) => {
      const n = Math.min(100, p + (p < 60 ? 2 : p < 85 ? 1 : 1.5))
      if (n >= 100) { clearInterval(id); setTimeout(c.next, 700) }
      return n
    }), 55)
    return () => clearInterval(id)
  }, [])
  const R = 64, C = 2 * Math.PI * R
  return (
    <div className="screen">
      <div className="center-stack" style={{ marginTop: 90 }}>
        <svg width="170" height="170" viewBox="0 0 170 170">
          <circle cx="85" cy="85" r={R} stroke="var(--line)" strokeWidth="10" fill="none" />
          <circle cx="85" cy="85" r={R} stroke="var(--accent)" strokeWidth="10" fill="none" strokeLinecap="round"
            strokeDasharray={C} strokeDashoffset={C * (1 - pct / 100)} transform="rotate(-90 85 85)" />
          <text x="85" y="96" textAnchor="middle" className="pct">{Math.round(pct)}%</text>
        </svg>
        <h2 className="title" style={{ textAlign: 'center', marginTop: 22 }}>Analyzing your answers</h2>
        <div className="checklist">
          {steps.map((s, i) => {
            const done = pct >= (i + 1) * 25
            const active = !done && pct >= i * 25
            return (
              <div key={s} className={`check-row ${done ? 'done' : ''} ${active ? 'active' : ''}`}>
                <span className="check-dot">{done ? <Icon name="check" size={13} /> : null}</span>{s}
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}

// ---------- results ----------
function Results({ c }: { c: Ctx }) {
  const a = c.a
  const packs = packsPerDay(a)
  const dep = dependence(a)
  const cigs = Math.round(cigsPerDay(a))
  const usePacks = packs >= 1
  const v = useCountUp(usePacks ? packs : cigs, 1300)
  const unit = budgetUnit(a)
  return (
    <div className="screen">
      <TopBar onBack={c.back} />
      <div className="scroll">
        <p className="eyebrow">{a.name ? `${a.name}, here's` : "Here's"} what your {what(a)} really {a.device === 'pouch' ? 'are' : 'is'}</p>
        <div className="result-hero">
          <div className="mega">≈ {usePacks ? v.toFixed(1) : Math.round(v)}</div>
          <div className="mega-sub">{usePacks ? (packs === 1 ? 'pack of cigarettes a day' : 'packs of cigarettes a day') : 'cigarettes a day'}</div>
          <p className="fine">in nicotine, by our estimate</p>
        </div>
        <div className="tiles">
          <Tile k={String(startAmount(a))} l={unit === 'pouches' ? 'pouches a day' : 'hits a day'} />
          <Tile k={`${nicotineMgPerDay(a)} mg`} l="nicotine a day" />
          <Tile k={money(yearlySpend(a))} l="a year" danger />
        </div>
        <div className="card dep-card">
          <div className="row"><span className="muted">Dependence</span><span className={`dep-label lv${dep.level}`}>{dep.label}</span></div>
          <div className="gauge">
            {[0, 1, 2, 3].map((i) => <div key={i} className={`gseg lv${i} ${i <= dep.level ? 'on' : ''}`} />)}
          </div>
          <div className="gauge-l"><span>Low</span><span>Moderate</span><span>High</span><span>Very high</span></div>
          <p className="fine left" style={{ marginTop: 12 }}>
            {a.firstHit === 'lt5' || a.firstHit === '5to30'
              ? 'Reaching for it within 30 minutes of waking is the strongest single sign of nicotine dependence.'
              : 'Your amount per day is the main driver here. Waiting a while after waking is a good sign.'}
          </p>
        </div>
      </div>
      <Bottom><CTA onClick={c.next}>How do I get out?</CTA></Bottom>
    </div>
  )
}
const Tile = ({ k, l, danger }: { k: string; l: string; danger?: boolean }) => (
  <div className="tile"><div className={`tile-k ${danger ? 'danger' : ''}`}>{k}</div><div className="tile-l">{l}</div></div>
)

// ---------- lungs before / after ----------
function Lungs({ c }: { c: Ctx }) {
  const [pos, setPos] = useState(50)
  const ref = useRef<HTMLDivElement>(null)
  const move = (x: number) => {
    const r = ref.current!.getBoundingClientRect()
    setPos(Math.max(4, Math.min(96, ((x - r.left) / r.width) * 100)))
  }
  return (
    <div className="screen">
      <TopBar progress={c.progress} onBack={c.back} />
      <Title sub="Drag to compare.">Your lungs are waiting for you</Title>
      <div className="compare" ref={ref}
        onPointerDown={(e) => { (e.target as HTMLElement).setPointerCapture(e.pointerId); move(e.clientX) }}
        onPointerMove={(e) => e.buttons && move(e.clientX)}>
        <img src="/img/lungs-after.jpg" alt="" className="cmp-img" />
        <img src="/img/lungs-before.jpg" alt="" className="cmp-img" style={{ clipPath: `inset(0 ${100 - pos}% 0 0)` }} />
        <span className="cmp-tag l">Nicotine every day</span>
        <span className="cmp-tag r">Nicotine-free</span>
        <div className="cmp-handle" style={{ left: `${pos}%` }}><span>‹ ›</span></div>
      </div>
      <div className="timeline">
        <TL t="72 hours" d="Nicotine is out of your body" />
        <TL t="2–4 weeks" d="Cravings fade, sleep and mood settle" />
        <TL t="1–3 months" d="Less coughing, easier breathing" />
      </div>
      <Bottom><CTA onClick={c.next}>I want that</CTA></Bottom>
    </div>
  )
}
const TL = ({ t, d }: { t: string; d: string }) => (
  <div className="tl"><span className="tl-dot" /><span className="tl-t">{t}</span><span className="tl-d">{d}</span></div>
)

// ---------- choose quit date ----------
function QuitWhen({ c }: { c: Ctx }) {
  const rec = recommendedWeeks(c.a)
  const mk = (w: number, label: string): Opt => ({
    id: String(w), label, detail: `Nicotine-free by ${fmtDate(quitDate({ ...c.a, weeks: w }))}`, tag: w === rec ? 'Recommended' : undefined,
  })
  return (
    <Single c={c} field="weeks" title="How fast do you want to step down?"
      sub={`Based on your answers we recommend ${rec} weeks.`}
      opts={[mk(2, '2 weeks · fast'), mk(4, '4 weeks · steady'), mk(6, '6 weeks · gentle'), mk(8, '8 weeks · slowest')].map((o) => ({ ...o, value: Number(o.id) }))} />
  )
}

// ---------- plan ----------
function Plan({ c }: { c: Ctx }) {
  const a = c.a
  const steps = plan(a)
  const start = startAmount(a)
  const unit = budgetUnit(a)
  const max = Math.max(start, ...steps)
  const still = isStill()
  return (
    <div className="screen">
      <TopBar progress={c.progress} onBack={c.back} />
      <Title sub={`A daily ${unit === 'pouches' ? 'pouch' : 'hit'} budget that shrinks every week. Stay under it and you're winning.`}>
        Your step-down plan
      </Title>
      <div className="card plan-card">
        <div className="bars">
          <div className="bar-col">
            <div className="bar-val muted">{start}</div>
            <div className="bar now" style={{ height: `${(start / max) * 150}px` }} />
            <div className="bar-x">Now</div>
          </div>
          {steps.map((s, i) => (
            <div className="bar-col" key={i}>
              <div className="bar-val">{s === 0 ? '0' : s}</div>
              <div className={`bar ${s === 0 ? 'zero' : ''} ${still ? '' : 'grow'}`} style={{ height: `${Math.max(6, (s / max) * 150)}px`, animationDelay: `${i * 90}ms` }} />
              <div className="bar-x">W{i + 1}</div>
            </div>
          ))}
        </div>
        <div className="plan-foot">
          <Icon name="spark" size={18} />
          <span>Nicotine-free by <b>{fmtDate(quitDate(a), true)}</b></span>
        </div>
      </div>
      <div className="card list-card">
        <Row l="This week's daily budget" r={`${steps[0]} ${unit}`} />
        <Row l="Kept in your first year" r={money(savedByQuit(a))} />
      </div>
      <Bottom><CTA onClick={c.next}>Continue</CTA></Bottom>
    </div>
  )
}

// ---------- lock screen logging demo ----------
function LockDemo({ c }: { c: Ctx }) {
  const a = c.a
  const budget = plan(a)[0] || 10
  const unit = budgetUnit(a)
  const [used, setUsed] = useState(Math.round(budget * 0.58))
  const [tap, setTap] = useState(false)
  useEffect(() => {
    if (isStill()) return
    const id = setInterval(() => { setTap(true); setUsed((u) => (u + 1 > budget ? Math.round(budget * 0.58) : u + 1)); setTimeout(() => setTap(false), 300) }, 1600)
    return () => clearInterval(id)
  }, [])
  const pct = used / budget
  const R = 22, C = 2 * Math.PI * R
  return (
    <div className="screen">
      <TopBar progress={c.progress} onBack={c.back} />
      <Title sub="Tap the widget each time you hit it. No unlocking, no app to open. Seeing the number is half the work.">Log in one tap, right from your lock screen</Title>
      <div className="lock">
        <div className="lock-date">{new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })}</div>
        <div className="lock-time">9:41</div>
        <div className={`lock-widget ${tap ? 'tapped' : ''}`}>
          <svg width="56" height="56" viewBox="0 0 56 56">
            <circle cx="28" cy="28" r={R} stroke="rgba(255,255,255,.18)" strokeWidth="6" fill="none" />
            <circle cx="28" cy="28" r={R} stroke={pct > 0.9 ? 'var(--warn)' : 'var(--accent)'} strokeWidth="6" fill="none" strokeLinecap="round"
              strokeDasharray={C} strokeDashoffset={C * (1 - Math.min(1, pct))} transform="rotate(-90 28 28)" />
          </svg>
          <div>
            <div className="lw-k">{used} / {budget}</div>
            <div className="lw-l">{unit} today · tap to log</div>
          </div>
          <div className="lw-plus">+</div>
        </div>
        <div className="lock-finger" />
      </div>
      <Bottom><CTA onClick={c.next}>Continue</CTA></Bottom>
    </div>
  )
}

// ---------- craving SOS demo ----------
function SosDemo({ c }: { c: Ctx }) {
  const [phase, setPhase] = useState<'idle' | 'in' | 'out' | 'done'>(isStill() ? 'in' : 'idle')
  const [secs, setSecs] = useState(12)
  useEffect(() => {
    if (phase === 'idle' || phase === 'done' || isStill()) return
    const id = setInterval(() => setSecs((s) => {
      if (s <= 1) { clearInterval(id); setPhase('done'); return 0 }
      if ((s - 1) % 4 === 0) setPhase((p) => (p === 'in' ? 'out' : 'in'))
      return s - 1
    }), 1000)
    return () => clearInterval(id)
  }, [phase === 'idle' || phase === 'done'])
  return (
    <div className="screen">
      <TopBar progress={c.progress} onBack={c.back} />
      <Title sub="A craving peaks and fades within minutes. When one hits, hit SOS and ride it out with us. Try a short one now.">Cravings pass. We'll get you through them.</Title>
      <div className="sos-wrap">
        <button className={`sos-orb ${phase}`} onClick={() => { if (phase === 'idle' || phase === 'done') { setSecs(12); setPhase('in') } }}>
          <span className="sos-text">
            {phase === 'idle' && <>Tap to try</>}
            {phase === 'in' && <>Breathe in</>}
            {phase === 'out' && <>Breathe out</>}
            {phase === 'done' && <>Nice. That's<br />how it works.</>}
          </span>
        </button>
        <p className="fine center" style={{ minHeight: 18 }}>{phase === 'in' || phase === 'out' ? `${secs}s` : ' '}</p>
      </div>
      <Bottom><CTA onClick={c.next}>{phase === 'done' ? 'Continue' : 'Skip'}</CTA></Bottom>
    </div>
  )
}

// ---------- notifications warm-up ----------
const TRIGGERS: Opt[] = [
  { id: 'wake', label: 'Right after waking up' },
  { id: 'meals', label: 'After meals' },
  { id: 'stress', label: 'When stressed or anxious' },
  { id: 'bored', label: 'When bored' },
  { id: 'drive', label: 'Driving or commuting' },
  { id: 'work', label: 'At work or school breaks' },
  { id: 'drink', label: 'Drinking or going out' },
  { id: 'social', label: 'Around friends who vape' },
  { id: 'bed', label: 'Before bed' },
]
function Notify({ c }: { c: Ctx }) {
  const [asked, setAsked] = useState(false)
  const t = (c.a.triggers ?? ['meals', 'stress']).slice(0, 3)
  return (
    <div className="screen">
      <TopBar progress={c.progress} onBack={c.back} />
      <Title sub="We'll check in at the moments you told us are hardest, plus one heads-up each time your budget drops.">We'll show up when it's hardest</Title>
      <div className="notifs">
        {t.map((id, i) => (
          <div className="notif" key={id} style={{ animationDelay: `${i * 160}ms` }}>
            <div className="notif-app">{APP_NAME.slice(0, 1)}</div>
            <div>
              <div className="notif-h"><b>{APP_NAME}</b><span className="muted">now</span></div>
              <div className="notif-b">{NOTIF_COPY[id] ?? 'Craving? Hit SOS. It passes in a few minutes.'}</div>
            </div>
          </div>
        ))}
      </div>
      <Bottom>
        <CTA onClick={() => setAsked(true)}>Turn on check-ins</CTA>
        <button className="link" onClick={c.next}>Not now</button>
      </Bottom>
      {asked && (
        <div className="sys-dim">
          <div className="sys-alert">
            <div className="sys-t">"{APP_NAME}" Would Like to Send You Notifications</div>
            <div className="sys-b">Notifications may include alerts, sounds, and icon badges. These can be configured in Settings.</div>
            <div className="sys-btns"><button onClick={c.next}>Don't Allow</button><button onClick={c.next}><b>Allow</b></button></div>
          </div>
        </div>
      )}
    </div>
  )
}
const NOTIF_COPY: Record<string, string> = {
  wake: 'Morning. Breakfast first, first hit after. You\'ve got this.',
  meals: 'After-meal craving incoming. Walk for 3 minutes before you decide.',
  stress: 'Stressful moment? Hit SOS. It passes in a few minutes.',
  bored: 'Bored hands. Do 10 slow breaths before you reach for it.',
  drive: 'Driving? Leave it in the bag until you park.',
  work: 'Break time. You\'re at 58% of today\'s budget.',
  drink: 'Going out tonight? Decide your budget before the first drink.',
  social: 'Friends vaping? You don\'t have to explain. Just hold off 5 minutes.',
  bed: 'Last one of the night counts too. You\'re under budget today.',
}

// ---------- signature commitment ----------
function Commit({ c }: { c: Ctx }) {
  const cv = useRef<HTMLCanvasElement>(null)
  const [has, setHas] = useState(false)
  const drawing = useRef(false)
  const pos = (e: React.PointerEvent) => {
    const r = cv.current!.getBoundingClientRect()
    return [(e.clientX - r.left) * 2, (e.clientY - r.top) * 2]
  }
  const date = fmtDate(quitDate(c.a), true)
  return (
    <div className="screen">
      <TopBar progress={c.progress} onBack={c.back} />
      <Title sub="People who make a written commitment are more likely to follow through. Sign below.">Make it official</Title>
      <div className="pledge">
        "I{c.a.name ? `, ${c.a.name},` : ''} am done letting nicotine run my day. I'll follow my plan and be nicotine-free by <b>{date}</b>."
      </div>
      <div className="sig-wrap">
        <canvas ref={cv} width={680} height={340} className="sig"
          onPointerDown={(e) => { drawing.current = true; const ctx = cv.current!.getContext('2d')!; const [x, y] = pos(e); ctx.beginPath(); ctx.moveTo(x, y); (e.target as HTMLElement).setPointerCapture(e.pointerId) }}
          onPointerMove={(e) => { if (!drawing.current) return; const ctx = cv.current!.getContext('2d')!; ctx.lineWidth = 6; ctx.lineCap = 'round'; ctx.strokeStyle = '#0B0F17'; const [x, y] = pos(e); ctx.lineTo(x, y); ctx.stroke(); setHas(true) }}
          onPointerUp={() => (drawing.current = false)} />
        {!has && <span className="sig-hint">Sign here with your finger</span>}
        {has && <button className="sig-clear" onClick={() => { cv.current!.getContext('2d')!.clearRect(0, 0, 680, 340); setHas(false) }}>Clear</button>}
      </div>
      <Bottom><CTA disabled={!has} onClick={() => { c.set({ signed: true, signature: cv.current!.toDataURL('image/png') }); c.next() }}>I commit</CTA></Bottom>
    </div>
  )
}

// ---------- ready ----------
function Ready({ c }: { c: Ctx }) {
  const a = c.a
  const reasons = (a.reasons ?? []).map((r) => REASONS.find((x) => x.id === r)?.label).filter(Boolean).slice(0, 3)
  return (
    <div className="screen ready">
      <div className="breath-orb small" />
      <div className="ready-check"><Icon name="check" size={30} /></div>
      <p className="eyebrow center">{a.name ? `${a.name}, your plan is ready` : 'Your plan is ready'}</p>
      <h1 className="title center">You'll be nicotine-free by</h1>
      <div className="date-pill">{fmtDate(quitDate(a), true)}</div>
      <div className="card list-card" style={{ marginTop: 22 }}>
        <Row l="Starting budget" r={`${plan(a)[0]} ${budgetUnit(a)}/day`} />
        <Row l="Steps" r={`${plan(a).length} weekly drops`} />
        <Row l="You'll keep" r={money(yearlySpend(a)) + '/yr'} />
      </div>
      {reasons.length > 0 && (
        <div className="chips">{reasons.map((r) => <span className="chip" key={r}>{r}</span>)}</div>
      )}
      <Bottom><CTA onClick={c.next}>Start my plan</CTA></Bottom>
    </div>
  )
}

// ---------- name + age ----------
function About({ c }: { c: Ctx }) {
  const [name, setName] = useState(c.a.name ?? '')
  const ages = ['18–24', '25–34', '35–44', '45+']
  return (
    <div className="screen">
      <TopBar progress={c.progress} onBack={c.back} />
      <Title sub="So your plan feels like yours.">Last thing. A bit about you</Title>
      <label className="field-l">First name</label>
      <input className="field" placeholder="Your first name" value={name} onChange={(e) => setName(e.target.value)} />
      <label className="field-l" style={{ marginTop: 22 }}>Age</label>
      <div className="seg">
        {ages.map((g) => <button key={g} className={`seg-b ${c.a.age === g ? 'on' : ''}`} onClick={() => c.set({ age: g })}>{g}</button>)}
      </div>
      <Bottom><CTA disabled={!c.a.age} onClick={() => { c.set({ name: name.trim() || undefined }); c.next() }}>See my results</CTA></Bottom>
    </div>
  )
}

export const REASONS: Opt[] = [
  { id: 'money', label: 'Save money' },
  { id: 'breathe', label: 'Breathe easier' },
  { id: 'fit', label: 'Get fitter' },
  { id: 'control', label: 'Stop feeling controlled by it' },
  { id: 'anxiety', label: 'Less anxiety' },
  { id: 'sleep', label: 'Sleep better' },
  { id: 'someone', label: 'For someone in my life' },
  { id: 'health', label: 'Long-term health' },
]

// ---------- the flow ----------
export function buildFlow(a: Answers): Screen[] {
  const s: Screen[] = []
  const add = (x: Screen) => s.push(x)

  add({ id: 'welcome', render: (c) => <Welcome c={c} /> })

  add({ id: 'device', quiz: true, render: (c) => <Single c={c} field="device" title="What do you use?" sub="This sets up how we measure your nicotine."
    opts={[
      { id: 'disposable', label: 'Disposable vape', detail: 'Elf Bar, Lost Mary, Geek Bar…', icon: 'disposable' },
      { id: 'pod', label: 'Pod vape', detail: 'Juul, Vuse, NJOY…', icon: 'pod' },
      { id: 'refill', label: 'Refillable vape', detail: 'You fill it with e-liquid', icon: 'refill' },
      { id: 'pouch', label: 'Nicotine pouches', detail: 'Zyn, Velo, On!…', icon: 'pouch' },
      { id: 'combo', label: 'Vape and pouches', icon: 'combo' },
    ]} /> })

  add({ id: 'duration', quiz: true, render: (c) => <Single c={c} field="duration" title={`How long have you been using ${what(c.a) === 'pouches' ? 'pouches' : 'nicotine'}?`}
    opts={[
      { id: 'lt6m', label: 'Less than 6 months' }, { id: '6to12m', label: '6–12 months' }, { id: '1to3y', label: '1–3 years' },
      { id: '3to5y', label: '3–5 years' }, { id: '5y', label: 'More than 5 years' },
    ]} /> })

  if (usesVape(a)) {
    if (a.device === 'disposable' || a.device === 'combo') {
      add({ id: 'disposable', quiz: true, render: (c) => <DisposableQ c={c} /> })
    }
    if (a.device === 'pod') {
      add({ id: 'pods', quiz: true, render: (c) => <Single c={c} field="podsPerDay" title="How many pods do you go through?"
        opts={[
          { id: 'q', label: 'About one every 3–4 days', value: 0.3 }, { id: 'h', label: 'About one every 2 days', value: 0.5 },
          { id: '1', label: 'About one a day', value: 1 }, { id: '2', label: 'Two a day', value: 2 }, { id: '3', label: 'Three or more a day', value: 3 },
        ]} /> })
    }
    if (a.device === 'refill') {
      add({ id: 'ml', quiz: true, render: (c) => <Single c={c} field="mlPerDay" title="How much e-liquid do you use a day?"
        opts={[
          { id: '1', label: 'About 1 mL', value: 1 }, { id: '3', label: '2–3 mL', value: 2.5 }, { id: '5', label: '4–6 mL', value: 5 }, { id: '8', label: '7 mL or more', value: 8 },
        ]} /> })
    }
    add({ id: 'strength', quiz: true, render: (c) => <Single c={c} field="strength" title="How strong is it?" sub="Check the box or the pod. Most disposables and pods are 5%."
      opts={[
        { id: '50', label: '5% · 50 mg', value: 50 }, { id: '35', label: '3–3.5% · 30–35 mg', value: 33 }, { id: '20', label: '2% · 20 mg', value: 20 },
        { id: '6', label: '1% or less', value: 8 }, { id: 'ns', label: 'Not sure', detail: "We'll assume 5%", value: 49 },
      ]} /> })
  }

  if (usesPouch(a)) {
    add({ id: 'pouches', quiz: true, render: (c) => <PouchQ c={c} /> })
  }

  add({ id: 'firstHit', quiz: true, render: (c) => <Single c={c} field="firstHit"
    title={<>After you wake up, how soon do you reach for it?</>} sub="Be honest. This is the best single measure of dependence."
    opts={[
      { id: 'lt5', label: 'Within 5 minutes' }, { id: '5to30', label: '6–30 minutes' }, { id: '31to60', label: '31–60 minutes' }, { id: 'gt60', label: 'After an hour or more' },
    ]} /> })

  if (usesVape(a)) {
    add({ id: 'hits', quiz: true, render: (c) => <Single c={c} field="hitsPerDay" title="How many times a day do you pick it up?"
      sub="Count each time you reach for it, even for one hit. A rough guess is fine."
      opts={[
        { id: '12', label: '10–20 times', value: 15 }, { id: '30', label: '20–40 times', value: 30 },
        { id: '50', label: '40–60 times', value: 50 }, { id: '75', label: 'Honestly, all day', detail: "It's barely out of my hand", value: 75 },
      ]} /> })
  }

  add({ id: 'triggers', quiz: true, render: (c) => <Multi c={c} field="triggers" title="When do you reach for it most?" opts={TRIGGERS} /> })

  add({ id: 'spend', quiz: true, render: (c) => <Single c={c} field="weeklySpend" title={`How much do you spend on ${what(c.a)} a week?`}
    opts={[
      { id: '10', label: 'Under $15', value: 10 }, { id: '20', label: '$15–30', value: 22 }, { id: '40', label: '$30–50', value: 40 },
      { id: '60', label: '$50–75', value: 62 }, { id: '90', label: 'More than $75', value: 90 },
    ]} /> })

  add({ id: 'cost', quiz: true, render: (c) => <CostReveal c={c} /> })

  add({ id: 'tried', quiz: true, render: (c) => <Single c={c} field="tried" title="Have you tried to quit before?"
    opts={[{ id: 'never', label: 'No, this is my first time' }, { id: 'once', label: 'Once' }, { id: 'few', label: '2–5 times' }, { id: 'lost', label: "I've lost count" }]} /> })

  if (a.tried && a.tried !== 'never') {
    add({ id: 'hard', quiz: true, render: (c) => <Multi c={c} field="hardParts" title="What made it hard?"
      opts={[
        { id: 'cravings', label: 'The cravings' }, { id: 'irritable', label: 'Irritability or anxiety' }, { id: 'stress', label: 'Stress came back' },
        { id: 'friends', label: 'Friends who vape' }, { id: 'bored', label: 'Boredom' }, { id: 'sleep', label: 'Bad sleep' }, { id: 'focus', label: "Couldn't focus" },
      ]} /> })
  }

  add({ id: 'reframe', quiz: true, render: (c) => <Reframe c={c} /> })

  add({ id: 'reasons', quiz: true, render: (c) => <Multi c={c} field="reasons" title="Why do you want to quit?" sub="We'll remind you of these when it gets hard." opts={REASONS} /> })

  add({ id: 'about', quiz: true, render: (c) => <About c={c} /> })
  add({ id: 'analyzing', render: (c) => <Analyzing c={c} /> })
  add({ id: 'results', render: (c) => <Results c={c} /> })
  if (usesVape(a)) add({ id: 'lungs', render: (c) => <Lungs c={c} /> })
  add({ id: 'when', render: (c) => <QuitWhen c={c} /> })
  add({ id: 'plan', render: (c) => <Plan c={c} /> })
  add({ id: 'lock', render: (c) => <LockDemo c={c} /> })
  add({ id: 'sos', render: (c) => <SosDemo c={c} /> })
  add({ id: 'notify', render: (c) => <Notify c={c} /> })
  add({ id: 'commit', render: (c) => <Commit c={c} /> })
  add({ id: 'ready', render: (c) => <Ready c={c} /> })
  return s
}

export { cigsPerDay }
