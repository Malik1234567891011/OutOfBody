import SwiftUI
import UserNotifications

// MARK: - Lock-screen logging demo

struct LockDemo: View {
    @EnvironmentObject var m: OnboardingModel
    @State private var used: Int?
    @State private var tap = false
    let timer = Timer.publish(every: 1.6, on: .main, in: .common).autoconnect()

    var body: some View {
        let a = m.a
        let budget = max(1, Calc.plan(a).first.flatMap { $0 == 0 ? nil : $0 } ?? 10)
        let unit = Calc.budgetUnit(a)
        let u = used ?? Int(jsRound(Double(budget) * 0.58))
        let pct = Double(u) / Double(budget)
        ScreenBox {
            TopBar(progress: m.progress, onBack: m.back)
            TitleBlock(title: "Log in one tap, right from your lock screen",
                       sub: "Tap the widget each time you hit it. No unlocking, no app to open. Seeing the number is half the work.")
            VStack(spacing: 0) {
                Text(lockDate()).font(sf(16, 600)).foregroundStyle(.white.opacity(0.85)).padding(.top, 26)
                Text("9:41").font(sf(86, 600)).tracking(-2).foregroundStyle(.white.opacity(0.95)).frame(height: 86)
                HStack(spacing: 14) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.18), lineWidth: 6)
                        Circle().trim(from: 0, to: min(1, pct))
                            .stroke(pct > 0.9 ? T.warn : T.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 44, height: 44).frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(u) / \(budget)").font(sf(22, 700)).monospacedDigit().foregroundStyle(T.text)
                        Text("\(unit) today · tap to log").font(sf(13)).foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer(minLength: 0)
                    Text("+").font(sf(24, 600)).foregroundStyle(T.accentInk)
                        .frame(width: 36, height: 36).background(Circle().fill(T.accent))
                }
                .padding(.vertical, 12).padding(.horizontal, 14)
                .frame(width: 300)
                .background(RoundedRectangle(cornerRadius: 22).fill(.white.opacity(tap ? 0.24 : 0.14)))
                .scaleEffect(tap ? 0.96 : 1)
                .animation(.easeOut(duration: 0.15), value: tap)
                .padding(.top, 26)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity).frame(height: 330)
            .background(LinearGradient(stops: [
                .init(color: Color(hex: 0x1D3B4A), location: 0),
                .init(color: Color(hex: 0x0F2030), location: 0.45),
                .init(color: Color(hex: 0x2B1830), location: 1),
            ], startPoint: UnitPoint(x: 0.33, y: 0), endPoint: UnitPoint(x: 0.67, y: 1)))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .padding(.horizontal, -4)
        } bottom: {
            BottomBar { CTA(title: "Continue") { m.next() } }
        }
        .onReceive(timer) { _ in
            guard !Env.still else { return }
            tap = true
            let cur = used ?? Int(jsRound(Double(budget) * 0.58))
            used = cur + 1 > budget ? Int(jsRound(Double(budget) * 0.58)) : cur + 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { tap = false }
        }
    }

    func lockDate() -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }
}

// MARK: - Craving SOS demo

struct SosDemo: View {
    @EnvironmentObject var m: OnboardingModel
    enum Phase { case idle, inhale, exhale, done }
    @State private var phase: Phase = Env.still ? .inhale : .idle
    @State private var secs = 12
    @State private var scale: CGFloat = Env.still ? 1.12 : 0.96
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScreenBox {
            TopBar(progress: m.progress, onBack: m.back)
            TitleBlock(title: "Cravings pass. We'll get you through them.",
                       sub: "A craving peaks and fades within minutes. When one hits, hit SOS and ride it out with us. Try a short one now.")
            VStack(spacing: 18) {
                Button {
                    if phase == .idle || phase == .done { secs = 12; setPhase(.inhale) }
                } label: {
                    Text(label).font(sf(21, 650)).lineSpacing(lh(21, 1.25)).multilineTextAlignment(.center).foregroundStyle(T.text)
                        .frame(width: 230, height: 230)
                        .background(
                            Circle().fill(RadialGradient(stops: [
                                .init(color: T.accentA(0.55), location: 0),
                                .init(color: T.accentA(0.14), location: 0.6),
                                .init(color: T.accentA(0.05), location: 1),
                            ], center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: 115 * 1.12))
                        )
                        .overlay(Circle().stroke(T.accentA(0.35), lineWidth: 1))
                        .background(Circle().fill(T.accentA(0.25)).blur(radius: 30))
                        .scaleEffect(scale)
                }
                .buttonStyle(.plain)
                Text(phase == .inhale || phase == .exhale ? "\(secs)s" : " ").font(sf(12.5)).foregroundStyle(T.muted).frame(minHeight: 18)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
        } bottom: {
            BottomBar { CTA(title: phase == .done ? "Continue" : "Skip") { m.next() } }
        }
        .onAppear { if !Env.still { setPhase(.idle) } }
        .onReceive(timer) { _ in
            guard !Env.still, phase == .inhale || phase == .exhale else { return }
            let s = secs
            if s <= 1 { secs = 0; setPhase(.done); return }
            if (s - 1) % 4 == 0 { setPhase(phase == .inhale ? .exhale : .inhale) }
            secs = s - 1
        }
    }

    var label: String {
        switch phase {
        case .idle: return "Tap to try"
        case .inhale: return "Breathe in"
        case .exhale: return "Breathe out"
        case .done: return "Nice. That's\nhow it works."
        }
    }

    func setPhase(_ p: Phase) {
        phase = p
        switch p {
        case .idle:
            scale = 0.96
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { scale = 1.02 }
        case .inhale: withAnimation(.easeInOut(duration: 4)) { scale = 1.12 }
        case .exhale: withAnimation(.easeInOut(duration: 4)) { scale = 0.8 }
        case .done: withAnimation(.easeInOut(duration: 4)) { scale = 1 }
        }
    }
}

// MARK: - Notifications warm-up (real permission prompt)

let NOTIF_COPY: [String: String] = [
    "wake": "Morning. Breakfast first, first hit after. You've got this.",
    "meals": "After-meal craving incoming. Walk for 3 minutes before you decide.",
    "stress": "Stressful moment? Hit SOS. It passes in a few minutes.",
    "bored": "Bored hands. Do 10 slow breaths before you reach for it.",
    "drive": "Driving? Leave it in the bag until you park.",
    "work": "Break time. You're at 58% of today's budget.",
    "drink": "Going out tonight? Decide your budget before the first drink.",
    "social": "Friends vaping? You don't have to explain. Just hold off 5 minutes.",
    "bed": "Last one of the night counts too. You're under budget today.",
]

struct Notify: View {
    @EnvironmentObject var m: OnboardingModel
    @State private var shown = Env.still
    var body: some View {
        let t = Array((m.a.triggers ?? ["meals", "stress"]).prefix(3))
        ScreenBox {
            TopBar(progress: m.progress, onBack: m.back)
            TitleBlock(title: "We'll show up when it's hardest",
                       sub: "We'll check in at the moments you told us are hardest, plus one heads-up each time your budget drops.")
            VStack(spacing: 10) {
                ForEach(Array(t.enumerated()), id: \.element) { i, id in
                    HStack(alignment: .top, spacing: 12) {
                        Text("O").font(sf(18, 800)).foregroundStyle(T.accentInk)
                            .frame(width: 38, height: 38).background(RoundedRectangle(cornerRadius: 10).fill(T.accent))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("OutOfBody").font(sf(14, 700)).foregroundStyle(T.text)
                                Spacer()
                                Text("now").font(sf(14)).foregroundStyle(T.muted)
                            }
                            Text(NOTIF_COPY[id] ?? "Craving? Hit SOS. It passes in a few minutes.")
                                .font(sf(14.5)).lineSpacing(lh(14.5, 1.3)).foregroundStyle(T.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 12).padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20).fill(.white.opacity(0.08)))
                    .offset(y: shown ? 0 : -14).opacity(shown ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(Double(i) * 0.16), value: shown)
                }
            }
        } bottom: {
            BottomBar {
                CTA(title: "Turn on check-ins") {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                        DispatchQueue.main.async { m.next() }
                    }
                }
                Button { m.next() } label: {
                    Text("Not now").font(sf(15)).foregroundStyle(T.muted)
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
        }
        .onAppear { if !shown { DispatchQueue.main.async { shown = true } } }
    }
}

// MARK: - Signature commitment

struct Commit: View {
    @EnvironmentObject var m: OnboardingModel
    @State private var strokes: [[CGPoint]] = []
    @State private var has = false
    @State private var drawing = false
    var body: some View {
        let date = Calc.fmtDate(Calc.quitDate(m.a), withYear: true)
        ScreenBox {
            TopBar(progress: m.progress, onBack: m.back)
            TitleBlock(title: "Make it official", sub: "People who make a written commitment are more likely to follow through. Sign below.")
            (Text("\"I\(m.a.name.map { ", \($0)," } ?? "") am done letting nicotine run my day. I'll follow my plan and be nicotine-free by ")
             + Text(date).font(sf(18, 700)).foregroundColor(T.accent) + Text(".\""))
                .font(sf(18, 500)).lineSpacing(lh(18, 1.45)).foregroundStyle(T.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, -6).padding(.bottom, 18)
            ZStack(alignment: .topTrailing) {
                Canvas { ctx, _ in
                    for s in strokes where !s.isEmpty {
                        var p = Path(); p.move(to: s[0])
                        for q in s.dropFirst() { p.addLine(to: q) }
                        ctx.stroke(p, with: .color(Color(hex: 0x0B0F17)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 170)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color(hex: 0xF4F5F7)))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if !drawing { strokes.append([v.startLocation]); drawing = true }
                        strokes[strokes.count - 1].append(v.location)
                        if v.location != v.startLocation { has = true }
                    }
                    .onEnded { _ in drawing = false })
                if !has {
                    Text("Sign here with your finger").font(sf(15)).foregroundStyle(Color(hex: 0x9AA0AB))
                        .frame(maxWidth: .infinity, maxHeight: .infinity).allowsHitTesting(false)
                } else {
                    Button { strokes = []; has = false } label: {
                        Text("Clear").font(sf(14, 600)).foregroundStyle(Color(hex: 0x555566))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 10).padding(.top, 8)
                }
            }
            .frame(height: 170)
        } bottom: {
            BottomBar { CTA(title: "I commit", disabled: !has) { m.set { $0.signed = true }; m.next() } }
        }
    }
}

// MARK: - Plan ready

struct Ready: View {
    @EnvironmentObject var m: OnboardingModel
    var body: some View {
        let a = m.a
        let reasons = (a.reasons ?? []).compactMap { r in REASONS.first { $0.id == r }?.label }.prefix(3)
        GeometryReader { g in
            ZStack(alignment: .top) {
                BreathOrb(size: 340).position(x: g.size.width / 2, y: 170)
                VStack(spacing: 0) {
                    Icon(name: "check", size: 30).foregroundStyle(T.accentInk)
                        .frame(width: 64, height: 64).background(Circle().fill(T.accent))
                        .padding(.top, 62)
                    Eyebrow(text: a.name.map { "\($0), your plan is ready" } ?? "Your plan is ready").padding(.top, 6)
                    TitleText(text: "You'll be nicotine-free by", align: .center)
                    Text(Calc.fmtDate(Calc.quitDate(a), withYear: true))
                        .font(sf(30, 760)).tracking(-0.6).foregroundStyle(T.text)
                        .padding(.vertical, 10).padding(.horizontal, 22)
                        .background(RoundedRectangle(cornerRadius: 18).fill(T.surface)
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(T.accent, lineWidth: 1.5)))
                        .padding(.top, 14)
                    ListCard(rows: [
                        ("Starting budget", "\(Calc.plan(a).first ?? 0) \(Calc.budgetUnit(a))/day"),
                        ("Steps", "\(Calc.plan(a).count) weekly drops"),
                        ("You'll keep", Calc.money(Calc.yearlySpend(a)) + "/yr"),
                    ])
                    .padding(.top, 22)
                    if !reasons.isEmpty {
                        CenterFlow(spacing: 8) {
                            ForEach(Array(reasons), id: \.self) { r in
                                Text(r).font(sf(13.5, 600)).foregroundStyle(T.accent)
                                    .padding(.vertical, 7).padding(.horizontal, 12)
                                    .background(Capsule().fill(T.accentSoft))
                            }
                        }
                        .padding(.top, 18)
                    }
                }
                .padding(.top, 56).padding(.horizontal, 22)
                VStack { Spacer(); BottomBar { CTA(title: "Start my plan") { PaywallGate.afterReady(m) } } }
            }
        }
        .ignoresSafeArea()
    }
}

/// Wrapping, centered row layout (`.chips`).
struct CenterFlow: Layout {
    var spacing: CGFloat = 8
    func rows(_ w: CGFloat, _ subs: Subviews) -> [[(Int, CGSize)]] {
        var rows: [[(Int, CGSize)]] = [[]]; var x: CGFloat = 0
        for (i, s) in subs.enumerated() {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > w { rows.append([]); x = 0 }
            rows[rows.count - 1].append((i, sz)); x += sz.width + spacing
        }
        return rows
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 360
        let r = rows(w, subviews)
        let h = r.reduce(0) { $0 + ($1.map(\.1.height).max() ?? 0) } + CGFloat(max(0, r.count - 1)) * spacing
        return CGSize(width: w, height: h)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = b.minY
        for row in rows(b.width, subviews) {
            let rw = row.reduce(0) { $0 + $1.1.width } + CGFloat(max(0, row.count - 1)) * spacing
            var x = b.minX + (b.width - rw) / 2
            let rh = row.map(\.1.height).max() ?? 0
            for (i, sz) in row {
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz)); x += sz.width + spacing
            }
            y += rh + spacing
        }
    }
}
