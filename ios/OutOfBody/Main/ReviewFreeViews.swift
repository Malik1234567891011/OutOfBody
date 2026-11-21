import SwiftUI

// MARK: - Weekly step-down review (first open of a new week)

struct ReviewView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        let d = m.d
        let w = d.reviewWeek ?? max(1, d.weekIdx)
        let st = weekStats(m.s, w, d.t)
        let rough = st.under < 4
        SheetBox(top: 56) {
            ZStack(alignment: .top) {
                if !rough { Confetti(n: 30, top: 96 - 56, spread: 0.8, around: true).padding(.horizontal, -22) }
                VStack(spacing: 0) {
                    Eyebrow(text: "Step-down day").padding(.top, 0)
                    Text("Week \(w) done.").font(sf(40, 750)).tracking(-1.2).foregroundStyle(T.text).padding(.top, 4).padding(.bottom, 22)
                    VStack(spacing: 0) {
                        (Text("\(st.avg)").font(sf(56, 780)).tracking(-2) + Text("/day").font(sf(18, 600)).foregroundColor(T.muted))
                            .monospacedDigit().foregroundStyle(T.text)
                        Text("your average vs a budget of \(st.budget)").font(sf(14)).foregroundStyle(T.muted).padding(.top, 6)
                        HStack(spacing: 0) {
                            stat("\(st.under)/\(st.days)", "days under budget")
                            Rectangle().fill(T.line).frame(width: 1)
                            stat("\(st.beaten)", "cravings beaten")
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)
                        .overlay(alignment: .top) { Rectangle().fill(T.line).frame(height: 1) }
                        .padding(.top, 16)
                    }
                    .frame(maxWidth: .infinity).padding(20)
                    .background(RoundedRectangle(cornerRadius: 22).fill(T.surface))
                    VStack(spacing: 0) {
                        Text(rough ? "ROUGH WEEK" : "NEW BUDGET").font(sf(12.5, 700)).tracking(0.6).foregroundStyle(rough ? T.warn : T.accent)
                        if rough {
                            Text("Want to stay on \(st.budget) one more week?").font(sf(22, 720)).tracking(-0.4).multilineTextAlignment(.center).foregroundStyle(T.text).padding(.top, 6)
                        } else {
                            (Text("\(st.next) ").font(sf(46, 790)).tracking(-1.6) + Text("a day").font(sf(18, 600)).foregroundColor(T.muted))
                                .monospacedDigit().foregroundStyle(T.text).padding(.top, 4)
                        }
                        Text(rough ? "It moves your finish line by 7 days. Better than a step that feels too steep." : st.next == 0 ? "Zero week. The last step." : "Down from \(st.budget). Same method, smaller number.")
                            .font(sf(14)).lineSpacing(lh(14, 1.35)).multilineTextAlignment(.center).foregroundStyle(T.muted).padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 18).padding(.horizontal, 20)
                    .background(RoundedRectangle(cornerRadius: 22).fill(rough ? T.warn.opacity(0.07) : T.accentSoft)
                        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(rough ? T.warn : T.accent, lineWidth: 1.5)))
                    .padding(.top, 12)
                }
                .padding(.top, 64)
            }
        } bottom: {
            if !rough {
                AppCTA(title: "Let's go") { finish(false, w, st) }
            } else {
                AppCTA(title: "Stay on \(st.budget) another week") { finish(true, w, st) }
                LinkButton(title: "Step down to \(st.next) anyway") { finish(false, w, st) }
            }
        }
        .onAppear { Analytics.track("review_viewed", ["week": w, "under_days": st.under, "rough": rough]) }
    }
    func stat(_ b: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(b).font(sf(25, 760)).monospacedDigit().foregroundStyle(T.text)
            Text(l).font(sf(13)).foregroundStyle(T.muted)
        }
        .frame(maxWidth: .infinity)
    }
    func finish(_ stay: Bool, _ w: Int, _ st: WeekStats) {
        haptic(20)
        let newQuit = Calc.fmtDate(toDate(addDays(m.d.quitAt, 7)))
        m.update { x in
            if stay { x.budgets.insert(x.budgets[w - 1], at: w); x.extraWeeks += 1 }
            x.reviewed.append(w)
        }
        Analytics.track("plan_adapted", ["action": stay ? "stay" : "step_down", "from": "review", "week": w])
        m.open(nil)
        if stay { m.showToast("Staying on \(st.budget) this week. New finish: \(newQuit)") }
    }
}

// MARK: - Free mode Today

struct FreeTodayView: View {
    @EnvironmentObject var m: AppModel
    @State private var slip = false
    var body: some View {
        let d = m.d, s = m.s
        let t = hm(d.freeMs)
        let hours = d.freeMs / HOUR
        let next = MILESTONES.first { $0.h > hours }
        let prevH = MILESTONES.reversed().first { $0.h <= hours }?.h ?? 0
        let frac = next.map { (hours - prevH) / ($0.h - prevH) } ?? 1
        let inStr: String = next.map { n in
            let r = hm((n.h - hours) * HOUR)
            return r.d >= 1 ? plural(r.d, "day") : r.h >= 1 ? "\(r.h) h" : "\(r.m) min"
        } ?? ""
        VStack(spacing: 0) {
            Header(title: d.name.isEmpty ? "Today" : "Hey \(d.name)", chip: "Free mode")
            Ring(size: 262, stroke: 20, frac: d.slippedToday ? 0 : frac, color: T.accent, glow: true) {
                if d.slippedToday {
                    Text("Day 1 starts").font(sf(15.5, 500)).foregroundStyle(T.muted)
                    Text("tomorrow").font(sf(36, 780)).tracking(-1).foregroundStyle(T.text)
                } else {
                    Text("\(t.d >= 1 ? t.d : t.h)").font(sf(80, 780)).tracking(-3).monospacedDigit().foregroundStyle(T.text).frame(height: 76)
                    Text("\(t.d >= 1 ? (t.d == 1 ? "day" : "days") : t.h == 1 ? "hour" : "hours") nicotine-free").font(sf(15.5, 500)).foregroundStyle(T.muted).padding(.top, 6)
                    Text(t.d >= 1 ? "and \(plural(t.h, "hour"))" : "and \(plural(t.m, "minute"))").font(sf(12.5)).monospacedDigit().foregroundStyle(Color(hex: 0x626A7C)).padding(.top, 10)
                }
            }
            .padding(.top, 16)
            if let next, !d.slippedToday {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEXT UP · IN \(inStr.uppercased())").font(sf(12, 700)).tracking(0.5).foregroundStyle(T.accent)
                    (Text("\(next.t):").bold() + Text(" \(next.d.lowercased())")).font(sf(16.5)).foregroundStyle(T.text)
                }
                .card(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(T.accentA(0.22), lineWidth: 1))
                .padding(.top, 14)
            }
            Tiles2(money: d.moneyKept, beaten: d.beaten).padding(.top, 14)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Since your quit day").font(sf(16, 680)).foregroundStyle(T.text)
                    Spacer()
                    Text(Calc.fmtDate(toDate(d.quitAt))).font(sf(13.5, 500)).foregroundStyle(T.muted)
                }
                .padding(.bottom, 4)
                ForEach(MILESTONES, id: \.t) { ms in
                    let done = hours >= ms.h, isNext = ms == next
                    HStack(spacing: 12) {
                        CheckDot(done: done, accentBorder: isNext)
                        Text(ms.t).font(sf(15, 650)).foregroundStyle(isNext ? T.accent : T.text).frame(width: 94, alignment: .leading)
                        Text(ms.d).font(sf(14)).foregroundStyle(T.muted).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 11)
                    .overlay(alignment: .top) { Rectangle().fill(T.line).frame(height: 1) }
                }
                Fine(text: "General timelines. Everyone's body is different.", align: .leading).padding(.top, 10)
            }
            .card(EdgeInsets(top: 16, leading: 18, bottom: 12, trailing: 18))
            .padding(.top, 12)
            if !s.slips.isEmpty {
                (Text("Best run so far: ") + Text(plural(d.bestRunDays, "day")).bold().foregroundColor(T.text)).font(sf(14)).foregroundStyle(T.muted).padding(.top, 14)
            }
            Button { slip = true } label: {
                Text("I slipped").font(sf(16, 620)).foregroundStyle(Color(hex: 0xC5CBD6)).frame(maxWidth: .infinity).frame(height: 52)
                    .background(Capsule().strokeBorder(T.line, lineWidth: 1.5))
            }
            .buttonStyle(.plain).padding(.top, 14)
        }
        .alert("One slip isn't a relapse.", isPresented: $slip) {
            Button("Never mind", role: .cancel) {}
            Button("Log the slip") {
                haptic(14)
                m.update { $0.slips.append(Slip(at: now())) }
                Analytics.track("slip_logged", ["free_days": t.d])
                m.showToast("Logged. Tomorrow is day 1.")
            }
        } message: {
            Text("Day count keeps your best; tomorrow is day 1 of the next run. Log it so the record stays honest.")
        }
    }
}

// MARK: - Quit day

struct QuitDayView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        let d = m.d, s = m.s
        let card = QuitCard(name: s.answers.name ?? "", money: fmtMoney(d.moneyKept), beaten: d.beaten, weeks: s.budgets.count, from: "From \(d.startAmt) \(d.unit) a day to zero.")
        SheetBox(top: 56) {
            ZStack(alignment: .top) {
                BreathOrb(size: 340).opacity(0.7).position(x: (UIScreen.main.bounds.width - 44) / 2, y: 190 - 56)
                Confetti(n: 50, top: 192 - 56, spread: 0.8, around: true)
                VStack(spacing: 0) {
                    AppIcon(name: "leaf", size: 36).foregroundStyle(T.accentInk)
                        .frame(width: 92, height: 92).background(Circle().fill(T.accent).shadow(color: T.accentA(0.45), radius: 35))
                        .padding(.bottom, 28)
                    Text("You're\nnicotine-free.").font(sf(40, 750)).tracking(-1.2).multilineTextAlignment(.center).foregroundStyle(T.text)
                    Text(Calc.fmtDate(toDate(d.quitAt), withYear: true)).font(sf(30, 760)).tracking(-0.6).foregroundStyle(T.text)
                        .padding(.vertical, 10).padding(.horizontal, 22)
                        .background(RoundedRectangle(cornerRadius: 18).fill(T.surface).overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(T.accent, lineWidth: 1.5)))
                        .padding(.top, 14)
                    card.padding(.top, 26)
                }
                .frame(maxWidth: .infinity).padding(.top, 92)
            }
        } bottom: {
            AppCTA(title: "Start free mode") { m.update { $0.quitSeen = true }; m.open(nil) }
            ShareLink(item: Image(uiImage: renderCard(card)), preview: SharePreview("Nicotine-free", image: Image(uiImage: renderCard(card)))) {
                Text("Share my card").font(sf(15)).foregroundStyle(T.muted).padding(6).frame(maxWidth: .infinity)
            }
            .simultaneousGesture(TapGesture().onEnded { haptic(10); Analytics.track("quit_card_shared") })
        }
        .onAppear { Analytics.track("quit_day_reached", ["weeks": s.budgets.count, "beaten": d.beaten]) }
    }
    @MainActor func renderCard(_ c: QuitCard) -> UIImage {
        let r = ImageRenderer(content: c.frame(width: 350).padding(20).background(T.bg))
        r.scale = 3
        return r.uiImage ?? UIImage()
    }
}

struct QuitCard: View {
    let name: String, money: String, beaten: Int, weeks: Int, from: String
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("outofbody"); Spacer(); Text(name) }.font(sf(13, 750)).foregroundStyle(T.accent)
            HStack(spacing: 0) {
                cell(money, "kept"); div; cell("\(beaten)", "cravings beaten"); div; cell("\(weeks)", "weeks of steps")
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 16)
            Text(from).font(sf(13.5)).foregroundStyle(Color(hex: 0xC5CBD6)).frame(maxWidth: .infinity)
                .padding(.top, 12).overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.1)).frame(height: 1) }
                .padding(.top, 16)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22).fill(LinearGradient(colors: [Color(hex: 0x123B33), Color(hex: 0x0E1A24)], startPoint: .topLeading, endPoint: UnitPoint(x: 0.75, y: 0.9))))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(T.accentA(0.3), lineWidth: 1))
    }
    var div: some View { Rectangle().fill(.white.opacity(0.1)).frame(width: 1) }
    func cell(_ b: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(b).font(sf(24, 770)).monospacedDigit().foregroundStyle(T.text)
            Text(l).font(sf(12)).foregroundStyle(T.muted)
        }
        .frame(maxWidth: .infinity)
    }
}
