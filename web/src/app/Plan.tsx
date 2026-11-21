import { fmtDate, usesVape } from '../calc'
import { Icon } from '../ui'
import { useStore, fmtMoney, addDays, plural, DAY } from './store'
import { SectionTitle, haptic } from './bits'
import type { Nav } from './AppShell'

export function Plan({ nav }: { nav: Nav }) {
  const { s, d } = useStore()
  const pct = Math.round(d.progress * 100)
  return (
    <div className="page">
      <div className="hdr"><h1 className="hdr-hi">Your plan</h1><span className="chip-day">{d.free ? 'Complete' : `Week ${d.weekIdx + 1} of ${d.totalWeeks}`}</span></div>

      <div className={`lungs-card ${usesVape(s.answers) ? '' : 'plain'}`}>
        {usesVape(s.answers) ? <>
          {/* linear cross-fade: 0% = before only, 100% = after only */}
          <img src="/img/lungs-before.jpg" alt="" className="cmp-img lc-before" style={{ opacity: 1 - d.progress }} />
          <img src="/img/lungs-after.jpg" alt="" className="cmp-img lc-after" style={{ opacity: d.progress }} />
        </> : <div className="plain-steps">{s.budgets.map((b, i) => <i key={i} className={i < d.weekIdx || d.free ? 'past' : i === d.weekIdx ? 'on' : ''} style={{ height: `${12 + (b / Math.max(1, ...s.budgets)) * 78}%` }} />)}</div>}
        <div className="lc-fade" />
        <div className="lc-foot">
          <div className="lc-row"><span>Plan progress</span><b>{pct}%</b></div>
          <div className="lc-bar"><div style={{ width: `${Math.max(2, pct)}%` }} /></div>
          <div className="lc-note">{usesVape(s.answers) ? "An illustration of your plan's progress, not a scan." : `${d.free ? 'Every step done.' : `Step ${d.weekIdx + 1} of ${d.totalWeeks}.`} From ${d.startAmt} ${d.unit} a day to zero.`}</div>
        </div>
      </div>

      {d.adaptive && <Adaptive nav={nav} />}

      <SectionTitle right={<span className="muted">Finish {fmtDate(new Date(d.quitAt))}</span>}>Step-down</SectionTitle>
      <div className="weeks">
        {s.budgets.map((b, i) => (
          <div key={i} className={`wk ${i === d.weekIdx && !d.free ? 'on' : i < d.weekIdx || d.free ? 'past' : ''}`}>
            <span className="wk-l">W{i + 1}</span>
            <span className="wk-v">{b}</span>
            <span className="wk-d">{fmtDate(new Date(addDays(s.start, i * 7)))}</span>
          </div>
        ))}
        <div className={`wk flag ${d.free ? 'on' : ''}`}><Icon name="flag" size={17} /><span className="wk-d">{fmtDate(new Date(d.quitAt))}</span></div>
      </div>

      <Last7 />
      <Patterns />
      <Changing />

      <SectionTitle>Totals</SectionTitle>
      <div className="totals">
        <div className="tot"><b>{fmtMoney(d.moneyKept)}</b><span>money kept</span></div>
        <div className="tot"><b>{Math.round(d.mgAvoided).toLocaleString('en-US')} mg</b><span>nicotine avoided</span></div>
        <div className="tot"><b>{d.beaten}</b><span>cravings beaten</span></div>
        <div className="tot"><b>{d.underDays}</b><span>days under budget</span></div>
      </div>
      <p className="fine center" style={{ marginTop: 10 }}>Estimates from your answers and your logs.</p>
    </div>
  )
}

function Adaptive({ nav }: { nav: Nav }) {
  const { d, update } = useStore()
  const w = d.weekIdx
  const answer = (stay: boolean) => {
    haptic(16)
    update((x) => ({
      ...x,
      budgets: stay ? [...x.budgets.slice(0, w + 1), x.budgets[w], ...x.budgets.slice(w + 1)] : x.budgets,
      extraWeeks: x.extraWeeks + (stay ? 1 : 0),
      adaptiveDone: [...x.adaptiveDone, w],
    }))
    nav.toast(stay ? `Next week stays at ${d.budget}. Finish moves to ${fmtDate(new Date(addDays(d.quitAt, 7)))}` : `Keeping the plan. Next week: ${d.nextBudget}`)
  }
  return (
    <div className="card adaptive">
      <div className="ad-k"><Icon name="refresh" size={15} /> Over budget 3 of the last 4 days</div>
      <div className="ad-t">This step feels steep. Stay on {d.budget} another week?</div>
      <div className="ad-s">Your finish moves from {fmtDate(new Date(d.quitAt))} to {fmtDate(new Date(addDays(d.quitAt, 7)))}. A slower step you can keep beats a fast one you can't.</div>
      <div className="ad-btns">
        <button className="cta cta-primary sm" onClick={() => answer(true)}>Stay another week</button>
        <button className="cta cta-ghost2 sm" onClick={() => answer(false)}>Keep going</button>
      </div>
    </div>
  )
}

function Last7() {
  const { s, d } = useStore()
  const first = d.dayIdx < 6
  const last = d.totalWeeks * 7 - 7 // in free mode, show the final plan week
  const days = [...Array(7).keys()].map((i) => {
    const di = (d.free ? last : first ? 0 : d.dayIdx - 6) + i
    const h = d.history.find((x) => x.d === di)
    const at = addDays(s.start, di)
    return { di, h, budget: s.budgets[Math.floor(di / 7)] ?? 0, label: di === d.dayIdx ? 'Today' : new Date(at).toLocaleDateString('en-US', { weekday: 'short' }).slice(0, 2) }
  })
  const max = Math.max(4, ...days.map((x) => Math.max(x.h?.used ?? 0, x.budget))) * 1.12
  const H = 130
  const y = (v: number) => H - (v / max) * H
  return (
    <>
      <SectionTitle right={<span className="legend-inline"><i className="lg-u" />under <i className="lg-o" />over</span>}>{d.free ? 'Your last plan week' : first ? 'Your first week' : 'Last 7 days'}</SectionTitle>
      <div className="card chart7">
        <div className="c7">
          {days.map((x, i) => {
            const u = x.h?.used ?? 0
            const b = x.budget
            const today = x.di === d.dayIdx
            const cls = !x.h ? 'none' : u > b ? 'over' : 'under'
            return (
              <div className="c7-col" key={i}>
                <div className="c7-area" style={{ height: H }}>
                  <div className={`c7-budget ${x.h ? '' : 'future'}`} style={{ top: y(b) }} />
                  {x.h && <div className="c7-v" style={{ bottom: (u / max) * H + 4 }}>{u}</div>}
                  <div className={`c7-bar ${cls} ${today ? 'today' : ''}`} style={{ height: x.h ? Math.max(3, (u / max) * H) : 3 }} />
                </div>
                <span className={`c7-x ${today ? 'on' : ''}`}>{x.label}</span>
              </div>
            )
          })}
        </div>
        <div className="c7-foot"><span className="dash" /> daily budget{first && !d.free && <span className="muted"> · fills in as the week goes</span>}</div>
      </div>
    </>
  )
}

function Patterns() {
  const { d } = useStore()
  const max = Math.max(1, ...d.hourHist)
  return (
    <>
      <SectionTitle>Your patterns</SectionTitle>
      <div className="card patterns">
        {d.pattern ? <>
          <div className="pt-t">{d.pattern}</div>
          <div className="heat">
            {d.hourHist.map((n, h) => <i key={h} style={{ opacity: n ? 0.18 + 0.82 * (n / max) : 1, background: n ? 'var(--accent)' : 'var(--surface2)' }} />)}
          </div>
          <div className="strip-x"><span>12a</span><span>6a</span><span>12p</span><span>6p</span><span>12a</span></div>
          <div className="fine" style={{ marginTop: 8 }}>From {plural(d.daysWithLogs, 'day')} of logs. Check-ins are timed around these.</div>
        </> : <>
          <div className="pt-t muted">Patterns show up after 2 days of logging.</div>
          <div className="heat empty">{[...Array(24)].map((_, h) => <i key={h} />)}</div>
          <div className="fine" style={{ marginTop: 8 }}>{d.daysWithLogs === 1 ? 'One more day to go.' : 'Log each one today and tomorrow.'}</div>
        </>}
      </div>
    </>
  )
}

function Changing() {
  const { s, d } = useStore()
  const st = d.startAmt
  const halfIdx = s.budgets.findIndex((b) => b <= st / 2)
  const weekDone = [...Array(d.weekIdx + (d.free ? 1 : 0)).keys()].some((w) => {
    const days = d.history.filter((h) => Math.floor(h.d / 7) === w)
    return days.length === 7 && days.reduce((x, h) => x + h.used, 0) <= days[0].budget * 7
  })
  const q = d.quitAt
  const items = [
    { t: 'First week under budget', at: addDays(s.start, 7), done: weekDone },
    { t: 'Nicotine cut in half', at: addDays(s.start, Math.max(0, halfIdx) * 7), done: halfIdx >= 0 && (d.free || d.weekIdx >= halfIdx) },
    { t: 'Last step', at: addDays(s.start, (s.budgets.length - 1) * 7), done: d.free || d.weekIdx >= s.budgets.length - 1 },
    { t: 'Nicotine-free', at: q, done: d.free },
    { t: '72 h free: nicotine is out of your body', at: q + 3 * DAY, done: d.free && d.freeMs >= 3 * DAY },
    { t: '2–4 weeks free: cravings fade', at: addDays(q, 14), done: d.free && d.freeMs >= 14 * DAY },
    { t: '1–3 months free: easier breathing', at: addDays(q, 30), done: d.free && d.freeMs >= 60 * DAY },
  ]
  const nextI = items.findIndex((x) => !x.done)
  return (
    <>
      <SectionTitle>What's changing</SectionTitle>
      <div className="card changing">
        {items.map((x, i) => (
          <div key={x.t} className={`chg ${x.done ? 'done' : ''} ${i === nextI ? 'next' : ''}`}>
            <span className="check-dot">{x.done && <Icon name="check" size={13} />}</span>
            <span className="chg-t">{x.t}</span>
            <span className="chg-d">{x.done ? 'Done' : `${i < 4 ? '' : 'from '}${fmtDate(new Date(x.at))}`}</span>
          </div>
        ))}
        <p className="fine" style={{ marginTop: 10 }}>Body changes are general timelines, not a promise. Everyone is different.</p>
      </div>
    </>
  )
}
