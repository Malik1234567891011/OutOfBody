import CoreImage
import SwiftUI

/// CSS `filter:` chains applied to the lung illustrations (index.css .lc-before / .lc-after), in sRGB like the browser.
enum CSSFilter {
    case saturate(Double), brightness(Double), contrast(Double), sepia(Double)
    var matrix: (r: [Double], g: [Double], b: [Double], bias: Double) {
        switch self {
        case .saturate(let s):
            return ([0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s],
                    [0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s],
                    [0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s], 0)
        case .sepia(let a):
            let k = 1 - a
            return ([0.393 + 0.607 * k, 0.769 - 0.769 * k, 0.189 - 0.189 * k],
                    [0.349 - 0.349 * k, 0.686 + 0.314 * k, 0.168 - 0.168 * k],
                    [0.272 - 0.272 * k, 0.534 - 0.534 * k, 0.131 + 0.869 * k], 0)
        case .brightness(let b): return ([b, 0, 0], [0, b, 0], [0, 0, b], 0)
        case .contrast(let c): return ([c, 0, 0], [0, c, 0], [0, 0, c], 0.5 - 0.5 * c)
        }
    }
    private static var cache: [String: UIImage] = [:]
    static func apply(_ name: String, _ fs: [CSSFilter]) -> UIImage? {
        if let c = cache[name] { return c }
        guard let src = UIImage(named: name), let cg = src.cgImage else { return nil }
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        // Chrome runs CSS filter shorthands in sRGB (verified against the prototype screenshot).
        let ctx = CIContext(options: [.workingColorSpace: srgb, .outputColorSpace: srgb])
        var img = CIImage(cgImage: cg)
        for f in fs {
            let m = f.matrix
            let cm = CIFilter(name: "CIColorMatrix")!
            cm.setValue(img, forKey: kCIInputImageKey)
            cm.setValue(CIVector(x: m.r[0], y: m.r[1], z: m.r[2], w: 0), forKey: "inputRVector")
            cm.setValue(CIVector(x: m.g[0], y: m.g[1], z: m.g[2], w: 0), forKey: "inputGVector")
            cm.setValue(CIVector(x: m.b[0], y: m.b[1], z: m.b[2], w: 0), forKey: "inputBVector")
            cm.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            cm.setValue(CIVector(x: m.bias, y: m.bias, z: m.bias, w: 0), forKey: "inputBiasVector")
            img = cm.outputImage!.applyingFilter("CIColorClamp")
        }
        guard let out = ctx.createCGImage(img, from: img.extent) else { return nil }
        let ui = UIImage(cgImage: out)
        cache[name] = ui
        return ui
    }
    static let before: [CSSFilter] = [.saturate(0.75), .brightness(0.72), .contrast(1.15), .sepia(0.15)]
    static let after: [CSSFilter] = [.brightness(1.12), .saturate(1.05)]
}

struct PlanView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        let d = m.d, s = m.s
        let pct = Int(jsRound(d.progress * 100))
        let vape = Calc.usesVape(s.answers)
        VStack(spacing: 0) {
            Header(title: "Your plan", chip: d.free ? "Complete" : "Week \(d.weekIdx + 1) of \(d.totalWeeks)")
            ZStack(alignment: .bottom) {
                if vape {
                    GeometryReader { g in
                        ZStack {
                            if let b = CSSFilter.apply("lungs-before.jpg", CSSFilter.before) {
                                Image(uiImage: b).resizable().scaledToFill().frame(width: g.size.width, height: g.size.height).clipped().opacity(1 - d.progress)
                            }
                            if let a = CSSFilter.apply("lungs-after.jpg", CSSFilter.after) {
                                Image(uiImage: a).resizable().scaledToFill().frame(width: g.size.width, height: g.size.height).clipped().opacity(d.progress)
                            }
                        }
                    }
                } else {
                    let mx = Double(max(1, s.budgets.max() ?? 1))
                    GeometryReader { g in
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(Array(s.budgets.enumerated()), id: \.offset) { i, b in
                                let st = i < d.weekIdx || d.free ? 0 : i == d.weekIdx ? 1 : 2
                                UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 3, bottomTrailingRadius: 3, topTrailingRadius: 8)
                                    .fill(st == 1 ? T.accent : T.accentA(st == 0 ? 0.45 : 0.2))
                                    .shadow(color: st == 1 ? T.accentA(0.45) : .clear, radius: 12)
                                    .frame(height: g.size.height * (0.12 + Double(b) / mx * 0.78))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: g.size.height, alignment: .bottom)
                    }
                    .padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 82)
                }
                LinearGradient(stops: [.init(color: .black.opacity(0), location: 0.45), .init(color: .black.opacity(0.78), location: 1)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Plan progress").font(sf(15, 650)).foregroundStyle(T.text)
                        Spacer()
                        Text("\(pct)%").font(sf(24, 700)).monospacedDigit().foregroundStyle(T.accent)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.18))
                            Capsule().fill(T.accent).frame(width: g.size.width * Double(max(2, pct)) / 100)
                        }
                    }
                    .frame(height: 6).padding(.top, 8)
                    Text(vape ? "An illustration of your plan's progress, not a scan." : "\(d.free ? "Every step done." : "Step \(d.weekIdx + 1) of \(d.totalWeeks).") From \(d.startAmt) \(d.unit) a day to zero.")
                        .font(sf(11.5)).foregroundStyle(.white.opacity(0.58)).padding(.top, 7)
                }
                .padding(.horizontal, 16).padding(.bottom, 14)
            }
            .frame(height: vape ? 252 : 200)
            .background(vape ? AnyShapeStyle(Color.black) : AnyShapeStyle(EllipticalGradient(colors: [Color(hex: 0x10302A), Color(hex: 0x0B1016)], center: .top, startRadiusFraction: 0, endRadiusFraction: 0.7)))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .padding(.top, 12)

            if d.adaptive { AdaptiveCard() }

            SectionTitle(text: "Step-down") { Text("Finish \(Calc.fmtDate(toDate(d.quitAt)))").font(sf(13)).foregroundStyle(T.muted) }
            WeekChips()
            Last7()
            Patterns()
            Changing()
            SectionTitle("Totals")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                tot(fmtMoney(d.moneyKept), "money kept")
                tot("\(Int(jsRound(d.mgAvoided)).formatted(.number.locale(Locale(identifier: "en_US")))) mg", "nicotine avoided")
                tot("\(d.beaten)", "cravings beaten")
                tot("\(d.underDays)", "days under budget")
            }
            Fine(text: "Estimates from your answers and your logs.").frame(maxWidth: .infinity).padding(.top, 10)
        }
    }
    func tot(_ b: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(b).font(sf(23, 760)).tracking(-0.5).monospacedDigit().foregroundStyle(T.text)
            Text(l).font(sf(13)).foregroundStyle(T.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14).padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 18).fill(T.surface))
    }
}

struct WeekChips: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        let d = m.d, s = m.s
        let row = HStack(spacing: 6) {
            ForEach(Array(s.budgets.enumerated()), id: \.offset) { i, b in
                let on = i == d.weekIdx && !d.free, past = i < d.weekIdx || d.free
                VStack(spacing: 3) {
                    Text("W\(i + 1)").font(sf(11, 650)).foregroundStyle(on ? T.accent : T.muted)
                    Text("\(b)").font(sf(19, 760)).monospacedDigit().foregroundStyle(T.text)
                    Text(Calc.fmtDate(toDate(addDays(s.start, i * 7)))).font(sf(10)).foregroundStyle(T.muted).lineLimit(1).fixedSize()
                }
                .frame(minWidth: 44, maxWidth: .infinity)
                .padding(.top, 10).padding(.bottom, 9).padding(.horizontal, 2)
                .background(RoundedRectangle(cornerRadius: 14).fill(on ? T.accentSoft : T.surface)
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(on ? T.accent : .clear, lineWidth: 1.5)))
                .opacity(past ? 0.5 : 1)
            }
            VStack(spacing: 6) {
                AppIcon(name: "flag", size: 17).foregroundStyle(T.accent)
                Text(Calc.fmtDate(toDate(d.quitAt))).font(sf(10)).foregroundStyle(T.muted).lineLimit(1).fixedSize()
            }
            .frame(minWidth: 44, maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 2)
            .background(RoundedRectangle(cornerRadius: 14).fill(d.free ? T.accentSoft : T.surface)
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(d.free ? T.accent : .clear, lineWidth: 1.5)))
        }
        .fixedSize(horizontal: false, vertical: true)
        if s.budgets.count <= 7 { row } else {
            ScrollView(.horizontal, showsIndicators: false) { row.padding(.horizontal, 20) }.padding(.horizontal, -20)
        }
    }
}

struct Last7: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        let d = m.d, s = m.s
        let first = d.dayIdx < 6
        let last = d.totalWeeks * 7 - 7
        let days: [(di: Int, h: HistoryDay?, budget: Int, label: String)] = (0..<7).map { i in
            let di = (d.free ? last : first ? 0 : d.dayIdx - 6) + i
            let h = d.history.first { $0.d == di }
            let w = di / 7
            let wd = Calendar.current.component(.weekday, from: toDate(addDays(s.start, di)))
            let label = di == d.dayIdx ? "Today" : ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"][wd - 1]
            return (di, h, s.budgets.indices.contains(w) ? s.budgets[w] : 0, label)
        }
        let mx = Double(max(4, days.map { max($0.h?.used ?? 0, $0.budget) }.max() ?? 4)) * 1.12
        let H = 130.0
        VStack(spacing: 0) {
            SectionTitle(text: d.free ? "Your last plan week" : first ? "Your first week" : "Last 7 days") {
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(T.accent).frame(width: 8, height: 8)
                    Text("under").padding(.trailing, 4)
                    RoundedRectangle(cornerRadius: 2).fill(T.danger).frame(width: 8, height: 8).padding(.leading, 6)
                    Text("over")
                }
                .font(sf(12)).foregroundStyle(T.muted)
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, x in
                        let u = Double(x.h?.used ?? 0)
                        let today = x.di == d.dayIdx
                        VStack(spacing: 7) {
                            ZStack(alignment: .bottom) {
                                if let _ = x.h {
                                    UnevenRoundedRectangle(topLeadingRadius: 7, bottomLeadingRadius: 3, bottomTrailingRadius: 3, topTrailingRadius: 7)
                                        .fill(u > Double(x.budget) ? T.danger : T.accent).opacity(today ? 0.6 : 1)
                                        .frame(maxWidth: 30).frame(height: max(3, u / mx * H))
                                        .padding(.horizontal, 4)
                                    Text("\(Int(u))").font(sf(11, 650)).monospacedDigit().foregroundStyle(T.text)
                                        .offset(y: -(u / mx * H + 4))
                                } else {
                                    UnevenRoundedRectangle(topLeadingRadius: 7, bottomLeadingRadius: 3, bottomTrailingRadius: 3, topTrailingRadius: 7)
                                        .fill(T.line).frame(maxWidth: 30).frame(height: 3).padding(.horizontal, 4)
                                }
                                Line().stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                                    .foregroundStyle(.white.opacity(x.h == nil ? 0.14 : 0.38))
                                    .frame(height: 2).padding(.horizontal, -5)
                                    .offset(y: -(Double(x.budget) / mx * H))
                            }
                            .frame(maxWidth: .infinity).frame(height: H, alignment: .bottom)
                            Text(x.label).font(sf(11, today ? 700 : 400)).foregroundStyle(today ? T.text : T.muted).frame(height: 13).fixedSize()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 14)
                HStack(spacing: 6) {
                    Line().stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4])).foregroundStyle(.white.opacity(0.38)).frame(width: 18, height: 2)
                    Text("daily budget") + Text(first && !d.free ? " · fills in as the week goes" : "")
                }
                .font(sf(12)).foregroundStyle(T.muted).padding(.top, 10)
            }
            .card(EdgeInsets(top: 14, leading: 14, bottom: 12, trailing: 14))
        }
    }
}

struct Line: Shape {
    func path(in r: CGRect) -> Path { Path { p in p.move(to: CGPoint(x: r.minX, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY)) } }
}

struct Patterns: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        let d = m.d
        let mx = Double(max(1, d.hourHist.max() ?? 1))
        VStack(spacing: 0) {
            SectionTitle("Your patterns")
            VStack(alignment: .leading, spacing: 0) {
                if let p = d.pattern {
                    Text(p).font(sf(16, 660)).foregroundStyle(T.text)
                    HStack(spacing: 2) {
                        ForEach(0..<24, id: \.self) { h in
                            let n = Double(d.hourHist[h])
                            RoundedRectangle(cornerRadius: 4).fill(n > 0 ? T.accent : T.surface2).opacity(n > 0 ? 0.18 + 0.82 * n / mx : 1).frame(height: 28)
                        }
                    }
                    .padding(.top, 12)
                    AxisLabels().padding(.top, 6)
                    Fine(text: "From \(plural(d.daysWithLogs, "day")) of logs. Check-ins are timed around these.", align: .leading).padding(.top, 8)
                } else {
                    Text("Patterns show up after 2 days of logging.").font(sf(16, 660)).foregroundStyle(T.muted)
                    HStack(spacing: 2) { ForEach(0..<24, id: \.self) { _ in RoundedRectangle(cornerRadius: 4).fill(T.surface2).frame(height: 28) } }.padding(.top, 12)
                    Fine(text: d.daysWithLogs == 1 ? "One more day to go." : "Log each one today and tomorrow.", align: .leading).padding(.top, 8)
                }
            }
            .card(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        }
    }
}

struct Changing: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        let d = m.d, s = m.s
        let st = Double(d.startAmt)
        let halfIdx = s.budgets.firstIndex { Double($0) <= st / 2 } ?? -1
        let weekDone = (0..<(d.weekIdx + (d.free ? 1 : 0))).contains { w in
            let days = d.history.filter { $0.d / 7 == w }
            return days.count == 7 && days.reduce(0) { $0 + $1.used } <= days[0].budget * 7
        }
        let q = d.quitAt
        let items: [(t: String, at: Double, done: Bool)] = [
            ("First week under budget", addDays(s.start, 7), weekDone),
            ("Nicotine cut in half", addDays(s.start, max(0, halfIdx) * 7), halfIdx >= 0 && (d.free || d.weekIdx >= halfIdx)),
            ("Last step", addDays(s.start, (s.budgets.count - 1) * 7), d.free || d.weekIdx >= s.budgets.count - 1),
            ("Nicotine-free", q, d.free),
            ("72 h free: nicotine is out of your body", q + 3 * DAY, d.free && d.freeMs >= 3 * DAY),
            ("2–4 weeks free: cravings fade", addDays(q, 14), d.free && d.freeMs >= 14 * DAY),
            ("1–3 months free: easier breathing", addDays(q, 30), d.free && d.freeMs >= 60 * DAY),
        ]
        let nextI = items.firstIndex { !$0.done } ?? -1
        VStack(spacing: 0) {
            SectionTitle("What's changing")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, x in
                    HStack(spacing: 12) {
                        CheckDot(done: x.done, accentBorder: i == nextI)
                        Text(x.t).font(sf(14.5, i == nextI ? 650 : 400)).foregroundStyle(x.done || i == nextI ? T.text : Color(hex: 0xA6ADBB))
                            .lineSpacing(lh(14.5, 1.3)).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                        Text(x.done ? "Done" : "\(i < 4 ? "" : "from ")\(Calc.fmtDate(toDate(x.at)))").font(sf(12.5, x.done ? 650 : 400)).monospacedDigit()
                            .foregroundStyle(x.done ? T.accent : T.muted).lineLimit(1).fixedSize()
                    }
                    .padding(.vertical, 11)
                    .overlay(alignment: .bottom) { Rectangle().fill(T.line).frame(height: 1) }
                }
                Fine(text: "Body changes are general timelines, not a promise. Everyone is different.", align: .leading).padding(.top, 10)
            }
            .card(EdgeInsets(top: 4, leading: 16, bottom: 14, trailing: 16))
        }
    }
}

struct AdaptiveCard: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        let d = m.d
        let w = d.weekIdx
        let newQuit = Calc.fmtDate(toDate(addDays(d.quitAt, 7)))
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                AppIcon(name: "refresh", size: 15)
                Text("OVER BUDGET 3 OF THE LAST 4 DAYS").font(sf(12, 700)).tracking(0.5)
            }
            .foregroundStyle(T.warn)
            Text("This step feels steep. Stay on \(d.budget) another week?").font(sf(19.5, 720)).tracking(-0.3).lineSpacing(lh(19.5, 1.25))
                .foregroundStyle(T.text).padding(.top, 8).fixedSize(horizontal: false, vertical: true)
            Text("Your finish moves from \(Calc.fmtDate(toDate(d.quitAt))) to \(newQuit). A slower step you can keep beats a fast one you can't.")
                .font(sf(14)).lineSpacing(lh(14, 1.4)).foregroundStyle(T.muted).padding(.top, 6).fixedSize(horizontal: false, vertical: true)
            GeometryReader { g in
                HStack(spacing: 8) {
                    AppCTA(title: "Stay another week", height: 48, font: 15) { answer(true, w, d, newQuit) }.frame(width: (g.size.width - 8) * 1.25 / 2.25)
                    AppCTA(title: "Keep going", kind: .ghost, height: 48, font: 15) { answer(false, w, d, newQuit) }
                }
            }
            .frame(height: 48).padding(.top, 14)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(T.surface).overlay(RoundedRectangle(cornerRadius: 20).fill(T.warn.opacity(0.07))))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(T.warn, lineWidth: 1.5))
        .padding(.top, 12)
    }
    func answer(_ stay: Bool, _ w: Int, _ d: Derived, _ newQuit: String) {
        haptic(16)
        m.update { x in
            if stay { x.budgets.insert(x.budgets[w], at: w + 1); x.extraWeeks += 1 }
            x.adaptiveDone.append(w)
        }
        Analytics.track("plan_adapted", ["action": stay ? "stay" : "keep_going", "from": "adaptive", "week": w + 1])
        m.showToast(stay ? "Next week stays at \(d.budget). Finish moves to \(newQuit)" : "Keeping the plan. Next week: \(d.nextBudget ?? 0)")
    }
}
