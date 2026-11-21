import { useEffect, useRef, useState } from 'react'
import { fmtDate } from '../calc'
import { Icon } from '../ui'
import { useStore, fmtMoney, plural, unitWord, dayKey, type Mood } from './store'
import { Ring, Confetti, haptic } from './bits'
import type { Nav } from './AppShell'
import { FreeToday } from './Free'

export function Today({ nav, focus }: { nav: Nav; focus?: 'checkin' }) {
  const { d } = useStore()
  if (d.free) return <FreeToday nav={nav} />
  return <PlanToday nav={nav} focus={focus} />
}

function PlanToday({ nav, focus }: { nav: Nav; focus?: 'checkin' }) {
  const { s, d } = useStore()
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => { if (focus) ref.current?.scrollIntoView({ block: 'center' }) }, [focus])
  const zero = d.budget === 0
  const leftFrac = d.budget ? d.left / d.budget : 0
  const state = d.over > 0 || (zero && d.used > 0) ? 'over' : zero ? 'zero' : leftFrac < 0.3 ? 'low' : 'ok'
  const color = state === 'over' ? 'var(--danger)' : state === 'low' ? 'var(--warn)' : 'var(--accent)'
  const frac = state === 'over' ? Math.min(1, d.over / Math.max(1, d.budget)) : leftFrac
  const nearPct = Math.round(d.pctUsed * 100)

  return (
    <div className="page">
      <div className="hdr">
        <h1 className="hdr-hi">{d.name ? `Hey ${d.name}` : 'Today'}</h1>
        <span className="chip-day">Day {d.dayIdx + 1} · Week {d.weekIdx + 1}</span>
      </div>

      {d.stepDownToday && (
        <div className="banner"><Icon name="spark" size={18} /><span>New budget today: <b>{d.budget}</b>. Down from {d.prevBudget}.</span></div>
      )}
      {zero && (
        <div className="banner"><Icon name="flag" size={18} /><span><b>Last step.</b> Zero {d.unit} this week. SOS is here whenever you need it.</span></div>
      )}

      <div className="hero-ring">
        <Ring size={262} stroke={20} frac={frac} color={color} glow>
          {state === 'over' ? (
            <><div className="ring-num danger-t">+{d.over}</div><div className="ring-l">over today's budget</div></>
          ) : (
            <><div className="ring-num">{Math.max(0, d.left)}</div><div className="ring-l">{unitWord(d, d.left)} left today</div></>
          )}
          <div className="ring-of">{d.used} of {d.budget} logged</div>
        </Ring>
      </div>
      <p className={`ring-note ${state}`}>
        {d.used === 0 && !zero && <>Nothing logged yet. Tap below each time you pick it up.</>}
        {d.used > 0 && state === 'ok' && <>On track. Spread the other {d.left} through your day.</>}
        {state === 'low' && d.left > 0 && <>You're at {nearPct}%. {plural(d.left, d.one, d.unit)} left. Spread them out.</>}
        {state === 'low' && d.left === 0 && <>That's today's budget. Anything more still gets logged.</>}
        {state === 'over' && <>Going over isn't failure; it's data. Keep logging so the plan stays honest.</>}
        {state === 'zero' && <>Every craving you ride out now is one less to come.</>}
      </p>

      <button className="log-btn" onClick={() => nav.logHit('app')}>
        <Icon name="plus" size={22} /> Log a {d.one}
      </button>

      <div className="tiles2">
        <div className="tile2"><div className="t2-k">{fmtMoney(d.moneyKept)}</div><div className="t2-l">Kept so far</div></div>
        <div className="tile2"><div className="t2-k">{d.beaten}</div><div className="t2-l">Cravings beaten</div></div>
      </div>

      <PlanCard nav={nav} />
      <TimelineStrip />
      <div ref={ref}><CheckInCard nav={nav} /></div>
      {!(s.setup.widget && s.setup.checkins && s.setup.sos && s.setup.reasons) && <SetupCard nav={nav} />}
    </div>
  )
}

function PlanCard({ nav }: { nav: Nav }) {
  const { s, d } = useStore()
  const max = Math.max(...s.budgets, 1)
  return (
    <button className="card plan-mini" onClick={() => nav.setTab('plan')}>
      <div className="pm-top">
        <div>
          <div className="pm-l">This week</div>
          <div className="pm-v">{d.budget}<span>/day</span>
            {d.nextBudget !== undefined && <span className="pm-next"> → next week {d.nextBudget}</span>}
            {d.nextBudget === undefined && <span className="pm-next"> · last step</span>}
          </div>
        </div>
        <Icon name="chev" size={18} />
      </div>
      <div className="pm-bars">
        {s.budgets.map((b, i) => (
          <div key={i} className={`pmb ${i === d.weekIdx ? 'on' : i < d.weekIdx ? 'past' : ''}`}>
            <div className="pmb-b" style={{ height: b === 0 ? 4 : 6 + (b / max) * 34 }} />
            <span>W{i + 1}</span>
          </div>
        ))}
      </div>
      <div className="pm-foot"><Icon name="flag" size={15} /> Nicotine-free in <b>{plural(d.daysToQuit, 'day')}</b> · {fmtDate(new Date(d.quitAt))}</div>
    </button>
  )
}

function TimelineStrip() {
  const { d } = useStore()
  const byHour = new Array(24).fill(0)
  for (const l of d.todayLogs) byHour[new Date(l.at).getHours()]++
  return (
    <div className="card strip">
      <div className="strip-h"><span>Today</span><span className="muted">{plural(d.used, d.one, d.unit)}</span></div>
      <div className="strip-cols">
        {byHour.map((n, h) => (
          <div key={h} className={`sc ${h === d.hour ? 'now' : ''} ${h > d.hour ? 'future' : ''}`}>
            {[...Array(Math.min(n, 4))].map((_, i) => <i key={i} />)}
            {n > 4 && <b>{n}</b>}
          </div>
        ))}
      </div>
      <div className="strip-x"><span>12a</span><span>6a</span><span>12p</span><span>6p</span><span>12a</span></div>
    </div>
  )
}

const MOODS: { id: Mood; e: string; l: string }[] = [{ id: 'good', e: '😌', l: 'Good' }, { id: 'ok', e: '😐', l: 'Okay' }, { id: 'hard', e: '😣', l: 'Hard' }]

function CheckInCard({ nav }: { nav: Nav }) {
  const { d, update } = useStore()
  const [mood, setMood] = useState<Mood | null>(null)
  const [note, setNote] = useState('')
  const [justDone, setJustDone] = useState(false)
  const k = dayKey(d.t)
  if (d.hour < 12 && !d.morningDone) {
    return (
      <div className="card checkin">
        <div className="ci-eyebrow"><Icon name="sun" size={16} /> Morning check-in</div>
        <div className="ci-t">Commit to today's {d.budget}?</div>
        <div className="ci-s">One small promise each morning. Mornings set the tone.</div>
        <button className="cta cta-primary ci-btn" onClick={() => { haptic(14); update((x) => ({ ...x, checkins: [...x.checkins, { date: k, kind: 'morning' }] })); nav.toast(`You're in. ${d.budget} for today.`) }}>I'm in</button>
      </div>
    )
  }
  if (d.hour >= 18 && !d.eveningDone) {
    return (
      <div className="card checkin">
        <div className="ci-eyebrow"><Icon name="moon" size={16} /> Evening check-in</div>
        <div className="ci-t">How did today go?</div>
        <div className="moods">
          {MOODS.map((m) => (
            <button key={m.id} className={`mood ${mood === m.id ? 'on' : ''}`} onClick={() => { haptic(8); setMood(m.id) }}>
              <span className="mood-e">{m.e}</span><span>{m.l}</span>
            </button>
          ))}
        </div>
        {mood && <>
          <input className="field ci-note" placeholder="One line about today (optional)" value={note} onChange={(e) => setNote(e.target.value)} maxLength={80} />
          <button className="cta cta-primary ci-btn" onClick={() => { haptic(14); setJustDone(true); update((x) => ({ ...x, checkins: [...x.checkins, { date: k, kind: 'evening', mood, note: note.trim() || undefined }] })) }}>Save</button>
        </>}
      </div>
    )
  }
  if (d.eveningDone) {
    const under = d.used <= d.budget
    return (
      <div className={`card checkin done ${under ? 'win' : ''}`}>
        {justDone && under && <Confetti n={22} top={40} spread={0.6} />}
        <div className="ci-eyebrow"><Icon name="moon" size={16} /> Tonight · {MOODS.find((m) => m.id === d.eveningDone!.mood)?.e} {MOODS.find((m) => m.id === d.eveningDone!.mood)?.l}</div>
        <div className="ci-t">{under ? 'Under budget today. That counts.' : "Slips don't reset anything."}</div>
        <div className="ci-s">{under ? `${plural(d.used, d.one, d.unit)} of ${d.budget}. Same again tomorrow.` : `Tomorrow is a fresh budget of ${d.nextBudget !== undefined && d.dayIdx % 7 === 6 ? d.nextBudget : d.budget}. You're still on the plan.`}</div>
        {d.eveningDone.note && <div className="ci-quote">"{d.eveningDone.note}"</div>}
      </div>
    )
  }
  return null
}

function SetupCard({ nav }: { nav: Nav }) {
  const { s } = useStore()
  const items = [
    { k: 'widget' as const, l: 'Add the lock-screen widget', i: 'widget', go: () => nav.open({ kind: 'widgetguide' }) },
    { k: 'checkins' as const, l: 'Turn on check-ins', i: 'bell', go: () => nav.askPermission() },
    { k: 'sos' as const, l: 'Try SOS once', i: 'wind', go: () => nav.open({ kind: 'sos', step: 'interrupt' }) },
    { k: 'reasons' as const, l: 'Read your reasons', i: 'heart', go: () => nav.open({ kind: 'sos', step: 'myreasons' }) },
  ]
  const done = items.filter((x) => s.setup[x.k]).length
  return (
    <div className="card setup">
      <div className="setup-h"><span>Get set up</span><span className="muted">{done} of 4</span></div>
      <div className="setup-bar"><div style={{ width: `${(done / 4) * 100}%` }} /></div>
      {items.map((x) => (
        <button key={x.k} className={`setup-row ${s.setup[x.k] ? 'done' : ''}`} onClick={x.go} disabled={s.setup[x.k]}>
          <span className="check-dot">{s.setup[x.k] && <Icon name="check" size={13} />}</span>
          <span className="sr-l">{x.l}</span>
          {!s.setup[x.k] && <Icon name="chev" size={16} />}
        </button>
      ))}
    </div>
  )
}
