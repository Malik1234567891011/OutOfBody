import SwiftUI

private let TOTAL = 90.0
private let SKIP_AFTER = 20.0
/// in 4 · hold 4 · out 6
private func phaseAt(_ t: Double) -> (ph: String, left: Double, label: String) {
    let p = t.truncatingRemainder(dividingBy: 14)
    if p < 4 { return ("in", 4 - p, "Breathe in") }
    if p < 8 { return ("hold", 8 - p, "Hold") }
    return ("out", 14 - p, "Breathe out")
}
private func ease(_ x: Double) -> Double { 0.5 - cos(.pi * max(0, min(1, x))) / 2 }

struct SosGlow: View {
    @State private var on = false
    var body: some View {
        Circle()
            .fill(RadialGradient(stops: [.init(color: T.accentA(0.22), location: 0), .init(color: T.accentA(0), location: 0.65)], center: .center, startRadius: 0, endRadius: 210))
            .frame(width: 420, height: 420)
            .scaleEffect(Env.still ? 0.82 : (on ? 1.06 : 0.82)).opacity(Env.still ? 0.75 : (on ? 1 : 0.75))
            .position(x: UIScreen.main.bounds.width / 2, y: 330)
            .allowsHitTesting(false)
            .onAppear { if !Env.still { withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) { on = true } } }
    }
}

struct SosView: View {
    @EnvironmentObject var m: AppModel
    @State var step: SosStep
    @State private var method: Craving.Method = .breathe
    @State private var round = 0

    func close() { m.open(nil) }
    func markTried() { m.markSetup(\.sos, "sos") }
    func go(_ s: SosStep) { withAnimation(.easeOut(duration: 0.25)) { step = s } }

    var body: some View {
        let d = m.d
        let reason = m.s.reasons.first ?? "Get my day back"
        ZStack {
            switch step {
            case .interrupt:
                SheetBox(calm: true, onClose: close) {
                    ZStack(alignment: .top) {
                        SosGlow().padding(.horizontal, -22).padding(.top, -56)
                        VStack(alignment: .leading, spacing: 0) {
                            Eyebrow(text: "Craving SOS").frame(maxWidth: .infinity).padding(.top, -12)
                            Text("Breathe. This craving will pass in a few minutes.").font(sf(31, 760)).tracking(-0.8).lineSpacing(-2)
                                .foregroundStyle(T.text).fixedSize(horizontal: false, vertical: true).padding(.top, 6)
                            VStack(alignment: .leading, spacing: 0) {
                                Text("YOUR #1 REASON").font(sf(12.5, 700)).tracking(0.6).foregroundStyle(T.accent)
                                Text("\"\(reason)\"").font(sf(27, 720)).tracking(-0.5).foregroundStyle(T.text).padding(.top, 10).fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 22).padding(.horizontal, 20)
                            .background(RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.04)).overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(T.accentA(0.22), lineWidth: 1)))
                            .padding(.top, 36)
                        }
                        .padding(.top, 96)
                    }
                } bottom: {
                    AppCTA(title: "Breathe with me") { haptic(14); method = .breathe; Analytics.track("sos_breathe_started"); go(.breathe) }
                    AppCTA(title: "Read my reasons", kind: .ghost) { method = .reasons; go(.reasons) }
                    LinkButton(title: "I'm going to vape anyway") { go(.anyway) }
                }
            case .breathe:
                BreatheView(onDone: { completed in
                    if completed { Analytics.track("sos_breathe_completed") }
                    markTried(); go(.pass)
                }, onClose: close).id(round)
            case .pass:
                midSheet(close: close, orb: AnyView(passOrb("wind", soft: false)), title: "Did it pass?", sub: "Be honest. Either answer is fine.") {
                    AppCTA(title: "Yes, it passed") {
                        haptic(30); markTried()
                        m.update { $0.cravings.append(Craving(id: uid(), at: now(), outcome: .beaten, method: method)) }
                        Analytics.track("craving_outcome", ["outcome": "beaten", "method": method.rawValue])
                        go(.win)
                    }
                    AppCTA(title: "Not yet", kind: .ghost) { Analytics.track("craving_outcome", ["outcome": "not_yet", "method": method.rawValue]); go(.notyet) }
                }
            case .notyet:
                midSheet(close: close, orb: nil, title: "That's okay.\nCravings come in waves.", sub: "The next wave is usually smaller. Stay with it a little longer.") {
                    AppCTA(title: "Another round") { method = .breathe; round += 1; Analytics.track("sos_breathe_started", ["round": round + 1]); go(.breathe) }
                    AppCTA(title: "Read my reasons", kind: .ghost) { method = .reasons; go(.reasons) }
                    LinkButton(title: "I'm going to vape anyway") { go(.anyway) }
                }
            case .win:
                let n = d.beaten
                SheetBox(calm: true) {
                    ZStack(alignment: .top) {
                        Confetti(top: 252 - 56, spread: 0.8, around: true).padding(.horizontal, -22)
                        VStack(spacing: 0) {
                            Icon(name: "check", size: 40).foregroundStyle(T.accentInk)
                                .frame(width: 92, height: 92).background(Circle().fill(T.accent).shadow(color: T.accentA(0.4), radius: 30))
                                .padding(.bottom, 24)
                            Text("Craving beaten.\nThat's \(n).").font(sf(31, 760)).tracking(-0.8).multilineTextAlignment(.center).foregroundStyle(T.text)
                            SubText(text: n == 1 ? "Your first one. Now you know it passes." : n % 10 == 0 ? "\(n) times you rode it out. That's a pattern now." : "It passed, like they do. That one counts.", align: .center)
                                .frame(maxWidth: 310).padding(.top, 10)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 150)
                    }
                } bottom: {
                    AppCTA(title: "Back to today") { close() }
                }
            case .reasons, .myreasons:
                ReasonsView(sos: step == .reasons, onPass: { go(.pass) }, onClose: close)
            case .anyway:
                midSheet(close: close, orb: AnyView(passOrb("heart", soft: true)), title: "Okay. Make it a small one.", sub: "Log it so the plan stays honest. One \(d.one) doesn't undo your progress.", glow: false) {
                    AppCTA(title: "Log 1 \(d.one)") {
                        markTried()
                        m.update { $0.cravings.append(Craving(id: uid(), at: now(), outcome: .gaveIn, method: method)) }
                        Analytics.track("craving_outcome", ["outcome": "vape_anyway", "method": method.rawValue])
                        m.logHit(.sos); close()
                    }
                    LinkButton(title: "Actually, breathe with me first") { method = .breathe; Analytics.track("sos_breathe_started"); go(.breathe) }
                }
            }
        }
    }

    func passOrb(_ icon: String, soft: Bool) -> some View {
        AppIcon(name: icon, size: soft ? 36 : 40)
            .foregroundStyle(soft ? Color(hex: 0xFFB0B0) : T.accent)
            .frame(width: 104, height: 104)
            .background(Circle().fill(soft ? AnyShapeStyle(T.dangerA(0.1)) : AnyShapeStyle(RadialGradient(colors: [T.accentA(0.35), T.accentA(0.08)], center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: 52))))
            .overlay(Circle().strokeBorder(soft ? T.dangerA(0.25) : T.accentA(0.3), lineWidth: 1))
            .shadow(color: soft ? .clear : T.accentA(0.22), radius: 30)
            .padding(.bottom, 26)
    }

    func midSheet<B: View>(close: @escaping () -> Void, orb: AnyView?, title: String, sub: String, glow: Bool = true, @ViewBuilder bottom: () -> B) -> some View {
        SheetBox(calm: true, onClose: close) {
            ZStack(alignment: .top) {
                if glow { SosGlow().padding(.horizontal, -22).padding(.top, -56) }
                VStack(spacing: 0) {
                    if let orb { orb }
                    Text(title).font(sf(31, 760)).tracking(-0.8).multilineTextAlignment(.center).foregroundStyle(T.text).padding(.top, 6)
                    SubText(text: sub, align: .center).frame(maxWidth: 310).padding(.top, 10)
                }
                .frame(maxWidth: .infinity).padding(.top, 150)
            }
        } bottom: { bottom() }
    }
}

struct BreatheView: View {
    let onDone: (Bool) -> Void
    let onClose: () -> Void
    @State private var t0 = Date()
    @State private var lastPh = ""
    @State private var finished = false
    var body: some View {
        TimelineView(.animation(paused: Env.still)) { ctx in
            let t = Env.still ? 33.4 : min(TOTAL, ctx.date.timeIntervalSince(t0))
            let (ph, left, label) = phaseAt(t)
            let p = t.truncatingRemainder(dividingBy: 14)
            let scale = ph == "in" ? 0.72 + 0.38 * ease(p / 4) : ph == "hold" ? 1.1 : 1.1 - 0.38 * ease((p - 8) / 6)
            let remain = Int(ceil(TOTAL - t))
            SheetBox(calm: true, onClose: onClose) {
                VStack(spacing: 0) {
                    Eyebrow(text: "Breathe with me").padding(.top, 0).padding(.bottom, 0)
                    Text("In through your nose, out slowly through your mouth.").font(sf(15)).foregroundStyle(T.muted).padding(.top, 6)
                        .multilineTextAlignment(.center)
                    Ring(size: 316, stroke: 5, frac: (TOTAL - t) / TOTAL, color: T.accentA(0.75), track: .white.opacity(0.06)) {
                        ZStack {
                            Circle()
                                .fill(RadialGradient(stops: [.init(color: T.accentA(0.62), location: 0), .init(color: T.accentA(0.16), location: 0.62), .init(color: T.accentA(0.04), location: 1)],
                                                     center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: 118))
                                .overlay(Circle().strokeBorder(T.accentA(ph == "hold" ? 0.6 : 0.35), lineWidth: ph == "hold" ? 1.5 : 1))
                                .shadow(color: T.accentA(ph == "hold" ? 0.36 : 0.28), radius: ph == "hold" ? 45 : 35)
                                .frame(width: 236, height: 236)
                                .scaleEffect(scale)
                            VStack(spacing: 0) {
                                Text(label).font(sf(24, 720)).tracking(-0.3).foregroundStyle(T.text)
                                Text("\(Int(ceil(left)))").font(sf(56, 780)).tracking(-2).monospacedDigit().foregroundStyle(T.text)
                            }
                        }
                    }
                    .animation(nil, value: t)
                    .padding(.top, 66)
                    HStack(spacing: 8) {
                        ForEach(["in", "hold", "out"], id: \.self) { x in
                            Text(x == "in" ? "In 4" : x == "hold" ? "Hold 4" : "Out 6").font(sf(13, 650))
                                .foregroundStyle(x == ph ? T.accent : T.muted)
                                .padding(.horizontal, 13).padding(.vertical, 7)
                                .background(RoundedRectangle(cornerRadius: 14).fill(x == ph ? T.accentSoft : .white.opacity(0.05)))
                        }
                    }
                    .padding(.top, 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 30 - 12)
            } bottom: {
                Text("\(remain / 60):\(String(format: "%02d", remain % 60)) left").font(sf(15)).monospacedDigit().foregroundStyle(T.muted)
                LinkButton(title: "Skip to the end") { finish(false) }
                    .opacity(t >= SKIP_AFTER ? 1 : 0).disabled(t < SKIP_AFTER)
            }
            .onChange(of: ph) { _, new in
                if !lastPh.isEmpty && lastPh != new { haptic(new == "hold" ? 6 : 14) }
                lastPh = new
            }
            .onChange(of: t >= TOTAL) { _, done in if done { finish(true) } }
        }
        .onAppear { t0 = Date() }
    }
    func finish(_ completed: Bool) {
        guard !finished else { return }
        finished = true
        onDone(completed)
    }
}

struct ReasonsView: View {
    @EnvironmentObject var m: AppModel
    let sos: Bool
    var onPass: (() -> Void)?
    let onClose: () -> Void
    var body: some View {
        let s = m.s
        SheetBox(onClose: onClose) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(text: "Why you're doing this").padding(.top, 18)
                    TitleText(text: "Your reasons").padding(.bottom, 18)
                    VStack(spacing: 10) {
                        ForEach(Array(s.reasons.enumerated()), id: \.offset) { i, r in
                            HStack(spacing: 14) {
                                Text("\(i + 1)").font(sf(14, 750)).foregroundStyle(T.accent).frame(width: 30, height: 30).background(Circle().fill(T.accentSoft))
                                Text(r).font(sf(18, 650)).tracking(-0.2).foregroundStyle(T.text)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 16).padding(.horizontal, 18)
                            .background(RoundedRectangle(cornerRadius: 18).fill(T.surface))
                        }
                        if s.reasons.isEmpty { SubText(text: "Add your reasons in the You tab.") }
                    }
                    PledgeCard(full: true)
                }
                .padding(.bottom, 120)
            }
            .padding(.horizontal, -22).contentMargins(.horizontal, 22, for: .scrollContent)
        } bottom: {
            if sos { AppCTA(title: "Did it pass?") { onPass?() } } else { AppCTA(title: "Done") { onClose() } }
        }
        .onAppear {
            Analytics.track("reasons_viewed", ["from": sos ? "sos" : "setup"])
            m.markSetup(\.reasons, "reasons")
        }
    }
}

struct PledgeCard: View {
    @EnvironmentObject var m: AppModel
    var full = false
    var body: some View {
        let s = m.s
        VStack(alignment: .leading, spacing: 0) {
            if full {
                Text("\"I\(s.answers.name.map { ", \($0)," } ?? "") am done letting nicotine run my day. I'll follow my plan and be nicotine-free.\"")
                    .font(sf(15)).lineSpacing(lh(15, 1.45)).foregroundStyle(Color(hex: 0x2A2F3A)).fixedSize(horizontal: false, vertical: true)
            }
            SignatureView(file: s.signature).frame(maxWidth: .infinity).frame(height: 92).padding(.top, 6)
            Text(full ? "You signed this \(Calc.fmtDate(toDate(s.start)))" : "Signed \(Calc.fmtDate(toDate(s.start), withYear: true))")
                .font(sf(12.5, 600)).foregroundStyle(Color(hex: 0x6B7280)).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(full ? EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18) : EdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18))
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(hex: 0xF4F5F7)))
        .padding(.top, full ? 18 : 0)
    }
}
