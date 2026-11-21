import SwiftUI

// MARK: - 1. Welcome

struct WelcomeScreen: View {
    @EnvironmentObject var m: OnboardingModel
    @State private var breathe = false
    var body: some View {
        GeometryReader { g in
            let cx = g.size.width / 2
            ZStack(alignment: .topLeading) {
                Text("outofbody").font(sf(18, 750)).tracking(-0.3).foregroundStyle(T.text)
                    .frame(width: g.size.width).padding(.top, 64)
                BreathOrb(size: 460).position(x: cx, y: 300)
                lungs.position(x: cx, y: 300)
                VStack(spacing: 10) {
                    Lines(text: "Get nicotine\nout of your body.", size: 40, weight: 750, lineHeight: 1.05, tracking: -1.2)
                    SubText(text: "Answer a few quick questions. We'll show you what your vape is really doing, then step you down to zero.", align: .center)
                }
                .frame(width: g.size.width - 44)
                .padding(.leading, 22).padding(.top, 512)
                VStack(spacing: 0) {
                    Spacer()
                    BottomBar {
                        CTA(title: "Start the quiz") { m.next() }
                        Fine(text: "Takes about a minute · 100% private, no account").padding(.top, 10)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    private var lungs: some View {
        let w: CGFloat = 520, h: CGFloat = 520 * 1024 / 1536
        return Image(uiImage: UIImage(named: "lungs-after.jpg") ?? UIImage())
            .resizable().frame(width: w, height: h)
            .mask(
                EllipticalGradient(stops: [.init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                                   center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
                    .frame(width: w * 0.92, height: h)
            )
            .blendMode(.screen)
            .scaleEffect(Env.still ? 0.94 : (breathe ? 1.02 : 0.94))
            .onAppear {
                guard !Env.still else { return }
                withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) { breathe = true }
            }
            .allowsHitTesting(false)
    }
}

// MARK: - Disposable size + how long it lasts (one screen)

struct PlainOptRow: View {
    let label: String
    let on: Bool
    let tap: () -> Void
    var body: some View { OptionRow(o: Opt(id: label, label: label), on: on, tap: tap) }
}

struct DisposableQ: View {
    @EnvironmentObject var m: OnboardingModel
    let sizes: [(Double, String)] = [(800, "≤1k"), (3000, "2–4k"), (6000, "5–8k"), (12000, "10k+")]
    let days: [(Double, String)] = [(1, "1 day"), (2.5, "2–3 days"), (5, "4–6 days"), (7, "A week"), (14, "2+ weeks")]
    var body: some View {
        ScreenBox {
            TopBar(progress: m.progress, onBack: m.back)
            TitleBlock(title: "Tell us about your disposable", sub: "Two taps. This is how we work out your real nicotine.")
            FieldLabel(text: "Puffs on the box")
            Seg(items: sizes, value: m.a.dispSize) { v in m.set { $0.dispSize = v } }
            FieldLabel(text: "One lasts me about").padding(.top, 28)
            VStack(spacing: 10) {
                ForEach(days, id: \.0) { d in PlainOptRow(label: d.1, on: m.a.dispDays == d.0) { m.set { $0.dispDays = d.0 } } }
            }
        } bottom: {
            BottomBar { CTA(title: "Continue", disabled: m.a.dispSize == nil || m.a.dispDays == nil) { m.next() } }
        }
    }
}

// MARK: - Pouch strength + count (one screen)

struct PouchQ: View {
    @EnvironmentObject var m: OnboardingModel
    let mgs: [(Double, String)] = [(3, "3 mg"), (6, "6 mg"), (9, "8–10"), (13, "11+ mg")]
    let counts: [(Double, String)] = [(3, "1–4 a day"), (7, "5–9 a day"), (12, "10–14 a day"), (18, "15 or more a day")]
    var body: some View {
        ScreenBox {
            TopBar(progress: m.progress, onBack: m.back)
            TitleBlock(title: "Tell us about your pouches", sub: "Check the can if you're not sure.")
            FieldLabel(text: "Strength")
            Seg(items: mgs, value: m.a.pouchMg) { v in m.set { $0.pouchMg = v } }
            FieldLabel(text: "How many").padding(.top, 28)
            VStack(spacing: 10) {
                ForEach(counts, id: \.0) { d in PlainOptRow(label: d.1, on: m.a.pouchesPerDay == d.0) { m.set { $0.pouchesPerDay = d.0 } } }
            }
        } bottom: {
            BottomBar { CTA(title: "Continue", disabled: m.a.pouchMg == nil || m.a.pouchesPerDay == nil) { m.next() } }
        }
    }
}

// MARK: - Cost reveal

func durationYears(_ d: String?) -> Double {
    ["lt6m": 0.3, "6to12m": 0.75, "1to3y": 2, "3to5y": 4, "5y": 6][d ?? "1to3y"] ?? 2
}

struct CostReveal: View {
    @EnvironmentObject var m: OnboardingModel
    var body: some View {
        let yr = Calc.yearlySpend(m.a)
        ScreenBox {
            TopBar(progress: m.progress, onBack: m.back)
            VStack(spacing: 0) {
                Eyebrow(text: "At your current pace", color: T.danger)
                CountUp(target: Double(yr), ms: 1400) { v in
                    Text(Calc.money(Int(jsRound(v)))).font(sf(64, 780)).tracking(-2).monospacedDigit().foregroundStyle(T.danger).frame(height: 64)
                }
                Text("a year goes into your \(what(m.a))").font(sf(19, 600)).foregroundStyle(T.text).padding(.top, 8)
                Card(padding: EdgeInsets(top: 16, leading: 14, bottom: 12, trailing: 14)) {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach([1, 2, 3, 5, 10], id: \.self) { y in
                            VStack(spacing: 6) {
                                Text(cumLabel(yr, y)).font(sf(12, 700)).monospacedDigit().foregroundStyle(T.text)
                                UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 4, bottomTrailingRadius: 4, topTrailingRadius: 8)
                                    .fill(LinearGradient(colors: [T.dangerA(0.35), T.danger], startPoint: .bottom, endPoint: .top))
                                    .frame(maxWidth: 40).frame(height: CGFloat(y) / 10 * 120 + 6)
                                Text("\(y) yr").font(sf(11.5)).foregroundStyle(T.muted)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 160, alignment: .bottom)
                }
                .padding(.top, 26)
                ListCard(rows: [
                    ("Every month", Calc.money(Int(jsRound(Double(yr) / 12)))),
                    ("Already spent since you started", "≈ " + Calc.money(Int(jsRound(Double(yr) * durationYears(m.a.duration))))),
                ])
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 30)
        } bottom: {
            BottomBar { CTA(title: "I want that money back") { m.next() } }
        }
    }

    func cumLabel(_ yr: Int, _ y: Int) -> String {
        let raw = Double(yr * y)
        let v = jsRound(raw / 100) * 100 >= 10000 ? jsRound(raw / 1000) * 1000 : raw
        var s = Calc.money(v)
        if s.hasSuffix(",000") { s = String(s.dropLast(4)) + "k" }
        return s
    }
}

// MARK: - Reframe after failed attempts

struct Reframe: View {
    @EnvironmentObject var m: OnboardingModel
    var body: some View {
        let tried = m.a.tried != "never"
        ScreenBox {
            TopBar(progress: m.progress, onBack: m.back)
            TitleBlock(title: tried ? "It wasn't a willpower problem." : "Cold turkey is the hard way.",
                       sub: tried
                       ? "Going from your usual dose to zero overnight is when cravings, irritability and bad sleep hit hardest. Most people need more than one try. That isn't failure, it's withdrawal."
                       : "Going from your usual dose to zero overnight is when cravings, irritability and bad sleep hit hardest. That is why so many first attempts end in a few days.")
            Card(padding: EdgeInsets(top: 16, leading: 14, bottom: 12, trailing: 14)) {
                TaperCompare()
                HStack(spacing: 18) {
                    legend(T.danger, "Cold turkey")
                    legend(T.accent, "Step-down plan")
                }
                .padding(.top, 8)
            }
            SubText(text: "This time your body steps down a little each week, so no single day is a cliff.", size: 14).padding(.top, 16)
        } bottom: {
            BottomBar { CTA(title: "That makes sense") { m.next() } }
        }
    }
    func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(c).frame(width: 10, height: 10)
            Text(t).font(sf(13)).foregroundStyle(T.muted)
        }
    }
}

/// 300×150 SVG chart: cold-turkey cliff vs step-down staircase, drawn in.
struct TaperCompare: View {
    @State private var d1: CGFloat = Env.still ? 1 : 0
    @State private var d2: CGFloat = Env.still ? 1 : 0
    @State private var pop: Double = Env.still ? 1 : 0

    struct Poly: Shape {
        let pts: [CGPoint]
        func path(in r: CGRect) -> Path {
            let s = r.width / 300
            var p = Path()
            p.move(to: CGPoint(x: pts[0].x * s, y: pts[0].y * s))
            for q in pts.dropFirst() { p.addLine(to: CGPoint(x: q.x * s, y: q.y * s)) }
            return p
        }
    }
    // stroke-dasharray 700 → trim fraction of path length
    static let cold = [CGPoint(x: 8, y: 30), CGPoint(x: 70, y: 30), CGPoint(x: 70, y: 128), CGPoint(x: 292, y: 128)]
    static let step: [CGPoint] = {
        var p = [CGPoint(x: 8, y: 30), CGPoint(x: 70, y: 30)]
        let xs: [CGFloat] = [70, 120, 170, 220, 270, 292]
        let ys: [CGFloat] = [54, 78, 100, 118, 128]
        for i in 0..<5 { p.append(CGPoint(x: xs[i], y: ys[i])); p.append(CGPoint(x: xs[i + 1], y: ys[i])) }
        return p
    }()
    static func len(_ p: [CGPoint]) -> CGFloat { zip(p, p.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) } }

    var body: some View {
        GeometryReader { g in
            let s = g.size.width / 300
            ZStack(alignment: .topLeading) {
                Text("nicotine").font(.system(size: 10 * s)).foregroundStyle(T.muted).position(x: (4 + 20) * s, y: 8.5 * s)
                Text("weeks").font(.system(size: 10 * s)).foregroundStyle(T.muted).position(x: (262 + 14) * s, y: 142.5 * s)
                Path { p in p.move(to: CGPoint(x: 4 * s, y: 132 * s)); p.addLine(to: CGPoint(x: 296 * s, y: 132 * s)) }
                    .stroke(T.line, lineWidth: 1.5 * s)
                Poly(pts: Self.cold).trim(from: 0, to: d1 * 700 / Self.len(Self.cold))
                    .stroke(T.danger, style: StrokeStyle(lineWidth: 3.5 * s, lineJoin: .round))
                Poly(pts: Self.step).trim(from: 0, to: d2 * 700 / Self.len(Self.step))
                    .stroke(T.accent, style: StrokeStyle(lineWidth: 3.5 * s, lineJoin: .round))
                Circle().fill(T.danger).frame(width: 8 * s, height: 8 * s).position(x: 70 * s, y: 128 * s).opacity(pop)
                Text("the crash").font(.system(size: 11 * s, weight: .semibold)).foregroundStyle(T.danger)
                    .fixedSize().position(x: (78 + 25) * s, y: 118 * s)
            }
        }
        .aspectRatio(2, contentMode: .fit)
        .onAppear {
            guard !Env.still else { return }
            withAnimation(.easeInOut(duration: 1.6)) { d1 = 1 }
            withAnimation(.easeInOut(duration: 1.6).delay(0.5)) { d2 = 1 }
            withAnimation(.easeIn(duration: 0.3).delay(1)) { pop = 1 }
        }
    }
}

// MARK: - Name + age

struct About: View {
    @EnvironmentObject var m: OnboardingModel
    @State private var name = ""
    @FocusState private var focused: Bool
    let ages = ["18–24", "25–34", "35–44", "45+"]
    var body: some View {
        ScreenBox {
            TopBar(progress: m.progress, onBack: m.back)
            TitleBlock(title: "Last thing. A bit about you", sub: "So your plan feels like yours.")
            FieldLabel(text: "First name")
            TextField("", text: $name, prompt: Text("Your first name").foregroundStyle(Color(hex: 0x757575)))
                .font(sf(17)).foregroundStyle(T.text).tint(T.accent)
                .textContentType(.givenName).textInputAutocapitalization(.words).autocorrectionDisabled()
                .submitLabel(.done).focused($focused)
                .padding(.horizontal, 16).frame(height: 56)
                .background(RoundedRectangle(cornerRadius: 16).fill(T.surface)
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(focused ? T.accent : T.line, lineWidth: 1.5)))
            FieldLabel(text: "Age").padding(.top, 22)
            Seg(items: ages.map { ($0, $0) }, value: m.a.age) { v in focused = false; m.set { $0.age = v } }
        } bottom: {
            BottomBar {
                CTA(title: "See my results", disabled: m.a.age == nil) {
                    focused = false
                    let n = name.trimmingCharacters(in: .whitespaces)
                    m.set { $0.name = n.isEmpty ? nil : n }
                    m.next()
                }
            }
        }
        .onAppear { name = m.a.name ?? "" }
    }
}
