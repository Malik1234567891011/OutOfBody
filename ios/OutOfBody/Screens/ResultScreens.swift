import SwiftUI

// MARK: - Analyzing (labor illusion)

struct Analyzing: View {
    @EnvironmentObject var m: OnboardingModel
    @State private var pct: Double = Env.still ? 100 : 0
    @State private var spin = false
    let timer = Timer.publish(every: 0.055, on: .main, in: .common).autoconnect()

    var body: some View {
        let steps = [
            "Converting your \(what(m.a)) into cigarettes",
            "Measuring your dependence",
            "Mapping your trigger moments",
            "Building your step-down plan",
        ]
        ScreenBox {
            VStack(spacing: 0) {
                ZStack {
                    Circle().stroke(T.line, lineWidth: 10).frame(width: 128, height: 128)
                    Circle().trim(from: 0, to: pct / 100)
                        .stroke(T.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 128, height: 128)
                    Text("\(Int(jsRound(pct)))%").font(sf(34, 750)).tracking(-1).foregroundStyle(T.text).offset(y: 0)
                }
                .frame(width: 170, height: 170)
                TitleText(text: "Analyzing your answers", align: .center).padding(.top, 22)
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                        let done = pct >= Double(i + 1) * 25
                        let active = !done && pct >= Double(i) * 25
                        HStack(spacing: 12) {
                            ZStack {
                                if done {
                                    Circle().fill(T.accent)
                                    Icon(name: "check", size: 13).foregroundStyle(T.accentInk)
                                } else if active {
                                    Circle().trim(from: 0.125, to: 0.875).stroke(T.accent, lineWidth: 1.5)
                                        .rotationEffect(.degrees(spin ? 360 : 0) - .degrees(90))
                                        .padding(0.75)
                                } else {
                                    Circle().strokeBorder(Color(hex: 0x333B4B), lineWidth: 1.5)
                                }
                            }
                            .frame(width: 22, height: 22)
                            Text(s).font(sf(15.5)).foregroundStyle(done || active ? T.text : Color(hex: 0x4B5366))
                                .animation(.easeInOut(duration: 0.3), value: done || active)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.top, 26)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 90)
        }
        .onAppear {
            withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) { spin = true }
        }
        .onReceive(timer) { _ in
            guard !Env.still, pct < 100 else { return }
            let n = min(100, pct + (pct < 60 ? 2 : pct < 85 ? 1 : 1.5))
            pct = n
            if n >= 100 {
                let here = m.idx
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { if m.idx == here { m.next() } }
            }
        }
    }
}

// MARK: - Results

struct Results: View {
    @EnvironmentObject var m: OnboardingModel
    var body: some View {
        let a = m.a
        let packs = Calc.packsPerDay(a)
        let dep = Calc.dependence(a)
        let cigs = Int(jsRound(Calc.cigsPerDay(a)))
        let usePacks = packs >= 1
        let unit = Calc.budgetUnit(a)
        ScreenBox {
            TopBar(onBack: m.back)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(text: "\(a.name.map { "\($0), here's" } ?? "Here's") what your \(what(a)) really \(a.device == .pouch ? "are" : "is")")
                    VStack(spacing: 0) {
                        CountUp(target: usePacks ? packs : Double(cigs), ms: 1300) { v in
                            Text("≈ " + (usePacks ? String(format: "%.1f", v) : String(Int(jsRound(v)))))
                                .font(sf(72, 780)).tracking(-2).monospacedDigit().foregroundStyle(T.danger).frame(height: 72)
                        }
                        Text(usePacks ? (packs == 1 ? "pack of cigarettes a day" : "packs of cigarettes a day") : "cigarettes a day")
                            .font(sf(19, 600)).foregroundStyle(T.text).padding(.top, 8)
                        Fine(text: "in nicotine, by our estimate")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16).padding(.bottom, 8)
                    HStack(spacing: 8) {
                        tile(String(Calc.startAmount(a)), unit == "pouches" ? "pouches a day" : "hits a day")
                        tile("\(Calc.nicotineMgPerDay(a)) mg", "nicotine a day")
                        tile(Calc.money(Calc.yearlySpend(a)), "a year", danger: true)
                    }
                    .padding(.top, 18)
                    Card {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("Dependence").font(sf(15.5)).foregroundStyle(T.muted)
                                Spacer()
                                Text(dep.label).font(sf(15.5, 700)).foregroundStyle(T.level(dep.level))
                            }
                            HStack(spacing: 5) {
                                ForEach(0..<4, id: \.self) { i in
                                    Capsule().fill(i <= dep.level ? T.level(i) : T.line).frame(height: 9)
                                }
                            }
                            .padding(.top, 12)
                            HStack(spacing: 0) {
                                ForEach(["Low", "Moderate", "High", "Very high"], id: \.self) { l in
                                    Text(l).font(sf(11)).foregroundStyle(T.muted).frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.top, 6)
                            Fine(text: a.firstHit == "lt5" || a.firstHit == "5to30"
                                 ? "Reaching for it within 30 minutes of waking is the strongest single sign of nicotine dependence."
                                 : "Your amount per day is the main driver here. Waiting a while after waking is a good sign.",
                                 align: .leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 12)
                        }
                    }
                    .padding(.top, 12)
                }
                .padding(.bottom, 130)
            }
            .padding(.horizontal, -22)
            .contentMargins(.horizontal, 22, for: .scrollContent)
        } bottom: {
            BottomBar { CTA(title: "How do I get out?") { m.next() } }
        }
    }

    func tile(_ k: String, _ l: String, danger: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(k).font(sf(20, 720)).tracking(-0.4).monospacedDigit().foregroundStyle(danger ? T.danger : T.text)
                .lineLimit(1).minimumScaleFactor(0.8)
            Text(l).font(sf(12)).foregroundStyle(T.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14).padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 16).fill(T.surface))
    }
}

// MARK: - Lungs before / after (drag to compare)

struct Lungs: View {
    @EnvironmentObject var m: OnboardingModel
    @State private var pos: CGFloat = 50
    var body: some View {
        ScreenBox {
            TopBar(progress: m.progress, onBack: m.back)
            TitleBlock(title: "Your lungs are waiting for you", sub: "Drag to compare.")
            GeometryReader { g in
                let w = g.size.width, h: CGFloat = 270
                ZStack(alignment: .topLeading) {
                    Color.black
                    img("lungs-after.jpg", w, h)
                    img("lungs-before.jpg", w, h)
                        .mask(alignment: .leading) { Rectangle().frame(width: w * pos / 100) }
                    tag("Nicotine every day").padding(.leading, 12).padding(.top, 12)
                    tag("Nicotine-free").frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 12).padding(.top, 12)
                    Rectangle().fill(.white).frame(width: 3, height: h).position(x: w * pos / 100, y: h / 2)
                    Text("‹ ›").font(sf(15, 700)).foregroundStyle(.black)
                        .frame(width: 38, height: 38).background(Circle().fill(.white))
                        .shadow(color: .black.opacity(0.4), radius: 7, y: 4)
                        .position(x: w * pos / 100, y: h / 2)
                }
                .frame(width: w, height: h)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    pos = max(4, min(96, v.location.x / w * 100))
                })
            }
            .frame(height: 270)
            .padding(.top, -6)
            VStack(alignment: .leading, spacing: 12) {
                tl("72 hours", "Nicotine is out of your body")
                tl("2–4 weeks", "Cravings fade, sleep and mood settle")
                tl("1–3 months", "Less coughing, easier breathing")
            }
            .padding(.top, 20)
        } bottom: {
            BottomBar { CTA(title: "I want that") { m.next() } }
        }
    }
    func img(_ n: String, _ w: CGFloat, _ h: CGFloat) -> some View {
        Image(uiImage: UIImage(named: n) ?? UIImage()).resizable().scaledToFill().frame(width: w, height: h).clipped()
    }
    func tag(_ t: String) -> some View {
        Text(t).font(sf(12, 650)).foregroundStyle(T.text)
            .padding(.vertical, 5).padding(.horizontal, 9)
            .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.55)))
    }
    func tl(_ t: String, _ d: String) -> some View {
        HStack(spacing: 10) {
            Circle().fill(T.accent).frame(width: 10, height: 10)
                .background(Circle().fill(T.accentSoft).frame(width: 18, height: 18))
                .frame(width: 14, alignment: .leading)
            Text(t).font(sf(15, 700)).foregroundStyle(T.text).frame(width: 92, alignment: .leading)
            Text(d).font(sf(14)).foregroundStyle(T.muted)
        }
    }
}

// MARK: - Plan (weekly budget bars)

struct StripeFill: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(T.dangerA(0.3)))
            // repeating-linear-gradient(45deg, .55 0–4px, .3 4–8px)
            let period: CGFloat = 8 * 2.squareRoot()
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + period / 2, y: size.height))
                p.addLine(to: CGPoint(x: x + period / 2 + size.height, y: 0))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                p.closeSubpath()
                ctx.fill(p, with: .color(T.dangerA(0.55)))
                x += period
            }
        }
    }
}

struct PlanScreen: View {
    @EnvironmentObject var m: OnboardingModel
    @State private var grown = Env.still
    var body: some View {
        let a = m.a
        let steps = Calc.plan(a)
        let start = Calc.startAmount(a)
        let unit = Calc.budgetUnit(a)
        let mx = Double(max(start, steps.max() ?? 0))
        let barShape = UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 4, bottomTrailingRadius: 4, topTrailingRadius: 8)
        ScreenBox {
            TopBar(progress: m.progress, onBack: m.back)
            TitleBlock(title: "Your step-down plan",
                       sub: "A daily \(unit == "pouches" ? "pouch" : "hit") budget that shrinks every week. Stay under it and you're winning.")
            Card(padding: EdgeInsets(top: 18, leading: 14, bottom: 16, trailing: 14)) {
                HStack(alignment: .bottom, spacing: 6) {
                    VStack(spacing: 6) {
                        Text("\(start)").font(sf(11.5, 650)).monospacedDigit().foregroundStyle(T.muted)
                        StripeFill().clipShape(barShape).frame(maxWidth: 34).frame(height: Double(start) / mx * 150)
                        Text("Now").font(sf(11)).foregroundStyle(T.muted)
                    }
                    .frame(maxWidth: .infinity)
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                        VStack(spacing: 6) {
                            Text("\(s)").font(sf(11.5, 650)).monospacedDigit().foregroundStyle(T.text)
                            Group {
                                if s == 0 {
                                    barShape.strokeBorder(T.accent, style: StrokeStyle(lineWidth: 2, dash: [5, 3])).frame(height: 10)
                                } else {
                                    barShape.fill(T.accent).frame(height: max(6, Double(s) / mx * 150))
                                }
                            }
                            .frame(maxWidth: 34)
                            .scaleEffect(x: 1, y: grown ? 1 : 0.001, anchor: .bottom)
                            .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.6).delay(Double(i) * 0.09), value: grown)
                            Text("W\(i + 1)").font(sf(11)).foregroundStyle(T.muted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 200, alignment: .bottom)
                HStack(spacing: 8) {
                    Icon(name: "spark", size: 18).foregroundStyle(T.accent)
                    (Text("Nicotine-free by ").foregroundColor(T.accent) + Text(Calc.fmtDate(Calc.quitDate(a), withYear: true)).bold().foregroundColor(T.text))
                        .font(sf(16))
                }
                .padding(.top, 16)
            }
            ListCard(rows: [
                ("This week's daily budget", "\(steps.first ?? 0) \(unit)"),
                ("Kept in your first year", Calc.money(Calc.savedByQuit(a))),
            ])
            .padding(.top, 26)
        } bottom: {
            BottomBar { CTA(title: "Continue") { m.next() } }
        }
        .onAppear { if !grown { DispatchQueue.main.async { grown = true } } }
    }
}
