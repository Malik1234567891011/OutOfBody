import SwiftUI

// Presets let screenshots jump straight to any screen with realistic answers (same as App.tsx).
let PRESETS: [String: Answers] = [
    "disposable": Answers(device: .disposable, duration: "1to3y", strength: 50, dispSize: 6000, dispDays: 5, hitsPerDay: 30, firstHit: "5to30", triggers: ["meals", "stress", "bored"], weeklySpend: 22, tried: "few", hardParts: ["cravings", "irritable"], reasons: ["money", "breathe", "control"], name: "Malik", age: "18–24"),
    "pod": Answers(device: .pod, duration: "3to5y", strength: 50, podsPerDay: 1, hitsPerDay: 50, firstHit: "lt5", triggers: ["wake", "drive", "work"], weeklySpend: 40, tried: "once", hardParts: ["stress"], reasons: ["health", "fit"], name: "Sam", age: "25–34"),
    "pouch": Answers(device: .pouch, duration: "1to3y", pouchesPerDay: 12, pouchMg: 6, firstHit: "5to30", triggers: ["work", "meals"], weeklySpend: 40, tried: "never", reasons: ["money", "anxiety"], name: "Jordan", age: "25–34"),
    "combo": Answers(device: .combo, duration: "3to5y", strength: 50, dispSize: 6000, dispDays: 5, hitsPerDay: 30, pouchesPerDay: 7, pouchMg: 6, firstHit: "lt5", triggers: ["wake", "stress", "drink"], weeklySpend: 62, tried: "lost", hardParts: ["cravings", "friends"], reasons: ["control", "money"], name: "Alex", age: "18–24"),
]

let PW = ["pw1", "pw2", "pw3"]

/// Screen ids in order for a given set of answers (buildFlow in screens.tsx).
func buildFlow(_ a: Answers) -> [String] {
    var s = ["welcome", "device", "duration"]
    if Calc.usesVape(a) {
        if a.device == .disposable || a.device == .combo { s.append("disposable") }
        if a.device == .pod { s.append("pods") }
        if a.device == .refill { s.append("ml") }
        s.append("strength")
    }
    if Calc.usesPouch(a) { s.append("pouches") }
    s.append("firstHit")
    if Calc.usesVape(a) { s.append("hits") }
    s += ["triggers", "spend", "cost", "tried"]
    if let t = a.tried, t != "never" { s.append("hard") }
    s += ["reframe", "reasons", "about", "analyzing", "results"]
    if Calc.usesVape(a) { s.append("lungs") }
    s += ["when", "plan", "lock", "sos", "notify", "commit", "ready"]
    return s
}

/// "vape" / "pouches" / "nicotine"
func what(_ a: Answers) -> String { a.device == .pouch ? "pouches" : a.device == .combo ? "nicotine" : "vape" }

@MainActor
final class OnboardingModel: ObservableObject {
    @Published var a: Answers
    @Published var idx: Int = 0
    @Published var dir: Int = 1
    var onFinish: (Answers) -> Void = { _ in }

    init(preset: String? = Env.preset, screen: String? = Env.screen) {
        a = preset.flatMap { PRESETS[$0] } ?? Answers()
        if let screen {
            let ids = self.ids
            idx = ids.firstIndex(of: screen) ?? Int(screen) ?? 0
        }
    }

    var flow: [String] { buildFlow(a) }
    var ids: [String] { flow + PW }
    var id: String { let i = ids; return i[min(idx, i.count - 1)] }

    var progress: Double? {
        let scored = flow.filter { $0 != "welcome" }
        guard let pos = scored.firstIndex(of: id) else { return nil }
        return Double(pos + 1) / Double(scored.count)
    }

    func go(_ n: Int) {
        let target = max(0, min(ids.count - 1, n))
        dir = target > idx ? 1 : -1
        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: Env.still ? 0 : 0.32)) { idx = target }
    }
    func next() { go(idx + 1) }
    var back: (() -> Void)? { idx > 0 ? { [weak self] in guard let self else { return }; self.go(self.idx - 1) } : nil }
    func go(to id: String) { if let i = ids.firstIndex(of: id) { go(i) } }

    func set(_ f: (inout Answers) -> Void) { f(&a) }

    /// Single-select: set, then auto-advance after 260 ms (only if still on the same screen).
    func pickAndAdvance(_ f: (inout Answers) -> Void) {
        f(&a)
        let here = idx
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { [weak self] in
            guard let self, self.idx == here else { return }
            self.next()
        }
    }

    func finish() { onFinish(a) }
}

// MARK: - The flow host

struct OnboardingView: View {
    @ObservedObject var m: OnboardingModel

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            screen(m.id)
                .id(m.id)
                .transition(.asymmetric(insertion: .offset(x: CGFloat(m.dir) * 40).combined(with: .opacity), removal: .identity))
        }
        .environmentObject(m)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder func screen(_ id: String) -> some View {
        switch id {
        case "welcome": WelcomeScreen()
        case "disposable": DisposableQ()
        case "pouches": PouchQ()
        case "triggers": MultiScreen(spec: .triggers)
        case "hard": MultiScreen(spec: .hard)
        case "reasons": MultiScreen(spec: .reasons)
        case "cost": CostReveal()
        case "reframe": Reframe()
        case "about": About()
        case "analyzing": Analyzing()
        case "results": Results()
        case "lungs": Lungs()
        case "plan": PlanScreen()
        case "lock": LockDemo()
        case "sos": SosDemo()
        case "notify": Notify()
        case "commit": Commit()
        case "ready": Ready()
        case "pw1": PaywallP1()
        case "pw2": PaywallP2()
        case "pw3": PaywallP3()
        default:
            if let spec = SingleSpec.forId(id, m.a) { SingleScreen(spec: spec) } else { Text(id) }
        }
    }
}

// MARK: - Generic single-select question

struct SingleSpec {
    let title: String
    var sub: String?
    let opts: [(Opt, AnyHashable)]
    let get: (Answers) -> AnyHashable?
    let set: (inout Answers, AnyHashable) -> Void

    static func dbl(_ kp: WritableKeyPath<Answers, Double?>) -> ((Answers) -> AnyHashable?, (inout Answers, AnyHashable) -> Void) {
        ({ $0[keyPath: kp].map { AnyHashable($0) } }, { a, v in a[keyPath: kp] = v as? Double })
    }
    static func str(_ kp: WritableKeyPath<Answers, String?>) -> ((Answers) -> AnyHashable?, (inout Answers, AnyHashable) -> Void) {
        ({ $0[keyPath: kp].map { AnyHashable($0) } }, { a, v in a[keyPath: kp] = v as? String })
    }
    init(title: String, sub: String? = nil, opts: [(Opt, AnyHashable)], acc: ((Answers) -> AnyHashable?, (inout Answers, AnyHashable) -> Void)) {
        self.title = title; self.sub = sub; self.opts = opts; self.get = acc.0; self.set = acc.1
    }
    /// Options whose value is their id
    static func ids(_ o: [Opt]) -> [(Opt, AnyHashable)] { o.map { ($0, AnyHashable($0.id)) } }

    static func forId(_ id: String, _ a: Answers) -> SingleSpec? {
        switch id {
        case "device":
            return SingleSpec(title: "What do you use?", sub: "This sets up how we measure your nicotine.", opts: [
                (Opt(id: "disposable", label: "Disposable vape", detail: "Elf Bar, Lost Mary, Geek Bar…", icon: "disposable"), Device.disposable),
                (Opt(id: "pod", label: "Pod vape", detail: "Juul, Vuse, NJOY…", icon: "pod"), Device.pod),
                (Opt(id: "refill", label: "Refillable vape", detail: "You fill it with e-liquid", icon: "refill"), Device.refill),
                (Opt(id: "pouch", label: "Nicotine pouches", detail: "Zyn, Velo, On!…", icon: "pouch"), Device.pouch),
                (Opt(id: "combo", label: "Vape and pouches", icon: "combo"), Device.combo),
            ], acc: ({ $0.device.map { AnyHashable($0) } }, { a, v in a.device = v as? Device }))
        case "duration":
            return SingleSpec(title: "How long have you been using \(what(a) == "pouches" ? "pouches" : "nicotine")?", opts: ids([
                Opt(id: "lt6m", label: "Less than 6 months"), Opt(id: "6to12m", label: "6–12 months"), Opt(id: "1to3y", label: "1–3 years"),
                Opt(id: "3to5y", label: "3–5 years"), Opt(id: "5y", label: "More than 5 years"),
            ]), acc: str(\.duration))
        case "pods":
            return SingleSpec(title: "How many pods do you go through?", opts: [
                (Opt(id: "q", label: "About one every 3–4 days"), 0.3), (Opt(id: "h", label: "About one every 2 days"), 0.5),
                (Opt(id: "1", label: "About one a day"), 1.0), (Opt(id: "2", label: "Two a day"), 2.0), (Opt(id: "3", label: "Three or more a day"), 3.0),
            ], acc: dbl(\.podsPerDay))
        case "ml":
            return SingleSpec(title: "How much e-liquid do you use a day?", opts: [
                (Opt(id: "1", label: "About 1 mL"), 1.0), (Opt(id: "3", label: "2–3 mL"), 2.5), (Opt(id: "5", label: "4–6 mL"), 5.0), (Opt(id: "8", label: "7 mL or more"), 8.0),
            ], acc: dbl(\.mlPerDay))
        case "strength":
            return SingleSpec(title: "How strong is it?", sub: "Check the box or the pod. Most disposables and pods are 5%.", opts: [
                (Opt(id: "50", label: "5% · 50 mg"), 50.0), (Opt(id: "35", label: "3–3.5% · 30–35 mg"), 33.0), (Opt(id: "20", label: "2% · 20 mg"), 20.0),
                (Opt(id: "6", label: "1% or less"), 8.0), (Opt(id: "ns", label: "Not sure", detail: "We'll assume 5%"), 49.0),
            ], acc: dbl(\.strength))
        case "firstHit":
            return SingleSpec(title: "After you wake up, how soon do you reach for it?", sub: "Be honest. This is the best single measure of dependence.", opts: ids([
                Opt(id: "lt5", label: "Within 5 minutes"), Opt(id: "5to30", label: "6–30 minutes"), Opt(id: "31to60", label: "31–60 minutes"), Opt(id: "gt60", label: "After an hour or more"),
            ]), acc: str(\.firstHit))
        case "hits":
            return SingleSpec(title: "How many times a day do you pick it up?", sub: "Count each time you reach for it, even for one hit. A rough guess is fine.", opts: [
                (Opt(id: "12", label: "10–20 times"), 15.0), (Opt(id: "30", label: "20–40 times"), 30.0),
                (Opt(id: "50", label: "40–60 times"), 50.0), (Opt(id: "75", label: "Honestly, all day", detail: "It's barely out of my hand"), 75.0),
            ], acc: dbl(\.hitsPerDay))
        case "spend":
            return SingleSpec(title: "How much do you spend on \(what(a)) a week?", opts: [
                (Opt(id: "10", label: "Under $15"), 10.0), (Opt(id: "20", label: "$15–30"), 22.0), (Opt(id: "40", label: "$30–50"), 40.0),
                (Opt(id: "60", label: "$50–75"), 62.0), (Opt(id: "90", label: "More than $75"), 90.0),
            ], acc: dbl(\.weeklySpend))
        case "tried":
            return SingleSpec(title: "Have you tried to quit before?", opts: ids([
                Opt(id: "never", label: "No, this is my first time"), Opt(id: "once", label: "Once"), Opt(id: "few", label: "2–5 times"), Opt(id: "lost", label: "I've lost count"),
            ]), acc: str(\.tried))
        case "when":
            let rec = Calc.recommendedWeeks(a)
            func mk(_ w: Int, _ label: String) -> (Opt, AnyHashable) {
                var b = a; b.weeks = Double(w)
                return (Opt(id: String(w), label: label, detail: "Nicotine-free by \(Calc.fmtDate(Calc.quitDate(b)))", tag: w == rec ? "Recommended" : nil), Double(w))
            }
            return SingleSpec(title: "How fast do you want to step down?", sub: "Based on your answers we recommend \(rec) weeks.",
                              opts: [mk(2, "2 weeks · fast"), mk(4, "4 weeks · steady"), mk(6, "6 weeks · gentle"), mk(8, "8 weeks · slowest")],
                              acc: dbl(\.weeks))
        default: return nil
        }
    }
}

struct SingleScreen: View {
    @EnvironmentObject var m: OnboardingModel
    let spec: SingleSpec
    var body: some View {
        let cur = spec.get(m.a)
        let selId = spec.opts.first { $0.1 == cur }?.0.id
        ScreenBox {
            TopBar(progress: m.progress, onBack: m.back)
            TitleBlock(title: spec.title, sub: spec.sub)
            Options(opts: spec.opts.map(\.0), selected: { $0 == selId }) { id in
                guard let v = spec.opts.first(where: { $0.0.id == id })?.1 else { return }
                m.pickAndAdvance { spec.set(&$0, v) }
            }
        }
    }
}

// MARK: - Generic multi-select question

struct MultiSpec {
    let title: String
    var sub: String = "Pick all that apply."
    let opts: [Opt]
    let kp: WritableKeyPath<Answers, [String]?>

    static let triggers = MultiSpec(title: "When do you reach for it most?", opts: TRIGGERS, kp: \.triggers)
    static let hard = MultiSpec(title: "What made it hard?", opts: [
        Opt(id: "cravings", label: "The cravings"), Opt(id: "irritable", label: "Irritability or anxiety"), Opt(id: "stress", label: "Stress came back"),
        Opt(id: "friends", label: "Friends who vape"), Opt(id: "bored", label: "Boredom"), Opt(id: "sleep", label: "Bad sleep"), Opt(id: "focus", label: "Couldn't focus"),
    ], kp: \.hardParts)
    static let reasons = MultiSpec(title: "Why do you want to quit?", sub: "We'll remind you of these when it gets hard.", opts: REASONS, kp: \.reasons)
}

let TRIGGERS: [Opt] = [
    Opt(id: "wake", label: "Right after waking up"),
    Opt(id: "meals", label: "After meals"),
    Opt(id: "stress", label: "When stressed or anxious"),
    Opt(id: "bored", label: "When bored"),
    Opt(id: "drive", label: "Driving or commuting"),
    Opt(id: "work", label: "At work or school breaks"),
    Opt(id: "drink", label: "Drinking or going out"),
    Opt(id: "social", label: "Around friends who vape"),
    Opt(id: "bed", label: "Before bed"),
]

let REASONS: [Opt] = [
    Opt(id: "money", label: "Save money"),
    Opt(id: "breathe", label: "Breathe easier"),
    Opt(id: "fit", label: "Get fitter"),
    Opt(id: "control", label: "Stop feeling controlled by it"),
    Opt(id: "anxiety", label: "Less anxiety"),
    Opt(id: "sleep", label: "Sleep better"),
    Opt(id: "someone", label: "For someone in my life"),
    Opt(id: "health", label: "Long-term health"),
]

struct MultiScreen: View {
    @EnvironmentObject var m: OnboardingModel
    let spec: MultiSpec
    var body: some View {
        let cur = m.a[keyPath: spec.kp] ?? []
        ScreenBox {
            TopBar(progress: m.progress, onBack: m.back)
            TitleBlock(title: spec.title, sub: spec.sub)
            ScrollView(showsIndicators: false) {
                Options(opts: spec.opts, selected: { cur.contains($0) }, multi: true) { id in
                    m.set { a in
                        var c = a[keyPath: spec.kp] ?? []
                        if let i = c.firstIndex(of: id) { c.remove(at: i) } else { c.append(id) }
                        a[keyPath: spec.kp] = c
                    }
                }
                .padding(.bottom, 130)
            }
            .padding(.horizontal, -22)
            .contentMargins(.horizontal, 22, for: .scrollContent)
        } bottom: {
            BottomBar { CTA(title: "Continue", disabled: cur.isEmpty) { m.next() } }
        }
    }
}
