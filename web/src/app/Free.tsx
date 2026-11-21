import { useState } from 'react'
import { fmtDate } from '../calc'
import { APP_NAME, Icon } from '../ui'
import { useStore, fmtMoney, MILESTONES, now, plural } from './store'
import { Ring, Confetti, Sheet, Layer, haptic, hm } from './bits'
import type { Nav } from './AppShell'

const H = 36e5

export function FreeToday({ nav }: { nav: Nav }) {
  const { s, d, update } = useStore()
  const [slip, setSlip] = useState(false)
  const t = hm(d.freeMs)
  const hours = d.freeMs / H
  const next = MILESTONES.find((m) => m.h > hours)
  const prevH = [...MILESTONES].reverse().find((m) => m.h <= hours)?.h ?? 0
  const frac = next ? (hours - prevH) / (next.h - prevH) : 1
  const inStr = next ? (() => { const r = hm((next.h - hours) * H); return r.d >= 1 ? plural(r.d, 'day') : r.h >= 1 ? `${r.h} h` : `${r.m} min` })() : ''
  return (
    <div className="page">
      <div className="hdr">
        <h1 className="hdr-hi">{d.name ? `Hey ${d.name}` : 'Today'}</h1>
        <span className="chip-day">Free mode</span>
      </div>
      <div className="hero-ring">
        <Ring size={262} stroke={20} frac={d.slippedToday ? 0 : frac} color="var(--accent)" glow>
          {d.slippedToday ? <>
            <div className="ring-l" style={{ marginTop: 0 }}>Day 1 starts</div>
            <div className="ring-num sm">tomorrow</div>
          </> : <>
            <div className="ring-num">{t.d >= 1 ? t.d : t.h}</div>
            <div className="ring-l">{t.d >= 1 ? (t.d === 1 ? 'day' : 'days') : t.h === 1 ? 'hour' : 'hours'} nicotine-free</div>
            <div className="ring-of">{t.d >= 1 ? `and ${plural(t.h, 'hour')}` : `and ${plural(t.m, 'minute')}`}</div>
          </>}
        </Ring>
      </div>
      {next && !d.slippedToday && (
        <div className="card next-ms">
          <div className="nm-k">Next up · in {inStr}</div>
          <div className="nm-t"><b>{next.t}:</b> {next.d.toLowerCase()}</div>
        </div>
      )}
      <div className="tiles2">
        <div className="tile2"><div className="t2-k">{fmtMoney(d.moneyKept)}</div><div className="t2-l">Kept so far</div></div>
        <div className="tile2"><div className="t2-k">{d.beaten}</div><div className="t2-l">Cravings beaten</div></div>
      </div>
      <div className="card ms-list">
        <div className="setup-h"><span>Since your quit day</span><span className="muted">{fmtDate(new Date(d.quitAt))}</span></div>
        {MILESTONES.map((m) => {
          const done = hours >= m.h
          return (
            <div key={m.t} className={`ms-row ${done ? 'done' : ''} ${m === next ? 'next' : ''}`}>
              <span className="check-dot">{done && <Icon name="check" size={13} />}</span>
              <span className="ms-t">{m.t}</span><span className="ms-d">{m.d}</span>
            </div>
          )
        })}
        <p className="fine" style={{ marginTop: 10 }}>General timelines. Everyone's body is different.</p>
      </div>
      {s.slips.length > 0 && <div className="best">Best run so far: <b>{plural(d.bestRunDays, 'day')}</b></div>}
      <button className="slip-btn" onClick={() => setSlip(true)}>I slipped</button>
      {slip && <Layer>
        <div className="sys-dim" onClick={() => setSlip(false)}>
          <div className="slip-card" onClick={(e) => e.stopPropagation()}>
            <div className="slip-t">One slip isn't a relapse.</div>
            <div className="slip-s">Day count keeps your best; tomorrow is day 1 of the next run. Log it so the record stays honest.</div>
            <button className="cta cta-primary" onClick={() => { haptic(14); update((x) => ({ ...x, slips: [...x.slips, { at: now() }] })); setSlip(false); nav.toast('Logged. Tomorrow is day 1.') }}>Log the slip</button>
            <button className="link" onClick={() => setSlip(false)}>Never mind</button>
          </div>
        </div>
      </Layer>}
    </div>
  )
}

export function QuitDay({ nav }: { nav: Nav }) {
  const { s, d, update } = useStore()
  const done = () => { update((x) => ({ ...x, quitSeen: true })); nav.open(null) }
  const share = async () => {
    haptic(10)
    try { await navigator.share?.({ title: APP_NAME, text: `Nicotine-free since ${fmtDate(new Date(d.quitAt))}. ${fmtMoney(d.moneyKept)} kept.` }) } catch { /* canceled */ }
  }
  return (
    <Sheet className="quit-sheet">
      <Confetti top={192} n={50} spread={0.8} around />
      <div className="breath-orb small" style={{ top: 190 }} />
      <div className="q-body">
        <div className="ready-check big"><Icon name="leaf" size={36} /></div>
        <h1 className="hero q-h">You're<br />nicotine-free.</h1>
        <div className="date-pill">{fmtDate(new Date(d.quitAt), true)}</div>
        <div className="q-card">
          <div className="q-share-top"><span>{APP_NAME.toLowerCase()}</span><span>{s.answers.name ?? ''}</span></div>
          <div className="q-grid">
            <div><b>{fmtMoney(d.moneyKept)}</b><span>kept</span></div>
            <div><b>{d.beaten}</b><span>cravings beaten</span></div>
            <div><b>{s.budgets.length}</b><span>weeks of steps</span></div>
          </div>
          <div className="q-share-f">From {d.startAmt} {d.unit} a day to zero.</div>
        </div>
      </div>
      <div className="sheet-bottom">
        <button className="cta cta-primary" onClick={done}>Start free mode</button>
        <button className="link" onClick={share}>Share my card</button>
      </div>
    </Sheet>
  )
}
