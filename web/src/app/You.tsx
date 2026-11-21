import { useState } from 'react'
import { type Answers, type Device, fmtDate, plan, budgetUnit, recommendedWeeks } from '../calc'
import { Icon, Options } from '../ui'
import { REASONS } from '../screens'
import { useStore, plural, now, midnight, defaultNotifs, type AppState } from './store'
import { Toggle, Signature, SectionTitle, Sheet, Layer, haptic } from './bits'
import { eraseAndRestart, type Nav } from './AppShell'

const replan = (x: AppState, a: Answers): AppState => {
  const budgets = plan(a)
  return { ...x, answers: a, budgets, extraWeeks: 0, notifs: x.notifs.map((n) => (n.id === 'morning' ? { ...n, detail: `"Today's budget: ${budgets[0]} ${budgetUnit(a)}."` } : n)) }
}

export function You({ nav }: { nav: Nav }) {
  const { s, d, update } = useStore()
  const [adding, setAdding] = useState(false)
  const [custom, setCustom] = useState('')
  const [device, setDevice] = useState(false)
  const [confirm, setConfirm] = useState<null | 'restart' | 'erase'>(null)
  const a = s.answers
  const weeks = a.weeks ?? recommendedWeeks(a)
  const addReason = (r: string) => { if (r && !s.reasons.includes(r)) update((x) => ({ ...x, reasons: [...x.reasons, r] })); setCustom(''); setAdding(false) }

  return (
    <div className="page">
      <div className="profile">
        <div className="avatar">{(a.name ?? 'Y').slice(0, 1).toUpperCase()}</div>
        <div>
          <div className="pf-name">{a.name ?? 'You'}</div>
          <div className="pf-sub">Nicotine-free by {fmtDate(new Date(d.quitAt), true)}</div>
          <div className="pf-day">{d.free ? (Math.floor((d.t - d.quitAt) / 864e5) === 0 ? 'Quit day is today' : `${plural(Math.floor((d.t - d.quitAt) / 864e5), 'day')} since quit day`) : `Day ${d.dayIdx + 1} of ${d.totalWeeks * 7}`}</div>
        </div>
      </div>

      <SectionTitle right={<button className="sec-a" onClick={() => setAdding((v) => !v)}>{adding ? 'Done' : 'Add'}</button>}>My reasons</SectionTitle>
      <div className="card list">
        {s.reasons.map((r) => (
          <div className="li" key={r}>
            <Icon name="heart" size={17} /><span className="li-l">{r}</span>
            <button className="li-x" aria-label={`Remove ${r}`} onClick={() => update((x) => ({ ...x, reasons: x.reasons.filter((y) => y !== r) }))}><Icon name="close" size={15} /></button>
          </div>
        ))}
        {!s.reasons.length && <div className="li"><span className="li-l muted">No reasons yet. Add one.</span></div>}
        {adding && (
          <div className="add-reason">
            <div className="chips left">
              {REASONS.filter((r) => !s.reasons.includes(r.label)).map((r) => <button key={r.id} className="chip" onClick={() => addReason(r.label)}>+ {r.label}</button>)}
            </div>
            <div className="ar-row">
              <input className="field sm" placeholder="Or write your own" value={custom} onChange={(e) => setCustom(e.target.value)} maxLength={60} />
              <button className="cta cta-primary xs" disabled={!custom.trim()} onClick={() => addReason(custom.trim())}>Add</button>
            </div>
          </div>
        )}
      </div>

      <SectionTitle>My pledge</SectionTitle>
      <div className="pledge-card small">
        <div className="pc-sig"><Signature src={s.signature ?? a.signature} name={a.name} /></div>
        <div className="pc-date">Signed {fmtDate(new Date(s.start), true)}</div>
      </div>

      <SectionTitle>Plan settings</SectionTitle>
      <div className="card list">
        <div className="li col">
          <span className="li-l">Pace</span>
          <div className="seg pace">
            {[2, 4, 6, 8].map((w) => (
              <button key={w} className={`seg-b ${weeks === w ? 'on' : ''}`} onClick={() => {
                if (w === weeks) return
                haptic(10)
                update((x) => replan(x, { ...x.answers, weeks: w }))
                const q = new Date(s.start); q.setDate(q.getDate() + 7 * w)
                nav.toast(`${w} weeks. Nicotine-free by ${fmtDate(q)}`)
              }}>{w} wk</button>
            ))}
          </div>
        </div>
        <button className="li" onClick={() => setDevice(true)}>
          <Icon name={a.device ?? 'disposable'} size={18} /><span className="li-l">What I use</span><span className="li-r">{DEVICES.find((x) => x.id === a.device)?.label}</span><Icon name="chev" size={16} />
        </button>
        <button className="li" onClick={() => setConfirm('restart')}>
          <Icon name="refresh" size={18} /><span className="li-l">Restart plan</span><Icon name="chev" size={16} />
        </button>
      </div>

      <SectionTitle>Check-ins</SectionTitle>
      <div className="card list">
        {!s.notifsAllowed && (
          <div className="li notif-off">
            <Icon name="bell" size={18} /><span className="li-l">Notifications are off</span>
            <button className="cta cta-primary xs" onClick={nav.askPermission}>Turn on</button>
          </div>
        )}
        {s.notifs.map((n) => (
          <div className={`li notif-row ${!s.notifsAllowed ? 'dim' : ''}`} key={n.id}>
            <div className="nr-txt">
              <div className="li-l">{n.label}</div>
              <div className="li-d">{n.detail}</div>
            </div>
            {n.time && (
              <label className="time-pill">
                {n.when && <span>{n.when}</span>}
                <input type="time" value={n.time} onChange={(e) => update((x) => ({ ...x, notifs: x.notifs.map((y) => (y.id === n.id ? { ...y, time: e.target.value } : y)) }))} />
                <span className="tp-shown">{fmtTime(n.time)}</span>
              </label>
            )}
            <Toggle label={n.label} on={n.on} onChange={(v) => update((x) => ({ ...x, notifs: x.notifs.map((y) => (y.id === n.id ? { ...y, on: v } : y)) }))} />
          </div>
        ))}
      </div>

      <SectionTitle>Widgets</SectionTitle>
      <div className="card list">
        <button className="li" onClick={() => nav.open({ kind: 'widgetguide' })}>
          <Icon name="widget" size={18} /><span className="li-l">Lock-screen widget setup</span>
          {s.setup.widget && <span className="li-r ok">Added</span>}<Icon name="chev" size={16} />
        </button>
      </div>

      <SectionTitle>Account</SectionTitle>
      <div className="card list">
        <button className="li" onClick={() => nav.toast('Manage your plan in Settings › Apple ID › Subscriptions')}><Icon name="star" size={17} /><span className="li-l">Subscription</span><span className="li-r">Yearly · trial</span><Icon name="chev" size={16} /></button>
        <button className="li" onClick={() => nav.toast('Purchases restored. You\'re all set.')}><Icon name="refresh" size={18} /><span className="li-l">Restore purchases</span><Icon name="chev" size={16} /></button>
        <button className="li"><Icon name="book" size={18} /><span className="li-l">Terms</span><Icon name="chev" size={16} /></button>
        <button className="li"><Icon name="shield" size={18} /><span className="li-l">Privacy</span><Icon name="chev" size={16} /></button>
      </div>
      <div className="data-note"><Icon name="lock" size={16} /> Your data stays on this phone. No account, nothing sent to a server.</div>
      <button className="erase" onClick={() => setConfirm('erase')}><Icon name="trash" size={17} /> Erase all data</button>

      {device && <Layer><DeviceSheet onClose={() => setDevice(false)} onSave={(p) => { update((x) => replan(x, { ...x.answers, ...p })); setDevice(false); nav.toast('Plan updated to match') }} /></Layer>}
      {confirm && <Layer>
        <div className="sys-dim">
          <div className="sys-alert">
            <div className="sys-t">{confirm === 'restart' ? 'Restart your plan?' : 'Erase all data?'}</div>
            <div className="sys-b">{confirm === 'restart' ? 'Your plan starts again from week 1 today. Your logs and cravings beaten stay.' : 'This deletes your plan, logs, and reasons from this phone. It can’t be undone.'}</div>
            <div className="sys-btns">
              <button onClick={() => setConfirm(null)}>Cancel</button>
              <button className="danger" onClick={() => {
                if (confirm === 'erase') { eraseAndRestart(); return }
                update((x) => ({ ...replan(x, x.answers), start: midnight(now()), reviewed: [], adaptiveDone: [], quitSeen: false, slips: [], notifs: defaultNotifs(x.answers, plan(x.answers)[0], budgetUnit(x.answers)).map((n) => ({ ...n, on: x.notifs.find((y) => y.id === n.id)?.on ?? true })) }))
                setConfirm(null); nav.setTab('today'); nav.toast('Fresh start. Day 1 is today.')
              }}><b>{confirm === 'restart' ? 'Restart' : 'Erase'}</b></button>
            </div>
          </div>
        </div>
      </Layer>}
    </div>
  )
}

const fmtTime = (t: string) => { const [h, m] = t.split(':').map(Number); return `${h % 12 || 12}:${String(m).padStart(2, '0')} ${h < 12 ? 'am' : 'pm'}` }

const DEVICES: { id: Device; label: string; icon: string }[] = [
  { id: 'disposable', label: 'Disposable vape', icon: 'disposable' }, { id: 'pod', label: 'Pod vape', icon: 'pod' },
  { id: 'refill', label: 'Refillable vape', icon: 'refill' }, { id: 'pouch', label: 'Nicotine pouches', icon: 'pouch' }, { id: 'combo', label: 'Vape and pouches', icon: 'combo' },
]
const HITS = [{ id: '15', label: '10–20 times' }, { id: '30', label: '20–40 times' }, { id: '50', label: '40–60 times' }, { id: '75', label: 'Honestly, all day' }]
const POUCHES = [{ id: '4', label: '1–5 pouches' }, { id: '8', label: '6–10 pouches' }, { id: '12', label: '11–15 pouches' }, { id: '18', label: '16 or more' }]

function DeviceSheet({ onClose, onSave }: { onClose: () => void; onSave: (p: Partial<Answers>) => void }) {
  const { s } = useStore()
  const [dev, setDev] = useState<Device>(s.answers.device ?? 'disposable')
  const pouch = dev === 'pouch'
  const cur = pouch ? s.answers.pouchesPerDay : s.answers.hitsPerDay
  const opts = pouch ? POUCHES : HITS
  const [amt, setAmt] = useState(String(opts.reduce((b, o) => (Math.abs(Number(o.id) - (cur ?? 0)) < Math.abs(Number(b.id) - (cur ?? 0)) ? o : b), opts[1]).id))
  return (
    <Sheet className="device-sheet" onClose={onClose}>
      <div className="guide-scroll">
        <h1 className="title">What do you use?</h1>
        <Options opts={DEVICES.map((x) => ({ id: x.id, label: x.label, icon: x.icon }))} value={dev} onPick={(id) => { setDev(id as Device); setAmt(id === 'pouch' ? '8' : '30') }} />
        <h2 className="title h2">{pouch ? 'Pouches a day' : 'Times a day you pick it up'}</h2>
        <Options opts={opts} value={amt} onPick={setAmt} />
      </div>
      <div className="sheet-bottom">
        <button className="cta cta-primary" onClick={() => onSave(pouch ? { device: dev, pouchesPerDay: Number(amt) } : { device: dev, hitsPerDay: Number(amt) })}>Update my plan</button>
      </div>
    </Sheet>
  )
}
