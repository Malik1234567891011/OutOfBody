import SwiftUI

// MARK: - SVG path data → Path (M L H V C S A Z, absolute + relative), for the prototype's icons verbatim.

enum SVG {
    static func path(_ d: String) -> Path {
        var p = Path()
        let chars = Array(d)
        var i = 0
        var cur = CGPoint.zero, start = CGPoint.zero, lastCtrl: CGPoint?
        var cmd: Character = "M"
        func skip() { while i < chars.count, chars[i] == " " || chars[i] == "," || chars[i] == "\n" { i += 1 } }
        func num() -> CGFloat {
            skip()
            var s = ""
            if i < chars.count, chars[i] == "-" || chars[i] == "+" { s.append(chars[i]); i += 1 }
            var dot = false
            while i < chars.count {
                let c = chars[i]
                if c.isNumber { s.append(c); i += 1 }
                else if c == ".", !dot { dot = true; s.append(c); i += 1 }
                else { break }
            }
            return CGFloat(Double(s) ?? 0)
        }
        func flag() -> Bool { skip(); let c = chars[i]; i += 1; return c == "1" }
        func hasNum() -> Bool { skip(); return i < chars.count && (chars[i].isNumber || chars[i] == "-" || chars[i] == "." || chars[i] == "+") }
        while true {
            skip()
            guard i < chars.count else { break }
            if chars[i].isLetter { cmd = chars[i]; i += 1 }
            let rel = cmd.isLowercase
            let o = rel ? cur : .zero
            switch cmd.uppercased() {
            case "M":
                cur = CGPoint(x: o.x + num(), y: o.y + num()); start = cur; p.move(to: cur); lastCtrl = nil
                cmd = rel ? "l" : "L"
            case "L": cur = CGPoint(x: o.x + num(), y: o.y + num()); p.addLine(to: cur); lastCtrl = nil
            case "H": cur.x = (rel ? cur.x : 0) + num(); p.addLine(to: cur); lastCtrl = nil
            case "V": cur.y = (rel ? cur.y : 0) + num(); p.addLine(to: cur); lastCtrl = nil
            case "C":
                let c1 = CGPoint(x: o.x + num(), y: o.y + num()), c2 = CGPoint(x: o.x + num(), y: o.y + num())
                cur = CGPoint(x: o.x + num(), y: o.y + num())
                p.addCurve(to: cur, control1: c1, control2: c2); lastCtrl = c2
            case "S":
                let c1 = lastCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = CGPoint(x: o.x + num(), y: o.y + num())
                cur = CGPoint(x: o.x + num(), y: o.y + num())
                p.addCurve(to: cur, control1: c1, control2: c2); lastCtrl = c2
            case "A":
                let rx = num(), ry = num(), rot = num(), large = flag(), sweep = flag()
                let to = CGPoint(x: o.x + num(), y: o.y + num())
                arc(&p, cur, to, rx, ry, rot, large, sweep)
                cur = to; lastCtrl = nil
            case "Z":
                p.closeSubpath(); cur = start; lastCtrl = nil
                if !hasNum() { continue }
            default: i += 1
            }
            if cmd.uppercased() == "Z" { continue }
            if !hasNum() { continue }
        }
        return p
    }

    /// SVG elliptical arc → cubic béziers (endpoint → center parameterization, SVG spec F.6).
    private static func arc(_ p: inout Path, _ p0: CGPoint, _ p1: CGPoint, _ rx0: CGFloat, _ ry0: CGFloat, _ deg: CGFloat, _ large: Bool, _ sweep: Bool) {
        var rx = abs(rx0), ry = abs(ry0)
        if rx == 0 || ry == 0 || p0 == p1 { p.addLine(to: p1); return }
        let phi = deg * .pi / 180, cp = cos(phi), sp = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1 = cp * dx + sp * dy, y1 = -sp * dx + cp * dy
        let lam = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lam > 1 { rx *= sqrt(lam); ry *= sqrt(lam) }
        let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var k = sqrt(max(0, num / den))
        if large == sweep { k = -k }
        let cxp = k * rx * y1 / ry, cyp = -k * ry * x1 / rx
        let cx = cp * cxp - sp * cyp + (p0.x + p1.x) / 2, cy = sp * cxp + cp * cyp + (p0.y + p1.y) / 2
        func ang(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat { atan2(ux * vy - uy * vx, ux * vx + uy * vy) }
        let t1 = ang(1, 0, (x1 - cxp) / rx, (y1 - cyp) / ry)
        var dt = ang((x1 - cxp) / rx, (y1 - cyp) / ry, (-x1 - cxp) / rx, (-y1 - cyp) / ry)
        if !sweep && dt > 0 { dt -= 2 * .pi } else if sweep && dt < 0 { dt += 2 * .pi }
        let segs = max(1, Int(ceil(abs(dt) / (.pi / 2))))
        let step = dt / CGFloat(segs)
        let kk = 4.0 / 3.0 * tan(step / 4)
        func pt(_ t: CGFloat) -> CGPoint { CGPoint(x: cx + rx * cos(t) * cp - ry * sin(t) * sp, y: cy + rx * cos(t) * sp + ry * sin(t) * cp) }
        func der(_ t: CGFloat) -> CGPoint { CGPoint(x: -rx * sin(t) * cp - ry * cos(t) * sp, y: -rx * sin(t) * sp + ry * cos(t) * cp) }
        var t = t1
        for _ in 0..<segs {
            let a = pt(t), b = pt(t + step), da = der(t), db = der(t + step)
            p.addCurve(to: b, control1: CGPoint(x: a.x + kk * da.x, y: a.y + kk * da.y), control2: CGPoint(x: b.x - kk * db.x, y: b.y - kk * db.y))
            t += step
        }
    }
}

/// App icons from web/src/ui.tsx that the onboarding port didn't need, as their SVG markup.
let APP_ICONS: [String: [String]] = [
    "wind": ["M3 9h11a3 3 0 10-3-3M3 15h15a3 3 0 11-3 3M3 12h7"],
    "shield": ["M12 3l7.5 3v5.5c0 4.5-3.2 8.2-7.5 9.5-4.3-1.3-7.5-5-7.5-9.5V6z", "M8.8 12l2.2 2.2 4.4-4.4"],
    "chart": ["M4 20V10M10 20V4M16 20v-7M22 20H2"],
    "today": ["M20.5 12a8.5 8.5 0 10-17 0a8.5 8.5 0 1017 0"],
    "you": ["M15.8 8.5a3.8 3.8 0 10-7.6 0a3.8 3.8 0 107.6 0", "M4.5 20.5c1-3.8 4-5.8 7.5-5.8s6.5 2 7.5 5.8"],
    "plus": ["M12 5v14M5 12h14"],
    "flag": ["M5 21V4M5 4h11l-2 4 2 4H5"],
    "widget": ["M5.5 3.5h3a2 2 0 012 2v3a2 2 0 01-2 2h-3a2 2 0 01-2-2v-3a2 2 0 012-2z", "M17 3.5a3.5 3.5 0 110 7 3.5 3.5 0 110-7z", "M5.5 13.5h13a2 2 0 012 2v3a2 2 0 01-2 2h-13a2 2 0 01-2-2v-3a2 2 0 012-2z"],
    "book": ["M4 5.5A2 2 0 016 3.5h13v15H6a2 2 0 00-2 2z", "M4 20.5V5.5M8 8h7"],
    "pen": ["M4 20l4-1 11-11-3-3L5 16z", "M14 7l3 3"],
    "sun": ["M16 12a4 4 0 10-8 0a4 4 0 108 0", "M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"],
    "moon": ["M19.5 14.5A8 8 0 019.5 4.5a8 8 0 1010 10z"],
    "chev": ["M9 5l7 7-7 7"],
    "trash": ["M4.5 7h15M9.5 7V4.5h5V7M6.5 7l1 13h9l1-13"],
    "leaf": ["M5 19C5 10 10 5 20 4c0 10-5 15-14 15z", "M5 19l8-8"],
    "heart": ["M12 20s-7.5-4.6-7.5-10A4.3 4.3 0 0112 7.3 4.3 4.3 0 0119.5 10c0 5.4-7.5 10-7.5 10z"],
    "clock": ["M20.5 12a8.5 8.5 0 10-17 0a8.5 8.5 0 1017 0", "M12 7.5V12l3 2"],
    "refresh": ["M19.5 12a7.5 7.5 0 11-2.2-5.3M19.5 4.5v4h-4"],
]

struct AppIcon: View {
    let name: String
    var size: CGFloat = 22
    var body: some View {
        if let paths = APP_ICONS[name] {
            let s = size / 24
            let lw: CGFloat = name == "plus" ? 2.4 : 1.8
            ZStack {
                ForEach(Array(paths.enumerated()), id: \.offset) { _, d in
                    SVGShape(d: d).stroke(style: StrokeStyle(lineWidth: lw * s, lineCap: .round, lineJoin: .round))
                }
                if name == "today" {
                    SVGShape(d: "M12 3.5a8.5 8.5 0 018.5 8.5").stroke(style: StrokeStyle(lineWidth: 3 * s, lineCap: .round))
                }
            }
            .frame(width: size, height: size)
        } else {
            Icon(name: name, size: size)
        }
    }
}

struct SVGShape: Shape {
    let d: String
    var viewBox: CGFloat = 24
    func path(in rect: CGRect) -> Path {
        let s = rect.width / viewBox
        return SVG.path(d).applying(CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: s, y: s))
    }
}

// MARK: - CSS cubic-bezier timing (for confetti, ring, etc.)

func cubicBezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ x: Double) -> Double {
    if x <= 0 { return 0 }; if x >= 1 { return 1 }
    func bx(_ t: Double) -> Double { 3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t }
    func by(_ t: Double) -> Double { 3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t * y2 + t * t * t }
    var lo = 0.0, hi = 1.0, t = x
    for _ in 0..<40 { t = (lo + hi) / 2; if bx(t) < x { lo = t } else { hi = t } }
    return by(t)
}

// MARK: - Ring (`Ring` in bits.tsx): frac = share of the arc drawn

struct Ring<Content: View>: View {
    let size: CGFloat
    let stroke: CGFloat
    let frac: Double
    let color: Color
    var track: Color = .white.opacity(0.08)
    var glow = false
    @ViewBuilder var content: Content
    var body: some View {
        let f = max(0, min(1, frac))
        let r = (size - stroke) / 2
        ZStack {
            if glow {
                Circle().stroke(color, lineWidth: stroke).frame(width: 2 * r, height: 2 * r).opacity(0.12).blur(radius: 10)
            }
            Circle().stroke(track, lineWidth: stroke).frame(width: 2 * r, height: 2 * r)
            Circle().trim(from: 0, to: f)
                .stroke(color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 2 * r, height: 2 * r)
                .opacity(f == 0 ? 0 : 1)
                .animation(Env.still ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.6), value: f)
                .animation(.easeInOut(duration: 0.3), value: color)
            VStack(spacing: 0) { content }.multilineTextAlignment(.center)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Confetti (bits.tsx): `around` = a tight burst that stays around an icon

private let CONF_COLORS: [Color] = [Color(hex: 0x4FE3B8), Color(hex: 0xFFB547), Color(hex: 0xFF6B6B), Color(hex: 0x8FD3FF), Color(hex: 0xF3F5F9), Color(hex: 0xC9A7FF)]

struct Confetti: View {
    var n = 36
    var top: CGFloat = 160
    var spread: CGFloat = 1
    var around = false
    @State private var t0 = Date()
    struct Bit { let dx, dy, r: CGFloat; let c: Color; let w: CGFloat; let delay: Double }
    var bits: [Bit] {
        (0..<n).map { i in
            let ang = Double(i) / Double(n) * .pi * 2 + Double(i % 3) * 0.3
            let dist = Double(90 + ((i * 37) % 110)) * spread
            let dx = cos(ang) * dist * (around ? 1.1 : 1.25)
            let dy = around ? sin(ang) * dist * (sin(ang) < 0 ? 0.6 : 0.2) - 24 * spread : sin(ang) * dist * 0.75 + 60
            return Bit(dx: dx, dy: dy, r: CGFloat((i * 73) % 360), c: CONF_COLORS[i % CONF_COLORS.count], w: CGFloat(6 + (i % 3) * 2), delay: Double(i % 6) * 0.025)
        }
    }
    var body: some View {
        GeometryReader { g in
            TimelineView(.animation(paused: Env.still)) { ctx in
                let el = Env.still ? 0.38 : ctx.date.timeIntervalSince(t0)
                ZStack(alignment: .topLeading) {
                    ForEach(Array(bits.enumerated()), id: \.offset) { _, b in
                        let e = Env.still ? 0.38 : el - b.delay
                        let k = max(0, min(1, e / 1.4))
                        let p = cubicBezier(0.15, 0.7, 0.3, 1, k)
                        let op = e < 0 ? 1 : k <= 0.75 ? 1 : 1 - cubicBezier(0.15, 0.7, 0.3, 1, (k - 0.75) / 0.25)
                        RoundedRectangle(cornerRadius: 2).fill(b.c)
                            .frame(width: b.w, height: b.w * 0.45)
                            .rotationEffect(.degrees(Double(b.r) * 3 * p))
                            .position(x: g.size.width / 2 + b.w / 2 + b.dx * p, y: top + b.w * 0.225 + b.dy * p)
                            .opacity(op)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { t0 = Date() }
    }
}

// MARK: - Toggle (iOS-style switch, `.toggle`)

struct OOBToggle: View {
    let on: Bool
    let change: (Bool) -> Void
    var body: some View {
        Button { haptic(8); change(!on) } label: {
            ZStack(alignment: .leading) {
                Capsule().fill(on ? T.accent : Color(hex: 0x39404E)).frame(width: 51, height: 31)
                Circle().fill(.white).frame(width: 27, height: 27).shadow(color: .black.opacity(0.3), radius: 2, y: 2)
                    .offset(x: on ? 22 : 2)
            }
            .animation(.easeInOut(duration: 0.2), value: on)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Full-screen sheet over the tabs (SOS, review, welcome…)

struct SheetBox<Content: View, Bottom: View>: View {
    var calm = false
    var top: CGFloat = 56
    var onClose: (() -> Void)?
    @ViewBuilder var content: Content
    @ViewBuilder var bottom: Bottom
    var body: some View {
        ZStack(alignment: .top) {
            if calm {
                GeometryReader { g in
                    EllipticalGradient(stops: [.init(color: Color(hex: 0x0E2526), location: 0), .init(color: T.bg, location: 0.62)],
                                       center: UnitPoint(x: 0.5, y: 0.28), startRadiusFraction: 0, endRadiusFraction: 1)
                        .frame(width: g.size.width * 1.3 * 2 / 1.0, height: g.size.height * 0.7 * 2)
                        .position(x: g.size.width / 2, y: g.size.height * 0.28)
                }
                .background(T.bg)
            } else {
                T.bg
            }
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(.top, top).padding(.horizontal, 22)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 10) { bottom }
                    .padding(.top, 22).padding(.horizontal, 22).padding(.bottom, 36)
                    .frame(maxWidth: .infinity)
                    .background(VStack(spacing: 0) {
                        LinearGradient(colors: [T.bgA(0), T.bg], startPoint: .top, endPoint: .bottom).frame(height: 24)
                        T.bg
                    }.opacity(calm ? 0 : 1))
            }
            if let onClose {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Icon(name: "close").foregroundStyle(T.text).frame(width: 40, height: 40)
                            .background(Circle().fill(.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
                .padding(.top, 54).padding(.trailing, 12)
            }
        }
        .ignoresSafeArea()
    }
}

/// `.cta` variants used in the app.
struct AppCTA: View {
    enum Kind { case primary, ghost }
    let title: String
    var kind: Kind = .primary
    var height: CGFloat = 58
    var font: CGFloat = 17.5
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(sf(font, 650)).tracking(-0.2)
                .foregroundStyle(kind == .primary ? T.accentInk : T.text)
                .frame(maxWidth: .infinity).frame(height: height)
                .background(Capsule().fill(kind == .primary ? T.accent : T.surface2))
                .contentShape(Capsule())
        }
        .buttonStyle(PressScale(scale: 0.98))
    }
}

struct LinkButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) { Text(title).font(sf(15)).foregroundStyle(T.muted).padding(6).frame(maxWidth: .infinity) }
            .buttonStyle(.plain)
            .padding(.top, 2)
    }
}

/// Small pill CTA (`.cta.xs`)
struct XSButton: View {
    let title: String
    var disabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(sf(14, 650)).foregroundStyle(disabled ? Color(hex: 0x556666) : T.accentInk)
                .padding(.horizontal, 16).frame(height: 36)
                .background(Capsule().fill(disabled ? T.surface2 : T.accent))
        }
        .buttonStyle(.plain).disabled(disabled)
    }
}

// MARK: - Their pledge signature, or a drawn stand-in for scenarios that never signed on this device

struct SignatureView: View {
    let file: String?
    var body: some View {
        if let file, let img = UIImage(contentsOfFile: AppGroup.url.appendingPathComponent(file).path) {
            Image(uiImage: img).resizable().scaledToFit().frame(height: 92)
        } else {
            ZStack {
                SVGShape(d: "M28 82c10-30 22-52 30-50 9 2-6 44-2 46 6 3 16-40 26-39 8 1-2 34 5 35 8 1 12-20 20-21 7-1 3 16 10 16 9 0 13-22 22-21 6 1 2 14 8 14 10-1 14-30 22-44 4-7 8-4 5 6-5 17-14 38-9 39 7 2 15-16 24-16 8 0 2 13 10 13 12 0 20-12 34-14 12-2 30 2 48-4", viewBox: 340)
                    .stroke(Color(hex: 0x0B0F17), style: StrokeStyle(lineWidth: 4 * 92 / 120, lineCap: .round, lineJoin: .round))
                SVGShape(d: "M40 96c60-6 140-8 250-4", viewBox: 340)
                    .stroke(Color(hex: 0x0B0F17).opacity(0.55), style: StrokeStyle(lineWidth: 2.5 * 92 / 120, lineCap: .round))
            }
            .frame(width: 340 * 92 / 120, height: 92)
        }
    }
}

struct SectionTitle<Right: View>: View {
    let text: String
    @ViewBuilder var right: Right
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text).font(sf(18.5, 720)).tracking(-0.3).foregroundStyle(T.text)
            Spacer()
            right
        }
        .padding(.top, 24).padding(.bottom, 10).padding(.horizontal, 2)
    }
}
extension SectionTitle where Right == EmptyView {
    init(_ text: String) { self.text = text; self.right = EmptyView() }
}

/// `.card` with the app's default 20 radius
extension View {
    func card(_ pad: EdgeInsets = EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18), radius: CGFloat = 20) -> some View {
        self.padding(pad).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: radius).fill(T.surface))
    }
}

func hm(_ ms: Double) -> (d: Int, h: Int, m: Int) {
    let h = Int(floor(ms / 36e5))
    return (h / 24, h % 24, Int(floor(ms.truncatingRemainder(dividingBy: 36e5) / 6e4)))
}

/// The check circle used in the setup, milestone and "what's changing" lists.
struct CheckDot: View {
    let done: Bool
    var accentBorder = false
    var body: some View {
        ZStack {
            Circle().fill(done ? T.accent : .clear)
            Circle().strokeBorder(done || accentBorder ? T.accent : Color(hex: 0x333B4B), lineWidth: 1.5)
            if done { Icon(name: "check", size: 13).foregroundStyle(T.accentInk) }
        }
        .frame(width: 22, height: 22)
    }
}
