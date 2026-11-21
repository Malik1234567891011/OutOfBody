import SwiftUI

// Native 3-page paywall (paywall.tsx). Copy is fixed to the CAD price like the prototype.
let PRICE = 39.99
let CUR = "CAD"
let perWeek = String(format: "%.2f", PRICE / 52)
let WEEKLY = 3.99
let WEEKLY_STR = "3.99"
let savePct = Int(((1 - PRICE / 52 / WEEKLY) * 100).rounded(.down))

private func daysFromNow(_ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: n, to: Date()) ?? Date() }

struct PwTop: View {
    var onBack: (() -> Void)?
    var onClose: (() -> Void)?
    var body: some View {
        HStack {
            if let onBack { iconBtn("back", onBack) } else { Color.clear.frame(width: 40, height: 40) }
            Spacer()
            if let onClose { iconBtn("close", onClose) } else { Color.clear.frame(width: 40, height: 40) }
        }
        .frame(height: 44)
    }
    func iconBtn(_ n: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) { Icon(name: n).foregroundStyle(T.text).frame(width: 40, height: 40).contentShape(Rectangle()) }
            .buttonStyle(.plain)
    }
}

// MARK: - Page 1: "We want you to try OutOfBody for free"

struct PaywallP1: View {
    @EnvironmentObject var m: OnboardingModel
    var body: some View {
        ScreenBox(top: 54) {
            PwTop(onClose: { m.go(to: "pw3") }).padding(.horizontal, -8)
            Lines(text: "We want you to try\nOutOfBody for free", size: 28, tracking: -0.6).padding(.top, 4)
            ZStack(alignment: .top) {
                ZStack(alignment: .top) {
                    T.bg
                    MiniHomeView(a: m.a)
                    MiniStatusBar()
                }
                .clipShape(RoundedRectangle(cornerRadius: 33, style: .continuous))
                .padding(8)
                Capsule().fill(.black).frame(width: 72, height: 21).padding(.top, 15)
            }
            .frame(width: 236, height: 486)
            .background(RoundedRectangle(cornerRadius: 40, style: .continuous).fill(.black))
            .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).stroke(Color(hex: 0x333333), lineWidth: 1.5).padding(-0.75))
            .shadow(color: T.accentA(0.12), radius: 25, y: 20)
            .frame(maxWidth: .infinity)
            .padding(.top, 22)
        } bottom: {
            BottomBar {
                FineOK(text: "No payment due now")
                CTA(title: "Continue") { m.next() }
            }
        }
    }
}

// MARK: - Page 2: reminder bell + trial timeline

struct PaywallP2: View {
    @EnvironmentObject var m: OnboardingModel
    var body: some View {
        ScreenBox(top: 54) {
            PwTop(onBack: { m.go(m.idx - 1) }).padding(.horizontal, -8)
            Lines(text: "We'll send you a reminder\nbefore your free trial ends", size: 28, tracking: -0.6).padding(.top, 4)
            ZStack(alignment: .topTrailing) {
                RingingBell().frame(width: 150, height: 150)
                Text("1").font(sf(20, 700)).foregroundStyle(.white)
                    .frame(width: 38, height: 38).background(Circle().fill(T.danger))
                    .padding(.top, 18).padding(.trailing, 22)
            }
            .frame(width: 150, height: 150)
            .frame(maxWidth: .infinity)
            .padding(.top, 54)
            VStack(alignment: .leading, spacing: 18) {
                row("lock", "Today", "Unlock your full plan, the lock-screen tracker and craving SOS.", on: true)
                row("bell", "Day 5 · \(Calc.fmtDate(daysFromNow(5)))", "We'll remind you your trial is ending.")
                row("star", "Day 7 · \(Calc.fmtDate(daysFromNow(7)))", "You'll be charged \(Calc.money(PRICE)) \(CUR) unless you cancel before.")
            }
            .padding(.horizontal, 6)
            .padding(.top, 40)
        } bottom: {
            BottomBar {
                FineOK(text: "No payment due now")
                CTA(title: "Continue for free") { m.next() }
            }
        }
    }
    func row(_ icon: String, _ t: String, _ d: String, on: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Icon(name: icon, size: 16).foregroundStyle(on ? T.accentInk : T.muted)
                .frame(width: 34, height: 34).background(Circle().fill(on ? T.accent : T.surface2))
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(sf(16, 650)).foregroundStyle(T.text)
                Text(d).font(sf(14)).lineSpacing(lh(14, 1.35)).foregroundStyle(T.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Bell that rings for ~1 s every 2.6 s (keyframes `ring`).
struct RingingBell: View {
    var body: some View {
        TimelineView(.animation(paused: Env.still)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.6) / 2.6
            Icon(name: "bell", size: 92).foregroundStyle(Color(hex: 0xC9CED8))
                .rotationEffect(.degrees(Env.still ? 0 : Self.angle(t)), anchor: UnitPoint(x: 0.5, y: 0.1))
        }
    }
    static func angle(_ t: Double) -> Double {
        let keys: [(Double, Double)] = [(0, 0), (0.60, 0), (0.64, 12), (0.70, -10), (0.76, 6), (0.82, -3), (1, 0)]
        for i in 0..<(keys.count - 1) where t >= keys[i].0 && t <= keys[i + 1].0 {
            let k = (t - keys[i].0) / (keys[i + 1].0 - keys[i].0)
            let e = k < 0.5 ? 2 * k * k : 1 - pow(-2 * k + 2, 2) / 2
            return keys[i].1 + (keys[i + 1].1 - keys[i].1) * e
        }
        return 0
    }
}

// MARK: - Page 3: photo + 7 DAYS FREE card

struct PaywallP3: View {
    @EnvironmentObject var m: OnboardingModel
    @StateObject private var store = Store.shared
    @State private var yearly = true
    func radio(_ on: Bool) -> some View {
        ZStack {
            Circle().fill(on ? T.accent : .clear)
            Circle().strokeBorder(on ? T.accent : Color(hex: 0x3A4253), lineWidth: 1.5)
            if on { Icon(name: "check", size: 16).foregroundStyle(T.accentInk) }
        }
        .frame(width: 28, height: 28)
    }
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .top) {
                T.bg
                Image(uiImage: UIImage(named: "paywall-hero.jpg") ?? UIImage())
                    .resizable().scaledToFill()
                    .frame(width: g.size.width, height: g.size.height * 0.58).clipped()
                LinearGradient(stops: [
                    .init(color: T.bgA(0.55), location: 0),
                    .init(color: T.bgA(0), location: 0.18),
                    .init(color: T.bgA(0), location: 0.36),
                    .init(color: T.bgA(0.75), location: 0.52),
                    .init(color: T.bg, location: 0.56),
                ], startPoint: .top, endPoint: .bottom)
                PwTop(onBack: { m.go(m.idx - 1) }, onClose: { m.go(to: "pw1") })
                    .padding(.horizontal, 14).padding(.top, 54)
                VStack(spacing: 0) {
                    Spacer()
                    Lines(text: "Start your FREE trial\nto continue", size: 33, weight: 780, lineHeight: 1.08, tracking: -0.9)
                        .padding(.bottom, 22)
                    Button { yearly = true } label: {
                        VStack(spacing: 0) {
                            Text("7 DAYS FREE").font(sf(13, 800)).tracking(1.6).foregroundStyle(yearly ? T.accentInk : T.muted)
                                .frame(maxWidth: .infinity).padding(.vertical, 6).background(yearly ? T.accent : T.surface2)
                            HStack(spacing: 12) {
                                radio(yearly)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Start for free & save \(savePct)%").font(sf(16, 700)).tracking(-0.2).foregroundStyle(T.text).lineLimit(1).fixedSize()
                                    Text("\(Calc.money(PRICE)) \(CUR) billed annually").font(sf(14)).foregroundStyle(T.muted).lineLimit(1).fixedSize()
                                }
                                .layoutPriority(1)
                                Spacer(minLength: 0)
                                Text("$\(perWeek)/wk").font(sf(16, 700)).foregroundStyle(T.text).fixedSize()
                            }
                            .padding(.vertical, 15).padding(.horizontal, 16)
                        }
                        .background(yearly ? T.accentA(0.08) : T.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(yearly ? T.accent : T.line, lineWidth: 2))
                        .contentShape(RoundedRectangle(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)
                    Button { yearly = false } label: {
                        HStack(spacing: 12) {
                            radio(!yearly)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Weekly").font(sf(16, 700)).tracking(-0.2).foregroundStyle(T.text)
                                Text("Cancel anytime").font(sf(14)).foregroundStyle(T.muted)
                            }
                            Spacer(minLength: 0)
                            Text("$\(WEEKLY_STR)/wk").font(sf(16, 700)).foregroundStyle(T.text).fixedSize()
                        }
                        .padding(.vertical, 15).padding(.horizontal, 16)
                        .background(RoundedRectangle(cornerRadius: 22).fill(yearly ? T.surface : T.accentA(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(yearly ? T.line : T.accent, lineWidth: 2))
                        .contentShape(RoundedRectangle(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                    Text("Nicotine-free by \(Calc.fmtDate(Calc.quitDate(m.a))). Keep \(Calc.money(Calc.yearlySpend(m.a))) a year.")
                        .font(sf(14, 600)).foregroundStyle(T.accent).multilineTextAlignment(.center)
                        .padding(.vertical, 14)
                    CTA(title: store.purchasing ? "One moment…" : (yearly ? "Start my free week" : "Continue"), disabled: false) {
                        guard !store.purchasing else { return }
                        Task { if await store.buy(yearly ? Config.productId : Config.weeklyProductId) { m.finish() } }
                    }
                    Fine(text: yearly
                         ? "7 days free, then \(Calc.money(PRICE)) \(CUR) per year. Billed annually and renews automatically unless canceled in the App Store."
                         : "$\(WEEKLY_STR) \(CUR) per week. Billed weekly and renews automatically unless canceled in the App Store.")
                        .padding(.top, 12)
                    HStack(spacing: 0) {
                        Text("Terms · Privacy · ")
                        Button("Restore") { Task { if await store.restore() { m.finish() } } }.buttonStyle(.plain)
                    }
                    .font(sf(12.5)).foregroundStyle(T.muted)
                    .padding(.top, 8)
                    if let e = store.error {
                        Text(e).font(sf(12)).foregroundStyle(T.danger).padding(.top, 6)
                    }
                }
                .padding(.horizontal, 22).padding(.bottom, 30)
            }
        }
        .ignoresSafeArea()
        .task { await store.load() }
    }
}
