import { useEffect, useState } from 'react'
import { type Answers, plan, budgetUnit, fmtDate, quitDate, money, yearlySpend } from './calc'
import { APP_NAME, Icon, CTA, Bottom, StatusBar, isStill } from './ui'

const PRICE = 39.99
const CUR = 'CAD'
const perWeek = (PRICE / 52).toFixed(2)

function trialEnd() {
  const d = new Date()
  d.setDate(d.getDate() + 7)
  return d
}
function reminderDay() {
  const d = new Date()
  d.setDate(d.getDate() + 5)
  return d
}

// The app's home screen, small, playing inside the phone on page 1.
export function MiniHome({ a }: { a: Answers }) {
  const budget = plan(a)[0] || 10
  const unit = budgetUnit(a)
  const step = 1
  const [used, setUsed] = useState(Math.round(budget * 0.4))
  const [pulse, setPulse] = useState(false)
  useEffect(() => {
    if (isStill()) return
    const id = setInterval(() => {
      setPulse(true)
      setUsed((u) => (u + step > budget * 0.9 ? Math.round(budget * 0.4) : u + step))
      setTimeout(() => setPulse(false), 350)
    }, 1400)
    return () => clearInterval(id)
  }, [])
  const R = 62, C = 2 * Math.PI * R
  const left = budget - used
  return (
    <div className="mini">
      <div className="mini-head">
        <span className="mini-hi">{a.name ? `Hey ${a.name}` : 'Today'}</span>
        <span className="mini-streak">Day 3 · on plan</span>
      </div>
      <div className="mini-ring">
        <svg width="150" height="150" viewBox="0 0 150 150">
          <circle cx="75" cy="75" r={R} stroke="rgba(255,255,255,.1)" strokeWidth="11" fill="none" />
          <circle cx="75" cy="75" r={R} stroke="var(--accent)" strokeWidth="11" fill="none" strokeLinecap="round"
            strokeDasharray={C} strokeDashoffset={C * (used / budget)} transform="rotate(-90 75 75)" style={{ transition: 'stroke-dashoffset .4s' }} />
        </svg>
        <div className="mini-ring-in">
          <div className="mini-left">{left}</div>
          <div className="mini-left-l">{unit} left today</div>
        </div>
      </div>
      <div className={`mini-log ${pulse ? 'pulse' : ''}`}>+ Log a {unit === 'pouches' ? 'pouch' : 'hit'}</div>
      <div className="mini-row">
        <div className="mini-tile"><div className="mt-k">{money(Math.round(yearlySpend(a) / 365 * 3))}</div><div className="mt-l">kept so far</div></div>
        <div className="mini-tile sos"><div className="mt-k">SOS</div><div className="mt-l">craving help</div></div>
      </div>
      <div className="mini-week">
        {plan(a).slice(0, 6).map((s, i) => (
          <div key={i} className={`mw ${i === 0 ? 'on' : ''}`}><div className="mw-b" style={{ height: `${8 + (s / Math.max(1, plan(a)[0])) * 26}px` }} /><span>W{i + 1}</span></div>
        ))}
      </div>
    </div>
  )
}

export function PaywallP1({ a, next, close }: { a: Answers; next: () => void; close: () => void }) {
  return (
    <div className="screen pw">
      <div className="pw-top"><span /><button className="iconbtn" onClick={close}><Icon name="close" /></button></div>
      <h1 className="title center pw-h">We want you to try<br />{APP_NAME} for free</h1>
      <div className="phone-mock">
        <div className="pm-screen">
          <StatusBar />
          <MiniHome a={a} />
        </div>
        <div className="pm-notch" />
      </div>
      <Bottom>
        <p className="fine center ok"><Icon name="check" size={14} /> No payment due now</p>
        <CTA onClick={next}>Try for $0.00</CTA>
        <p className="fine center">Just {money(PRICE).replace('$', '$')} {CUR} per year (${perWeek}/wk)</p>
      </Bottom>
    </div>
  )
}

export function PaywallP2({ next, back }: { next: () => void; back: () => void }) {
  return (
    <div className="screen pw">
      <div className="pw-top"><button className="iconbtn" onClick={back}><Icon name="back" /></button><span /></div>
      <h1 className="title center pw-h">We'll send you a reminder<br />before your free trial ends</h1>
      <div className="bell-wrap">
        <div className="bell"><Icon name="bell" size={92} /></div>
        <div className="bell-badge">1</div>
      </div>
      <div className="trial-tl">
        <TLRow icon="lock" t="Today" d={`Unlock your full plan, the lock-screen tracker and craving SOS.`} on />
        <TLRow icon="bell" t={`Day 5 · ${fmtDate(reminderDay())}`} d="We'll remind you your trial is ending." />
        <TLRow icon="star" t={`Day 7 · ${fmtDate(trialEnd())}`} d={`You'll be charged ${money(PRICE)} ${CUR} unless you cancel before.`} />
      </div>
      <Bottom>
        <p className="fine center ok"><Icon name="check" size={14} /> No payment due now</p>
        <CTA onClick={next}>Continue for free</CTA>
      </Bottom>
    </div>
  )
}
const TLRow = ({ icon, t, d, on }: { icon: string; t: string; d: string; on?: boolean }) => (
  <div className={`ttl ${on ? 'on' : ''}`}><span className="ttl-i"><Icon name={icon} size={16} /></span><div><div className="ttl-t">{t}</div><div className="ttl-d">{d}</div></div></div>
)

export function PaywallP3({ a, back, close, buy }: { a: Answers; back: () => void; close: () => void; buy: () => void }) {
  return (
    <div className="screen pw3">
      <img src="/img/paywall-hero.jpg" alt="" className="pw3-img" />
      <div className="pw3-fade" />
      <div className="pw-top abs"><button className="iconbtn" onClick={back}><Icon name="back" /></button><button className="iconbtn" onClick={close}><Icon name="close" /></button></div>
      <div className="pw3-body">
        <h1 className="pw3-h">Start your FREE trial<br />to continue</h1>
        <div className="plan-sel">
          <div className="plan-sel-top">7 DAYS FREE</div>
          <div className="plan-sel-row">
            <span className="plan-radio"><Icon name="check" size={16} /></span>
            <div className="plan-sel-txt">
              <div className="pst-1">Start for free</div>
              <div className="pst-2">{money(PRICE)} {CUR} billed annually</div>
            </div>
            <div className="pst-price">${perWeek}/wk</div>
          </div>
        </div>
        <p className="pw3-quit">Nicotine-free by {fmtDate(quitDate(a))}. Keep {money(yearlySpend(a))} a year.</p>
        <CTA onClick={buy}>Start my free week</CTA>
        <p className="fine center legal">7 days free, then {money(PRICE)} {CUR} per year. Billed annually and renews automatically unless canceled in the App Store.</p>
        <p className="fine center links">Terms · Privacy · Restore</p>
      </div>
    </div>
  )
}
