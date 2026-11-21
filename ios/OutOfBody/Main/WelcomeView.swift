import SwiftUI

/// CSS keyframes: value at time fraction p (0…1) with `ease` between stops.
func keyframes(_ p: Double, _ ks: [(Double, Double)]) -> Double {
    guard let first = ks.first else { return 0 }
    if p <= first.0 { return first.1 }
    for i in 0..<(ks.count - 1) where p >= ks[i].0 && p <= ks[i + 1].0 {
        let span = ks[i + 1].0 - ks[i].0
        let k = span <= 0 ? 1 : cubicBezier(0.25, 0.1, 0.25, 1, (p - ks[i].0) / span)
        return ks[i].1 + (ks[i + 1].1 - ks[i].1) * k
    }
    return ks.last!.1
}

struct WelcomeView: View {
    @EnvironmentObject var m: AppModel
    @State var step: Int
    @State private var guide = false
    var body: some View {
        let d = m.d
        let name = m.s.answers.name
        if guide {
            WidgetGuideView(onDone: { guide = false; step = 5 })
        } else {
            SheetBox(top: 54) {
                ZStack(alignment: .top) {
                    stepView(d, name).id(step)
                        .transition(.asymmetric(insertion: .offset(x: 40).combined(with: .opacity), removal: .identity))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } bottom: {
                if step < 4 { AppCTA(title: "Continue") { next() } }
                if step == 4 {
                    AppCTA(title: "Show me how") { Analytics.track("widget_guide_opened", ["from": "welcome"]); guide = true }
                    LinkButton(title: "I'll do it later") { next() }
                }
                if step == 5 {
                    AppCTA(title: "I'm in for today") {
                        haptic(24)
                        let k = dayKey(d.t)
                        m.update { x in
                            x.welcomed = true
                            x.checkins.removeAll { $0.date == k && $0.kind == .morning }
                            x.checkins.append(CheckIn(date: k, kind: .morning))
                        }
                        Analytics.track("checkin_completed", ["kind": "morning", "from": "welcome"])
                        m.open(nil)
                    }
                }
            }
            .onAppear { Analytics.track("welcome_step_viewed", ["step": step]) }
            .onChange(of: step) { _, s in Analytics.track("welcome_step_viewed", ["step": s]) }
        }
    }

    func next() { haptic(8); withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.32)) { step += 1 } }

    var dots: some View {
        HStack(spacing: 6) {
            ForEach(2...5, id: \.self) { i in
                Capsule().fill(i == step ? T.accent : i < step ? T.accentA(0.4) : T.line).frame(width: 22, height: 5)
            }
        }
        .frame(maxWidth: .infinity).padding(.top, 14)
    }

    @ViewBuilder func stepView(_ d: Derived, _ name: String?) -> some View {
        switch step {
        case 1:
            ZStack(alignment: .top) {
                BreathOrb(size: 340).opacity(0.7).position(x: (UIScreen.main.bounds.width - 44) / 2, y: 222)
                Confetti(n: 44, top: 222, spread: 0.75, around: true)
                VStack(spacing: 0) {
                    Icon(name: "check", size: 44).foregroundStyle(T.accentInk)
                        .frame(width: 92, height: 92).background(Circle().fill(T.accent).shadow(color: T.accentA(0.45), radius: 35))
                        .padding(.bottom, 28)
                    Text("You're in\(name.map { ", \($0)" } ?? "").").font(sf(40, 750)).tracking(-1.2).foregroundStyle(T.text).multilineTextAlignment(.center).padding(.bottom, 4)
                    SubText(text: "Your plan starts today. Here's how it works.", align: .center).padding(.top, 10)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 186)
            }
        case 2:
            VStack(alignment: .leading, spacing: 0) {
                dots
                TitleText(text: "How a day works").padding(.top, 30)
                VStack(spacing: 12) {
                    wrow(1, "plus", "Tap every time you pick it up", "From the lock screen widget or the app. One tap, no unlocking.")
                    wrow(2, "today", "Stay under today's budget", "It starts at \(d.budget) \(d.unitWord(d.budget)) and gets smaller every week.")
                    wrow(3, "wind", "Hit SOS when a craving hits", "Breathe with us for 90 seconds. Most cravings pass in minutes.", danger: true)
                }
                .padding(.top, 22)
            }
        case 3:
            VStack(alignment: .leading, spacing: 0) {
                dots
                TitleText(text: "Some days will be easy. Some won't.").padding(.top, 30)
                SubText(text: "Going over isn't failure; it's data. We adjust, you keep going.").padding(.top, 10).padding(.bottom, 22)
                Bumps(budget: d.budget)
            }
        case 4:
            VStack(alignment: .leading, spacing: 0) {
                dots
                TitleText(text: "Add the widget.\nIt's the whole habit.").padding(.top, 30)
                SubText(text: "Seeing the number every time you pick up your phone is half the work.").padding(.top, 10).padding(.bottom, 22)
                LockAnim()
            }
        default:
            VStack(spacing: 0) {
                dots
                VStack(spacing: 0) {
                    Eyebrow(text: "Day 1 · your first commitment").padding(.top, 0)
                    Text("Today's budget").font(sf(30, 700)).tracking(-0.6).foregroundStyle(T.text).padding(.top, 4).padding(.bottom, 22)
                    Ring(size: 210, stroke: 16, frac: 1, color: T.accent, glow: true) {
                        Text("\(d.budget)").font(sf(80, 780)).tracking(-3).monospacedDigit().foregroundStyle(T.text).frame(height: 76)
                        Text("\(d.unitWord(d.budget)) today").font(sf(15.5, 500)).foregroundStyle(T.muted).padding(.top, 6)
                    }
                    SubText(text: "Down from about \(d.startAmt) a day. Log each one and stay under it. That's all today asks.", align: .center)
                        .frame(maxWidth: 300).padding(.top, 22)
                }
                .padding(.top, 70)
            }
            .frame(maxWidth: .infinity)
        }
    }

    func wrow(_ n: Int, _ icon: String, _ t: String, _ dd: String, danger: Bool = false) -> some View {
        HStack(spacing: 16) {
            ZStack(alignment: .topLeading) {
                AppIcon(name: icon, size: 22).foregroundStyle(danger ? T.danger : T.accent)
                    .frame(width: 50, height: 50)
                    .background(RoundedRectangle(cornerRadius: 15).fill(danger ? T.dangerA(0.13) : T.accentSoft))
                Text("\(n)").font(sf(12, 800)).foregroundStyle(danger ? .white : T.accentInk)
                    .frame(width: 21, height: 21).background(Circle().fill(danger ? T.danger : T.accent))
                    .offset(x: -6, y: -6)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(t).font(sf(17, 680)).tracking(-0.2).foregroundStyle(T.text)
                Text(dd).font(sf(14)).lineSpacing(lh(14, 1.38)).foregroundStyle(T.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 18).padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 20).fill(T.surface))
    }
}

/// A week that wobbles but trends down; two days go over the line, and that's fine.
struct Bumps: View {
    let budget: Int
    var body: some View {
        let vals = [0.92, 1.12, 0.85, 0.95, 1.18, 0.8, 0.74]
        VStack(spacing: 8) {
            GeometryReader { g in
                let Wd = g.size.width, s = Wd / 320, H = 170 * s, mx = 1.3
                let ly = H - (1 / mx) * H
                ZStack(alignment: .topLeading) {
                    Path { p in p.move(to: CGPoint(x: 0, y: ly)); p.addLine(to: CGPoint(x: Wd, y: ly)) }
                        .stroke(T.muted, style: StrokeStyle(lineWidth: 1.5 * s, dash: [5 * s, 5 * s]))
                    Text("budget \(budget)").font(sf(11 * s, 600)).foregroundStyle(T.muted)
                        .position(x: Wd - 30 * s, y: ly - 12 * s)
                    ForEach(0..<7, id: \.self) { i in
                        let v = vals[i], x = (14 + Double(i) * (320 - 28) / 6) * s, h = v / mx * H
                        RoundedRectangle(cornerRadius: 8 * s).fill(v > 1 ? T.warn : T.accent).opacity(v > 1 ? 0.9 : 0.85)
                            .frame(width: 30 * s, height: h).position(x: x, y: H - h / 2)
                        Text(["M", "T", "W", "T", "F", "S", "S"][i]).font(sf(11 * s)).foregroundStyle(T.muted).position(x: x, y: H + 16 * s)
                    }
                }
            }
            .aspectRatio(320 / 196, contentMode: .fit)
            HStack(spacing: 18) {
                legend(T.accent, "Under"); legend(T.warn, "Over: still a good week")
            }
        }
        .padding(EdgeInsets(top: 18, leading: 14, bottom: 12, trailing: 14))
        .background(RoundedRectangle(cornerRadius: 20).fill(T.surface))
    }
    func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 6) { RoundedRectangle(cornerRadius: 3).fill(c).frame(width: 10, height: 10); Text(t).font(sf(13)).foregroundStyle(T.muted) }
    }
}

let LOCK_GRADIENT = LinearGradient(stops: [.init(color: Color(hex: 0x1D3B4A), location: 0), .init(color: Color(hex: 0x0F2030), location: 0.45), .init(color: Color(hex: 0x2B1830), location: 1)],
                                   startPoint: UnitPoint(x: 0.33, y: 0), endPoint: UnitPoint(x: 0.67, y: 1))

struct WidgetDemo: View {
    var left = 14
    var body: some View {
        HStack(spacing: 10) {
            Ring(size: 40, stroke: 5, frac: 0.6, color: .white, track: .white.opacity(0.25)) {
                Text("\(left)").font(sf(13, 750)).monospacedDigit().foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("\(left) left").font(sf(17, 700)).monospacedDigit().foregroundStyle(.white)
                Text("tap to log").font(sf(12.5)).foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(.leading, 9).padding(.trailing, 16).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 20).fill(.white.opacity(0.15)))
    }
}

struct LockAnim: View {
    @State private var t0 = Date()
    var body: some View {
        TimelineView(.animation(paused: Env.still)) { ctx in
            let p = Env.still ? -1 : (ctx.date.timeIntervalSince(t0).truncatingRemainder(dividingBy: 7)) / 7
            let still = p < 0
            let scale = still ? 0.86 : keyframes(p, [(0, 1), (0.24, 1), (0.32, 0.86), (0.92, 0.86), (1, 1)])
            let press = still ? 0 : keyframes(p, [(0, 0), (0.06, 0), (0.12, 1), (0.22, 1), (0.28, 0), (1, 0)])
            let pressScale = still ? 1 : keyframes(p, [(0, 0.4), (0.06, 0.4), (0.12, 1), (0.22, 1), (0.28, 1.2), (1, 1.2)])
            let cust = still ? 1 : keyframes(p, [(0, 0), (0.28, 0), (0.34, 1), (0.90, 1), (0.96, 0), (1, 0)])
            let slot = still ? 0 : keyframes(p, [(0, 0), (0.40, 0), (0.46, 0.6), (0.60, 0.6), (0.66, 0), (1, 0)])
            let wOp = still ? 1 : keyframes(p, [(0, 0), (0.58, 0), (0.66, 1), (0.92, 1), (1, 0)])
            let wK = still ? 1 : keyframes(p, [(0, 0), (0.58, 0), (0.66, 1), (1, 1)])
            let cap = still ? 2 : (p < 0.29 ? 0 : p < 0.59 ? 1 : p < 0.98 ? 2 : -1)
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(sf(16, 600)).foregroundStyle(.white.opacity(0.85)).padding(.top, 26)
                    Text("9:41").font(sf(86, 600)).tracking(-2).foregroundStyle(.white.opacity(0.95)).frame(height: 86)
                    WidgetDemo()
                        .opacity(wOp).scaleEffect(0.9 + 0.1 * wK).offset(y: 10 * (1 - wK))
                        .frame(width: 250, height: 66)
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4])).foregroundStyle(.white.opacity(slot)))
                        .padding(.top, 22)
                    Spacer()
                }
                .frame(maxWidth: .infinity).frame(height: 366)
                .background(LOCK_GRADIENT)
                .overlay {
                    GeometryReader { g in
                        Circle().fill(.white.opacity(0.3)).frame(width: 74, height: 74)
                            .background(Circle().stroke(.white.opacity(0.08), lineWidth: 20))
                            .scaleEffect(pressScale).opacity(press)
                            .position(x: g.size.width / 2, y: g.size.height * 0.62)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .scaleEffect(scale, anchor: UnitPoint(x: 0.5, y: 0.4))
                Text("Customize").font(sf(15, 650)).foregroundStyle(.black)
                    .padding(.horizontal, 26).padding(.vertical, 10)
                    .background(Capsule().fill(.white))
                    .opacity(cust)
                    .position(x: (UIScreen.main.bounds.width - 44) / 2, y: 410 - 62 - 19)
                HStack(spacing: 8) {
                    ForEach(Array(["Long-press", "Customize", "Add OutOfBody"].enumerated()), id: \.offset) { i, c in
                        Text(c).font(sf(13, 650)).foregroundStyle(i == cap ? T.accentInk : T.muted)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 14).fill(i == cap ? T.accent : T.surface))
                    }
                }
                .frame(maxWidth: .infinity)
                .position(x: (UIScreen.main.bounds.width - 44) / 2, y: 410 - 4 - 15)
            }
            .frame(height: 410)
            .padding(.horizontal, -4)
        }
        .onAppear { t0 = Date() }
    }
}

struct WidgetGuideView: View {
    @EnvironmentObject var m: AppModel
    var onDone: (() -> Void)?
    var body: some View {
        let d = m.d
        SheetBox(top: 56, onClose: onDone == nil ? { m.open(nil) } : nil) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(text: "Lock-screen widget").padding(.top, 6)
                    TitleText(text: "Three taps to set it up").padding(.bottom, 18)
                    VStack(spacing: 10) {
                        gstep(1, "Long-press your lock screen", "Unlock with Face ID first, but stay on the lock screen.")
                        gstep(2, "Tap Customize, then Lock Screen", "Then tap the box under the clock.")
                        gstep(3, "Pick OutOfBody", "Choose the ring or the “left · tap to log” widget.")
                    }
                    VStack(spacing: 0) {
                        Text("9:41").font(sf(66, 600)).tracking(-2).foregroundStyle(.white.opacity(0.95)).frame(height: 66)
                        HStack(spacing: 10) {
                            Ring(size: 52, stroke: 6, frac: 0.6, color: .white, track: .white.opacity(0.25)) {
                                Text("14").font(sf(13, 750)).foregroundStyle(.white)
                            }
                            .frame(width: 62, height: 62).background(Circle().fill(.white.opacity(0.15)))
                            WidgetDemo()
                        }
                        .padding(.top, 14)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18).padding(.horizontal, 16).padding(.bottom, 22)
                    .background(RoundedRectangle(cornerRadius: 24).fill(LOCK_GRADIENT))
                    .padding(.top, 16)
                    Fine(text: "Tapping it logs a \(d.one). No unlocking, no app to open.").frame(maxWidth: .infinity).padding(.top, 10)
                }
                .padding(.bottom, 150)
            }
            .padding(.horizontal, -22).contentMargins(.horizontal, 22, for: .scrollContent)
        } bottom: {
            AppCTA(title: "I added it") {
                m.markSetup(\.widget, "widget")
                haptic(14)
                if let onDone { onDone() } else { m.open(nil); m.showToast("Widget added. Tap it each time.") }
            }
            if let onDone { LinkButton(title: "Skip for now") { onDone() } }
        }
    }
    func gstep(_ n: Int, _ t: String, _ dd: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(n)").font(sf(15, 800)).foregroundStyle(T.accentInk).frame(width: 30, height: 30).background(Circle().fill(T.accent))
            VStack(alignment: .leading, spacing: 3) {
                Text(t).font(sf(16.5, 660)).foregroundStyle(T.text).padding(.top, 4)
                Text(dd).font(sf(14)).lineSpacing(lh(14, 1.35)).foregroundStyle(T.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 15).padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 18).fill(T.surface))
    }
}
