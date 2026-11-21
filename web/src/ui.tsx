import { useEffect, useState, type ReactNode } from 'react'

export const APP_NAME = 'OutOfBody'

export function Icon({ name, size = 22 }: { name: string; size?: number }) {
  const p = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 1.8, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const }
  switch (name) {
    case 'back': return <svg {...p}><path d="M15 5l-7 7 7 7" /></svg>
    case 'close': return <svg {...p}><path d="M6 6l12 12M18 6L6 18" /></svg>
    case 'check': return <svg {...p} strokeWidth={2.6}><path d="M5 12.5l4.5 4.5L19 7.5" /></svg>
    case 'disposable': return <svg {...p}><rect x="8" y="2.5" width="8" height="19" rx="3" /><path d="M10 2.5v-0M8 7h8" /><circle cx="12" cy="17" r="1" /></svg>
    case 'pod': return <svg {...p}><rect x="7.5" y="7" width="9" height="14.5" rx="2.5" /><path d="M9.5 7V4.5a1 1 0 011-1h3a1 1 0 011 1V7" /><circle cx="12" cy="16.5" r="1" /></svg>
    case 'refill': return <svg {...p}><rect x="7" y="9" width="10" height="12.5" rx="2" /><path d="M10 9V5h4v4M11 2.5h2v2.5h-2z" /><path d="M9.5 13h5" /></svg>
    case 'pouch': return <svg {...p}><ellipse cx="12" cy="12" rx="8.5" ry="8.5" /><ellipse cx="12" cy="12" rx="5" ry="5" /></svg>
    case 'combo': return <svg {...p}><rect x="4" y="4" width="6" height="16" rx="2.2" /><circle cx="16.5" cy="14" r="4.5" /></svg>
    case 'bell': return <svg {...p}><path d="M6 16V11a6 6 0 1112 0v5l1.5 2h-15z" /><path d="M10 20.5a2 2 0 004 0" /></svg>
    case 'lock': return <svg {...p}><rect x="5" y="10.5" width="14" height="10" rx="2.5" /><path d="M8 10.5V8a4 4 0 118 0v2.5" /></svg>
    case 'spark': return <svg {...p}><path d="M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5L18 18M6 18l2.5-2.5M15.5 8.5L18 6" /></svg>
    case 'wind': return <svg {...p}><path d="M3 9h11a3 3 0 10-3-3M3 15h15a3 3 0 11-3 3M3 12h7" /></svg>
    case 'shield': return <svg {...p}><path d="M12 3l7.5 3v5.5c0 4.5-3.2 8.2-7.5 9.5-4.3-1.3-7.5-5-7.5-9.5V6z" /><path d="M8.8 12l2.2 2.2 4.4-4.4" /></svg>
    case 'chart': return <svg {...p}><path d="M4 20V10M10 20V4M16 20v-7M22 20H2" /></svg>
    case 'star': return <svg {...p} fill="currentColor" stroke="none"><path d="M12 2.8l2.8 5.8 6.3.9-4.6 4.4 1.1 6.3L12 17.2l-5.6 3 1.1-6.3L2.9 9.5l6.3-.9z" /></svg>
    default: return null
  }
}

export function StatusBar({ dark = true }: { dark?: boolean }) {
  return (
    <div className="statusbar" style={{ color: dark ? '#fff' : '#000' }}>
      <span className="sb-time">9:41</span>
      <span className="sb-icons">
        <svg width="18" height="12" viewBox="0 0 18 12" fill="currentColor"><rect x="0" y="8" width="3" height="4" rx="1" /><rect x="5" y="5.5" width="3" height="6.5" rx="1" /><rect x="10" y="3" width="3" height="9" rx="1" /><rect x="15" y="0" width="3" height="12" rx="1" /></svg>
        <svg width="16" height="12" viewBox="0 0 16 12" fill="currentColor"><path d="M8 2.5c2.3 0 4.4.9 6 2.4l1.2-1.3A10.3 10.3 0 008 .7C5.2.7 2.7 1.8.8 3.6L2 4.9a8.5 8.5 0 016-2.4zm0 3.6c1.3 0 2.5.5 3.4 1.3l1.2-1.3a6.8 6.8 0 00-9.2 0l1.2 1.3c.9-.8 2.1-1.3 3.4-1.3zm0 3.5c-.6 0-1.1.2-1.5.6L8 11.8l1.5-1.6c-.4-.4-.9-.6-1.5-.6z" /></svg>
        <svg width="27" height="13" viewBox="0 0 27 13" fill="none"><rect x=".5" y=".5" width="23" height="12" rx="3.5" stroke="currentColor" opacity=".4" /><rect x="2" y="2" width="20" height="9" rx="2.2" fill="currentColor" /><path d="M25 4.5v4c.8-.3 1.3-1.1 1.3-2s-.5-1.7-1.3-2z" fill="currentColor" opacity=".45" /></svg>
      </span>
    </div>
  )
}

export function TopBar({ progress, onBack }: { progress?: number; onBack?: () => void }) {
  return (
    <div className="topbar">
      <button className="iconbtn" onClick={onBack} style={{ visibility: onBack ? 'visible' : 'hidden' }} aria-label="Back">
        <Icon name="back" />
      </button>
      {progress !== undefined && (
        <div className="progress"><div className="progress-fill" style={{ width: `${Math.max(4, progress * 100)}%` }} /></div>
      )}
      <div style={{ width: 40 }} />
    </div>
  )
}

export function Title({ children, sub }: { children: ReactNode; sub?: ReactNode }) {
  return (
    <div className="title-wrap">
      <h1 className="title">{children}</h1>
      {sub && <p className="sub">{sub}</p>}
    </div>
  )
}

export interface Opt { id: string; label: string; detail?: string; icon?: string; tag?: string }

export function Options({ opts, value, onPick, multi = false }: { opts: Opt[]; value?: string | string[]; onPick: (id: string) => void; multi?: boolean }) {
  const sel = (id: string) => (Array.isArray(value) ? value.includes(id) : value === id)
  return (
    <div className="opts">
      {opts.map((o) => (
        <button key={o.id} className={`opt ${sel(o.id) ? 'opt-on' : ''}`} onClick={() => onPick(o.id)}>
          {o.icon && <span className="opt-icon"><Icon name={o.icon} /></span>}
          <span className="opt-text">
            <span className="opt-label">{o.label}{o.tag && <span className="opt-tag">{o.tag}</span>}</span>
            {o.detail && <span className="opt-detail">{o.detail}</span>}
          </span>
          <span className={`opt-mark ${multi ? 'square' : ''}`}>{sel(o.id) && <Icon name="check" size={14} />}</span>
        </button>
      ))}
    </div>
  )
}

export function CTA({ children, onClick, disabled, variant = 'primary' }: { children: ReactNode; onClick?: () => void; disabled?: boolean; variant?: 'primary' | 'ghost' | 'light' }) {
  return (
    <button className={`cta cta-${variant}`} disabled={disabled} onClick={onClick}>{children}</button>
  )
}

export function Bottom({ children }: { children: ReactNode }) {
  return <div className="bottom">{children}</div>
}

export function useCountUp(target: number, ms = 1200, start = true) {
  const [v, setV] = useState(0)
  useEffect(() => {
    if (!start) return
    if (new URLSearchParams(location.search).has('still')) { setV(target); return }
    let raf = 0
    const t0 = performance.now()
    const tick = (t: number) => {
      const k = Math.min(1, (t - t0) / ms)
      setV(target * (1 - Math.pow(1 - k, 3)))
      if (k < 1) raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [target, ms, start])
  return v
}

export const isStill = () => new URLSearchParams(location.search).has('still')
