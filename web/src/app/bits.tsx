import { type ReactNode, useMemo } from 'react'
import { createPortal } from 'react-dom'
import { Icon, isStill } from '../ui'

export function haptic(ms = 12) { try { navigator.vibrate?.(ms) } catch { /* not supported */ } }

// Progress ring. `frac` = share of the arc drawn (remaining budget, or overage).
export function Ring({ size, stroke, frac, color, track = 'rgba(255,255,255,.08)', children, glow }: { size: number; stroke: number; frac: number; color: string; track?: string; children?: ReactNode; glow?: boolean }) {
  const R = (size - stroke) / 2, C = 2 * Math.PI * R, c = size / 2
  const f = Math.max(0, Math.min(1, frac))
  return (
    <div className="ring" style={{ width: size, height: size }}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        {glow && <circle cx={c} cy={c} r={R} stroke={color} strokeWidth={stroke} fill="none" opacity=".12" style={{ filter: 'blur(10px)' }} />}
        <circle cx={c} cy={c} r={R} stroke={track} strokeWidth={stroke} fill="none" />
        <circle cx={c} cy={c} r={R} stroke={color} strokeWidth={stroke} fill="none" strokeLinecap="round"
          strokeDasharray={C} strokeDashoffset={C * (1 - f)} transform={`rotate(-90 ${c} ${c})`}
          style={{ transition: 'stroke-dashoffset .6s cubic-bezier(.2,.8,.2,1), stroke .3s', opacity: f === 0 ? 0 : 1 }} />
      </svg>
      <div className="ring-in">{children}</div>
    </div>
  )
}

const COLORS = ['#4fe3b8', '#ffb547', '#ff6b6b', '#8fd3ff', '#f3f5f9', '#c9a7ff']
// `around`: a tight burst that stays around an icon and never falls onto the headline below it.
export function Confetti({ n = 36, top = 160, spread = 1, around = false }: { n?: number; top?: number; spread?: number; around?: boolean }) {
  const still = isStill()
  const bits = useMemo(() => [...Array(n)].map((_, i) => {
    const ang = (i / n) * Math.PI * 2 + (i % 3) * 0.3
    const dist = (90 + ((i * 37) % 110)) * spread
    return { dx: Math.cos(ang) * dist * (around ? 1.1 : 1.25), dy: around ? Math.sin(ang) * dist * (Math.sin(ang) < 0 ? 0.6 : 0.2) - 24 * spread : Math.sin(ang) * dist * 0.75 + 60, r: (i * 73) % 360, c: COLORS[i % COLORS.length], w: 6 + (i % 3) * 2, delay: (i % 6) * 25 }
  }), [n, spread, around])
  return (
    <div className={`confetti ${still ? 'still' : ''}`} style={{ top }} aria-hidden>
      {bits.map((b, i) => (
        <i key={i} style={{ '--dx': `${b.dx}px`, '--dy': `${b.dy}px`, '--r': `${b.r}deg`, background: b.c, width: b.w, height: b.w * 0.45, animationDelay: still ? '-380ms' : `${b.delay}ms` } as React.CSSProperties} />
      ))}
    </div>
  )
}

export function Toggle({ on, onChange, label }: { on: boolean; onChange: (v: boolean) => void; label: string }) {
  return <button role="switch" aria-checked={on} aria-label={label} className={`toggle ${on ? 'on' : ''}`} onClick={() => { haptic(8); onChange(!on) }}><span /></button>
}

// Full-screen sheet over the tabs (SOS, review, welcome...)
export function Sheet({ children, className = '', onClose, tone }: { children: ReactNode; className?: string; onClose?: () => void; tone?: 'calm' }) {
  return (
    <div className={`sheet ${tone ?? ''} ${className}`}>
      {onClose && <button className="iconbtn sheet-x" onClick={onClose} aria-label="Close"><Icon name="close" /></button>}
      {children}
    </div>
  )
}

// Their pledge signature, or a drawn stand-in for presets that never signed on this device.
export function Signature({ src, name }: { src?: string; name?: string }) {
  if (src) return <img className="sig-img" src={src} alt="Your signature" />
  return (
    <svg className="sig-img" viewBox="0 0 340 120" aria-label={`${name ?? ''} signature`}>
      <path d="M28 82c10-30 22-52 30-50 9 2-6 44-2 46 6 3 16-40 26-39 8 1-2 34 5 35 8 1 12-20 20-21 7-1 3 16 10 16 9 0 13-22 22-21 6 1 2 14 8 14 10-1 14-30 22-44 4-7 8-4 5 6-5 17-14 38-9 39 7 2 15-16 24-16 8 0 2 13 10 13 12 0 20-12 34-14 12-2 30 2 48-4"
        fill="none" stroke="#0b0f17" strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M40 96c60-6 140-8 250-4" fill="none" stroke="#0b0f17" strokeWidth="2.5" strokeLinecap="round" opacity=".55" />
    </svg>
  )
}

export function SectionTitle({ children, right }: { children: ReactNode; right?: ReactNode }) {
  return <div className="sec-t"><span>{children}</span>{right}</div>
}

export const hm = (ms: number) => {
  const h = Math.floor(ms / 36e5), d = Math.floor(h / 24)
  return { d, h: h % 24, m: Math.floor((ms % 36e5) / 6e4) }
}
export const clockStr = (t: number) => new Date(t).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' }).replace(/\s?[AP]M$/, '')

// Dialogs opened from inside a scrolling tab render on top of the whole app, not the scrolled page.
export function Layer({ children }: { children: ReactNode }) {
  const el = document.getElementById('app-layer')
  return el ? createPortal(children, el) : null
}
