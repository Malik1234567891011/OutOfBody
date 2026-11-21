import SwiftUI

struct TodayView: View {
    @EnvironmentObject var m: AppModel
    var focus: Bool = false
    var body: some View {
        if m.d.free { FreeTodayView() } else { PlanToday(focus: focus) }
    }
}

/// `.hdr`: big greeting + day chip
struct Header: View {
    let title: String
    let chip: String
    var body: some View {
        HStack(alignment: .center) {
            Text(title).font(sf(29, 760)).tracking(-0.7).foregroundStyle(T.text).lineLimit(1)
            Spacer(minLength: 8)
            Text(chip).font(sf(13, 650)).foregroundStyle(T.accent).lineLimit(1).fixedSize()
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 14).fill(T.accentSoft))
        }
        .frame(minHeight: 40)
        .padding(.top, 10).padding(.bottom, 4)
    }
}

struct Banner: View {
    let icon: String
    let text: Text
    var body: some View {
        HStack(spacing: 10) {
            AppIcon(name: icon, size: 18).foregroundStyle(T.accent)
            text.font(sf(14.5)).lineSpacing(lh(14.5, 1.35)).foregroundStyle(T.text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12).padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(T.surface).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(T.accentA(0.28), lineWidth: 1)))
        .padding(.top, 12)
    }
}

struct PlanToday: View {
    @EnvironmentObject var m: AppModel
    var focus = false
    var body: some View {
        let d = m.d
        let zero = d.budget == 0
        let leftFrac = d.budget > 0 ? Double(d.left) / Double(d.budget) : 0
        let state = d.over > 0 || (zero && d.used > 0) ? "over" : zero ? "zero" : leftFrac < 0.3 ? "low" : "ok"
        let color = state == "over" ? T.danger : state == "low" ? T.warn : T.accent
        let frac = state == "over" ? min(1, Double(d.over) / Double(max(1, d.budget))) : leftFrac
        let nearPct = Int(jsRound(d.pctUsed * 100))
        VStack(spacing: 0) {
            Header(title: d.name.isEmpty ? "Today" : "Hey \(d.name)", chip: "Day \(d.dayIdx + 1) · Week \(d.weekIdx + 1)")
            if d.stepDownToday {
                Banner(icon: "spark", text: Text("New budget today: ") + Text("\(d.budget)").bold() + Text(". Down from \(d.prevBudget ?? 0)."))
            }
            if zero {
                Banner(icon: "flag", text: Text("Last step.").bold() + Text(" Zero \(d.unit) this week. SOS is here whenever you need it."))
            }
            Ring(size: 262, stroke: 20, frac: frac, color: color, glow: true) {
                if state == "over" {
                    Text("+\(d.over)").font(sf(80, 780)).tracking(-3).monospacedDigit().foregroundStyle(T.danger).frame(height: 76)
                    Text("over today's budget").font(sf(15.5, 500)).foregroundStyle(T.muted).padding(.top, 6)
                } else {
                    Text("\(max(0, d.left))").font(sf(80, 780)).tracking(-3).monospacedDigit().foregroundStyle(T.text).frame(height: 76)
                        .contentTransition(.numericText())
                    Text("\(d.unitWord(d.left)) left today").font(sf(15.5, 500)).foregroundStyle(T.muted).padding(.top, 6)
                }
                Text("\(d.used) of \(d.budget) logged").font(sf(12.5)).monospacedDigit().foregroundStyle(Color(hex: 0x626A7C)).padding(.top, 10)
            }
            .padding(.top, 16)
            Group {
                if d.used == 0 && !zero { Text("Nothing logged yet. Tap below each time you pick it up.") }
                else if d.used > 0 && state == "ok" { Text("On track. Spread the other \(d.left) through your day.") }
                else if state == "low" && d.left > 0 { Text("You're at \(nearPct)%. \(plural(d.left, d.one, d.unit)) left. Spread them out.") }
                else if state == "low" && d.left == 0 { Text("That's today's budget. Anything more still gets logged.") }
                else if state == "over" { Text("Going over isn't failure; it's data. Keep logging so the plan stays honest.") }
                else if state == "zero" { Text("Every craving you ride out now is one less to come.") }
            }
            .font(sf(14.5)).lineSpacing(lh(14.5, 1.4)).multilineTextAlignment(.center)
            .foregroundStyle(state == "low" ? T.warn : state == "over" ? Color(hex: 0xFF9A9A) : T.muted)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .top)
            .padding(.horizontal, 14).padding(.top, 14)

            Button { m.logHit(.app) } label: {
                HStack(spacing: 8) {
                    AppIcon(name: "plus", size: 22)
                    Text("Log a \(d.one)").font(sf(18.5, 720)).tracking(-0.2)
                }
                .foregroundStyle(T.accentInk)
                .frame(maxWidth: .infinity).frame(height: 62)
                .background(Capsule().fill(T.accent).shadow(color: T.accentA(0.2), radius: 15, y: 10))
            }
            .buttonStyle(PressScale(scale: 0.97))
            .padding(.top, 12)

            Tiles2(money: d.moneyKept, beaten: d.beaten).padding(.top, 14)
            PlanCard().padding(.top, 12)
            TimelineStrip().padding(.top, 12)
            CheckInCard().id("checkin")
            if !m.s.setup.all { SetupCard().padding(.top, 12) }
        }
    }
}

struct Tiles2: View {
    let money: Double
    let beaten: Int
    var body: some View {
        HStack(spacing: 10) {
            tile(fmtMoney(money), "Kept so far")
            tile("\(beaten)", "Cravings beaten")
        }
    }
    func tile(_ k: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(sf(26, 760)).tracking(-0.6).monospacedDigit().foregroundStyle(T.text)
            Text(l).font(sf(13)).foregroundStyle(T.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14).padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 18).fill(T.surface))
    }
}

struct PlanCard: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        let d = m.d, s = m.s
        let mx = Double(max(s.budgets.max() ?? 1, 1))
        Button { m.setTab(.plan) } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This week").font(sf(13, 600)).foregroundStyle(T.muted)
                        (Text("\(d.budget)").font(sf(25, 760)).foregroundColor(T.text)
                         + Text("/day").font(sf(15, 600)).foregroundColor(T.muted)
                         + (d.nextBudget != nil ? Text(" → next week \(d.nextBudget!)") : Text(" · last step")).font(sf(15, 650)).foregroundColor(T.accent))
                            .tracking(-0.5).monospacedDigit()
                    }
                    Spacer()
                    AppIcon(name: "chev", size: 18).foregroundStyle(T.muted).padding(.top, 2)
                }
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(s.budgets.enumerated()), id: \.offset) { i, b in
                        VStack(spacing: 4) {
                            UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 3, bottomTrailingRadius: 3, topTrailingRadius: 6)
                                .fill(i == d.weekIdx ? T.accent : i < d.weekIdx ? Color.white.opacity(0.12) : T.accentA(0.22))
                                .frame(maxWidth: 30).frame(height: b == 0 ? 4 : 6 + Double(b) / mx * 34)
                            Text("W\(i + 1)").font(sf(10.5, i == d.weekIdx ? 700 : 400)).foregroundStyle(i == d.weekIdx ? T.accent : T.muted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 60, alignment: .bottom)
                .padding(.top, 12)
                Rectangle().fill(T.line).frame(height: 1).padding(.top, 12)
                HStack(spacing: 6) {
                    AppIcon(name: "flag", size: 15).foregroundStyle(T.accent)
                    (Text("Nicotine-free in ") + Text(plural(d.daysToQuit, "day")).bold().foregroundColor(T.text) + Text(" · \(Calc.fmtDate(toDate(d.quitAt)))"))
                        .font(sf(14)).foregroundStyle(T.muted)
                }
                .padding(.top, 12)
            }
            .padding(EdgeInsets(top: 16, leading: 18, bottom: 14, trailing: 18))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20).fill(T.surface))
        }
        .buttonStyle(.plain)
    }
}

struct TimelineStrip: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        let d = m.d
        var byHour = [Int](repeating: 0, count: 24)
        for l in d.todayLogs { byHour[hourOf(l.at)] += 1 }
        return VStack(spacing: 0) {
            HStack {
                Text("Today").font(sf(14.5, 650)).foregroundStyle(T.text)
                Spacer()
                Text(plural(d.used, d.one, d.unit)).font(sf(13.5, 500)).foregroundStyle(T.muted)
            }
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<24, id: \.self) { h in
                    let n = byHour[h]
                    VStack(spacing: 2) {
                        if n > 4 { Text("\(n)").font(sf(8.5, 700)).foregroundStyle(T.accent) }
                        ForEach(0..<min(n, 4), id: \.self) { _ in Circle().fill(T.accent).frame(width: 6, height: 6) }
                    }
                    .padding(.bottom, 3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .overlay(alignment: .bottom) { if h == d.hour { Rectangle().fill(T.muted).frame(height: 2) } }
                }
            }
            .frame(height: 40)
            .overlay(alignment: .bottom) { Rectangle().fill(T.line).frame(height: 1).offset(y: 1) }
            .padding(.top, 10)
            AxisLabels().padding(.top, 6)
        }
        .card(EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 16))
    }
}

struct AxisLabels: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(["12a", "6a", "12p", "6p", "12a"].enumerated()), id: \.offset) { i, t in
                Text(t).font(sf(10.5)).foregroundStyle(T.muted)
                if i < 4 { Spacer(minLength: 0) }
            }
        }
    }
}

private let MOODS: [(Mood, String, String)] = [(.good, "😌", "Good"), (.ok, "😐", "Okay"), (.hard, "😣", "Hard")]

struct CheckInCard: View {
    @EnvironmentObject var m: AppModel
    @State private var mood: Mood?
    @State private var note = ""
    @State private var justDone = false
    var body: some View {
        let d = m.d
        let k = dayKey(d.t)
        if d.hour < 12 && !d.morningDone {
            card {
                eyebrow("sun", "Morning check-in")
                Text("Commit to today's \(d.budget)?").font(sf(21, 720)).tracking(-0.4).foregroundStyle(T.text).padding(.top, 8)
                Text("One small promise each morning. Mornings set the tone.").font(sf(14)).lineSpacing(lh(14, 1.4)).foregroundStyle(T.muted).padding(.top, 4)
                AppCTA(title: "I'm in", height: 50, font: 16) {
                    haptic(14)
                    m.update { $0.checkins.append(CheckIn(date: k, kind: .morning)) }
                    Analytics.track("checkin_completed", ["kind": "morning"])
                    m.showToast("You're in. \(d.budget) for today.")
                }
                .padding(.top, 14)
            }
            .padding(.top, 12)
        } else if d.hour >= 18 && d.eveningDone == nil {
            card {
                eyebrow("moon", "Evening check-in")
                Text("How did today go?").font(sf(21, 720)).tracking(-0.4).foregroundStyle(T.text).padding(.top, 8)
                HStack(spacing: 8) {
                    ForEach(MOODS, id: \.0) { md in
                        Button { haptic(8); mood = md.0 } label: {
                            VStack(spacing: 4) {
                                Text(md.1).font(.system(size: 28))
                                Text(md.2).font(sf(13.5, 600)).foregroundStyle(T.text)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 16).fill(mood == md.0 ? T.accentSoft : T.surface2)
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(mood == md.0 ? T.accent : .clear, lineWidth: 1.5)))
                        }
                        .buttonStyle(PressScale(scale: 0.96))
                    }
                }
                .padding(.top, 14)
                if let mood {
                    TextField("", text: $note, prompt: Text("One line about today (optional)").foregroundColor(T.muted))
                        .font(sf(15)).foregroundStyle(T.text).padding(.horizontal, 16).frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 16).fill(T.surface).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(T.line, lineWidth: 1.5)))
                        .padding(.top, 12)
                        .onChange(of: note) { _, v in if v.count > 80 { note = String(v.prefix(80)) } }
                    AppCTA(title: "Save", height: 50, font: 16) {
                        haptic(14); justDone = true
                        let n = note.trimmingCharacters(in: .whitespaces)
                        m.update { $0.checkins.append(CheckIn(date: k, kind: .evening, mood: mood, note: n.isEmpty ? nil : n)) }
                        Analytics.track("checkin_completed", ["kind": "evening", "mood": mood.rawValue])
                    }
                    .padding(.top, 14)
                }
            }
            .padding(.top, 12)
        } else if let ev = d.eveningDone {
            let under = d.used <= d.budget
            let md = MOODS.first { $0.0 == ev.mood }
            card {
                eyebrow("moon", "Tonight · \(md?.1 ?? "") \(md?.2 ?? "")")
                Text(under ? "Under budget today. That counts." : "Slips don't reset anything.").font(sf(21, 720)).tracking(-0.4).foregroundStyle(T.text).padding(.top, 8)
                Text(under ? "\(plural(d.used, d.one, d.unit)) of \(d.budget). Same again tomorrow."
                     : "Tomorrow is a fresh budget of \(d.nextBudget != nil && d.dayIdx % 7 == 6 ? d.nextBudget! : d.budget). You're still on the plan.")
                    .font(sf(14)).lineSpacing(lh(14, 1.4)).foregroundStyle(T.muted).padding(.top, 4).fixedSize(horizontal: false, vertical: true)
                if let n = ev.note { Text("\"\(n)\"").font(sf(14.5).italic()).foregroundStyle(Color(hex: 0xB8BFCC)).padding(.top, 10) }
            }
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(under ? T.accentA(0.3) : .clear, lineWidth: 1))
            .overlay { if justDone && under { Confetti(n: 22, top: 40, spread: 0.6) } }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.top, 12)
        }
    }
    func card<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) { c() }.card(EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18))
    }
    func eyebrow(_ icon: String, _ t: String) -> some View {
        HStack(spacing: 6) {
            AppIcon(name: icon, size: 16)
            Text(t.uppercased()).font(sf(12.5, 700)).tracking(0.5)
        }
        .foregroundStyle(T.accent)
    }
}

struct SetupCard: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        let s = m.s
        let items: [(Bool, String, () -> Void)] = [
            (s.setup.widget, "Add the lock-screen widget", { Analytics.track("widget_guide_opened", ["from": "setup"]); m.open(.widgetguide) }),
            (s.setup.checkins, "Turn on check-ins", { m.askPermission() }),
            (s.setup.sos, "Try SOS once", { m.openSos(source: "setup") }),
            (s.setup.reasons, "Read your reasons", { m.open(.sos(.myreasons)) }),
        ]
        let done = items.filter(\.0).count
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Get set up").font(sf(16, 680)).foregroundStyle(T.text)
                Spacer()
                Text("\(done) of 4").font(sf(13.5, 500)).foregroundStyle(T.muted)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(T.line)
                    Capsule().fill(T.accent).frame(width: g.size.width * Double(done) / 4).animation(.easeInOut(duration: 0.4), value: done)
                }
            }
            .frame(height: 5).padding(.top, 10).padding(.bottom, 4)
            ForEach(Array(items.enumerated()), id: \.offset) { i, x in
                if i > 0 { Rectangle().fill(T.line).frame(height: 1) }
                Button(action: x.2) {
                    HStack(spacing: 12) {
                        CheckDot(done: x.0)
                        Text(x.1).font(sf(15.5)).foregroundStyle(x.0 ? T.muted : T.text)
                            .strikethrough(x.0, color: Color(hex: 0x4B5366))
                        Spacer()
                        if !x.0 { AppIcon(name: "chev", size: 16).foregroundStyle(T.muted) }
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .allowsHitTesting(!x.0)
            }
        }
        .card(EdgeInsets(top: 16, leading: 18, bottom: 8, trailing: 18))
    }
}
