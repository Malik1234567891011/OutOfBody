import SafariServices
import StoreKit
import SuperwallKit
import SwiftUI

enum Legal {
    static let terms = URL(string: "https://outofbody.vercel.app/terms")!
    static let privacy = URL(string: "https://outofbody.vercel.app/privacy")!
    static let support = URL(string: "https://outofbody.vercel.app/support")!
}

/// In-app Safari for Terms / Privacy / Support.
struct SafariSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let v = SFSafariViewController(url: url)
        v.preferredControlTintColor = UIColor(red: 0.31, green: 0.89, blue: 0.72, alpha: 1)
        return v
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
extension URL: @retroactive Identifiable { public var id: String { absoluteString } }

/// Restore: StoreKit sync + Superwall restore. True when access is active afterwards.
@MainActor func restoreAll() async -> Bool {
    if PaywallGate.hasSuperwall { _ = await Superwall.shared.restorePurchases() }
    return await Store.shared.restore()
}

private func replan(_ x: inout AppState, _ a: Answers) {
    let budgets = Calc.plan(a)
    x.answers = a; x.budgets = budgets; x.extraWeeks = 0
    x.notifs = x.notifs.map { n in
        var n = n
        if n.id == "morning" { n.detail = "\"Today's budget: \(budgets.first ?? 0) \(Calc.budgetUnit(a)).\"" }
        return n
    }
}

private let DEVICES: [(Device, String)] = [(.disposable, "Disposable vape"), (.pod, "Pod vape"), (.refill, "Refillable vape"), (.pouch, "Nicotine pouches"), (.combo, "Vape and pouches")]

struct YouView: View {
    @EnvironmentObject var m: AppModel
    @State private var adding = false
    @State private var custom = ""
    @State private var device = false
    @State private var confirm: String?
    @State private var web: URL?
    @State private var manage = false
    @State private var plan = "Yearly · trial"

    var body: some View {
        let s = m.s, d = m.d, a = s.answers
        let weeks = Calc.weeks(a)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Text(String((a.name ?? "Y").prefix(1)).uppercased()).font(sf(27, 760)).foregroundStyle(T.accent)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(T.accentSoft).overlay(Circle().strokeBorder(T.accentA(0.35), lineWidth: 1.5)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(a.name ?? "You").font(sf(25, 760)).tracking(-0.5).foregroundStyle(T.text)
                    Text("Nicotine-free by \(Calc.fmtDate(toDate(d.quitAt), withYear: true))").font(sf(14.5, 620)).foregroundStyle(T.accent)
                    Text(dayLine(d)).font(sf(13)).foregroundStyle(T.muted)
                }
            }
            .padding(.top, 14)

            SectionTitle(text: "My reasons") {
                Button(adding ? "Done" : "Add") { adding.toggle() }.font(sf(15, 650)).foregroundStyle(T.accent).buttonStyle(.plain)
            }
            VStack(spacing: 0) {
                ForEach(Array(s.reasons.enumerated()), id: \.element) { i, r in
                    if i > 0 { Divider().overlay(T.line) }
                    HStack(spacing: 12) {
                        AppIcon(name: "heart", size: 17).foregroundStyle(T.muted)
                        Text(r).font(sf(15.5)).foregroundStyle(T.text).frame(maxWidth: .infinity, alignment: .leading)
                        Button { m.update { $0.reasons.removeAll { $0 == r } } } label: { Icon(name: "close", size: 15).foregroundStyle(T.muted).padding(4) }
                            .buttonStyle(.plain).padding(.trailing, -4).accessibilityLabel("Remove \(r)")
                    }
                    .padding(.vertical, 12).frame(minHeight: 50)
                }
                if s.reasons.isEmpty { Text("No reasons yet. Add one.").font(sf(15.5)).foregroundStyle(T.muted).frame(maxWidth: .infinity, minHeight: 50, alignment: .leading) }
                if adding {
                    VStack(alignment: .leading, spacing: 12) {
                        FlowLeft(spacing: 8) {
                            ForEach(REASONS.filter { !s.reasons.contains($0.label) }) { r in
                                Button { addReason(r.label) } label: {
                                    Text("+ \(r.label)").font(sf(13.5, 600)).foregroundStyle(T.accent).padding(.vertical, 7).padding(.horizontal, 12).background(Capsule().fill(T.accentSoft))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        HStack(spacing: 8) {
                            TextField("", text: $custom, prompt: Text("Or write your own").foregroundColor(T.muted))
                                .font(sf(15)).foregroundStyle(T.text).padding(.horizontal, 16).frame(height: 42)
                                .background(RoundedRectangle(cornerRadius: 12).fill(T.surface).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(T.line, lineWidth: 1.5)))
                            XSButton(title: "Add", disabled: custom.trimmingCharacters(in: .whitespaces).isEmpty) { addReason(custom.trimmingCharacters(in: .whitespaces)) }
                        }
                    }
                    .padding(.top, 12).padding(.bottom, 14)
                    .overlay(alignment: .top) { Rectangle().fill(T.line).frame(height: 1) }
                }
            }
            .listCard()

            SectionTitle("My pledge")
            PledgeCard()

            SectionTitle("Plan settings")
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Pace").font(sf(15.5)).foregroundStyle(T.text)
                    HStack(spacing: 8) {
                        ForEach([2, 4, 6, 8], id: \.self) { w in
                            Button {
                                guard w != weeks else { return }
                                haptic(10)
                                m.update { var na = $0.answers; na.weeks = Double(w); replan(&$0, na) }
                                Analytics.track("plan_adapted", ["action": "pace", "weeks": w])
                                m.showToast("\(w) weeks. Nicotine-free by \(Calc.fmtDate(toDate(addDays(s.start, 7 * w))))")
                            } label: {
                                Text("\(w) wk").font(sf(14.5, 600)).foregroundStyle(weeks == w ? T.accent : T.text)
                                    .frame(maxWidth: .infinity).frame(height: 42)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(weeks == w ? T.accentSoft : T.surface)
                                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(weeks == w ? T.accent : T.surface, lineWidth: 1.5)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 12)
                row(icon: a.device?.rawValue ?? "disposable", "What I use", right: DEVICES.first { $0.0 == a.device }?.1) { device = true }
                row(icon: "refresh", "Restart plan") { confirm = "restart" }
            }
            .listCard()

            SectionTitle("Check-ins")
            VStack(spacing: 0) {
                if !s.notifsAllowed {
                    HStack(spacing: 12) {
                        AppIcon(name: "bell", size: 18).foregroundStyle(T.muted)
                        Text("Notifications are off").font(sf(15.5, 600)).foregroundStyle(T.text).frame(maxWidth: .infinity, alignment: .leading)
                        XSButton(title: "Turn on") { m.askPermission() }
                    }
                    .padding(.vertical, 12).frame(minHeight: 50)
                }
                ForEach(Array(s.notifs.enumerated()), id: \.element.id) { i, n in
                    if i > 0 || !s.notifsAllowed { Rectangle().fill(T.line).frame(height: 1) }
                    NotifRow(n: n).opacity(s.notifsAllowed ? 1 : 0.45)
                }
            }
            .listCard()

            SectionTitle("Widgets")
            VStack(spacing: 0) {
                row(icon: "widget", "Lock-screen widget setup", right: s.setup.widget ? "Added" : nil, rightOK: true) {
                    Analytics.track("widget_guide_opened", ["from": "you"]); m.open(.widgetguide)
                }
            }
            .listCard()

            SectionTitle("Account")
            VStack(spacing: 0) {
                row(icon: "star", "Subscription", right: plan) { manage = true }
                row(icon: "refresh", "Restore purchases") {
                    Task {
                        let ok = await restoreAll()
                        m.showToast(ok ? "Purchases restored. You're all set." : "No active subscription found.")
                    }
                }
                row(icon: "book", "Terms") { web = Legal.terms }
                row(icon: "shield", "Privacy") { web = Legal.privacy }
                row(icon: "heart", "Support") { web = Legal.support }
            }
            .listCard()
            HStack(spacing: 8) {
                Icon(name: "lock", size: 16).foregroundStyle(T.accent)
                Text("Your data stays on this phone. No account, nothing sent to a server.").font(sf(13.5)).foregroundStyle(T.muted).lineSpacing(lh(13.5, 1.35))
            }
            .padding(.top, 16).padding(.horizontal, 4)
            Button { confirm = "erase" } label: {
                HStack(spacing: 8) { AppIcon(name: "trash", size: 17); Text("Erase all data").font(sf(15.5, 620)) }
                    .foregroundStyle(T.danger).frame(maxWidth: .infinity).padding(15)
                    .background(RoundedRectangle(cornerRadius: 16).fill(T.surface))
            }
            .buttonStyle(.plain).padding(.top, 16)
        }
        .sheet(isPresented: $device) { DeviceSheet { p in m.update { replan(&$0, p) }; device = false; Analytics.track("plan_adapted", ["action": "device"]); m.showToast("Plan updated to match") } }
        .sheet(item: $web) { SafariSheet(url: $0).ignoresSafeArea() }
        .manageSubscriptionsSheet(isPresented: $manage)
        .alert(confirm == "restart" ? "Restart your plan?" : "Erase all data?", isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } })) {
            Button("Cancel", role: .cancel) { confirm = nil }
            Button(confirm == "restart" ? "Restart" : "Erase", role: .destructive) {
                if confirm == "erase" { m.erase() } else { restart() }
                confirm = nil
            }
        } message: {
            Text(confirm == "restart" ? "Your plan starts again from week 1 today. Your logs and cravings beaten stay." : "This deletes your plan, logs, and reasons from this phone. It can’t be undone.")
        }
        .task { await loadPlan() }
    }

    func dayLine(_ d: Derived) -> String {
        if d.free {
            let n = Int(floor((d.t - d.quitAt) / DAY))
            return n == 0 ? "Quit day is today" : "\(plural(n, "day")) since quit day"
        }
        return "Day \(d.dayIdx + 1) of \(d.totalWeeks * 7)"
    }

    func addReason(_ r: String) {
        if !r.isEmpty && !m.s.reasons.contains(r) { m.update { $0.reasons.append(r) } }
        custom = ""; adding = false
    }

    func restart() {
        m.update { x in
            replan(&x, x.answers)
            x.start = midnight(now()); x.reviewed = []; x.adaptiveDone = []; x.quitSeen = false; x.slips = []
            let old = x.notifs
            x.notifs = defaultNotifs(x.answers, Calc.plan(x.answers).first ?? 0, Calc.budgetUnit(x.answers)).map { n in
                var n = n; n.on = old.first { $0.id == n.id }?.on ?? true; return n
            }
        }
        Analytics.track("plan_adapted", ["action": "restart"])
        m.setTab(.today)
        m.showToast("Fresh start. Day 1 is today.")
    }

    func loadPlan() async {
        for await r in Transaction.currentEntitlements {
            if case .verified(let t) = r {
                let yearly = t.productID == Config.productId
                plan = (yearly ? "Yearly" : "Weekly") + (t.offerType == .introductory ? " · trial" : "")
            }
        }
    }

    func row(icon: String, _ l: String, right: String? = nil, rightOK: Bool = false, _ action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 12) {
                    AppIcon(name: icon, size: 18).foregroundStyle(T.muted)
                    Text(l).font(sf(15.5)).foregroundStyle(T.text).frame(maxWidth: .infinity, alignment: .leading)
                    if let right { Text(right).font(sf(14, rightOK ? 600 : 400)).foregroundStyle(rightOK ? T.accent : T.muted).lineLimit(1) }
                    AppIcon(name: "chev", size: 16).foregroundStyle(T.muted)
                }
                .padding(.vertical, 12).frame(minHeight: 50).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .overlay(alignment: .top) { Rectangle().fill(T.line).frame(height: 1) }
    }
}

extension View {
    /// `.card.list`: padding 2/16, rows separated by lines. The first row's top line is hidden by the clip.
    func listCard() -> some View {
        VStack(spacing: 0) { self }
            .padding(.horizontal, 16).padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20).fill(T.surface))
            .mask(RoundedRectangle(cornerRadius: 20).padding(.top, 1.5).padding(.top, -1.5))
    }
}

struct NotifRow: View {
    @EnvironmentObject var m: AppModel
    let n: Notif
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(n.label).font(sf(15.5)).foregroundStyle(T.text)
                Text(n.detail).font(sf(12.5)).lineSpacing(lh(12.5, 1.3)).foregroundStyle(T.muted).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let time = n.time {
                ZStack {
                    HStack(spacing: 4) {
                        if let w = n.when { Text(w).foregroundStyle(T.muted) }
                        Text(fmtTime(time)).foregroundStyle(T.text)
                    }
                    .font(sf(13.5, 620)).monospacedDigit()
                    .padding(.vertical, 6).padding(.horizontal, 9)
                    .background(RoundedRectangle(cornerRadius: 10).fill(T.surface2))
                    DatePicker("", selection: Binding(get: { timeDate(time) }, set: { v in
                        let c = Calendar.current.dateComponents([.hour, .minute], from: v)
                        let t = String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
                        m.update { x in if let i = x.notifs.firstIndex(where: { $0.id == n.id }) { x.notifs[i].time = t } }
                        Analytics.track("checkin_time_changed", ["kind": n.id, "time": t])
                    }), displayedComponents: .hourAndMinute)
                    .labelsHidden().opacity(0.02).frame(width: 60)
                }
                .fixedSize()
            }
            OOBToggle(on: n.on) { v in
                m.update { x in if let i = x.notifs.firstIndex(where: { $0.id == n.id }) { x.notifs[i].on = v } }
                Analytics.track("checkin_toggled", ["kind": n.id, "on": v])
            }
            .accessibilityLabel(n.label)
        }
        .padding(.vertical, 12).frame(minHeight: 50)
    }
    func timeDate(_ t: String) -> Date {
        let p = t.split(separator: ":").compactMap { Int($0) }
        return Calendar.current.date(bySettingHour: p.first ?? 8, minute: p.count > 1 ? p[1] : 0, second: 0, of: Date()) ?? Date()
    }
}

func fmtTime(_ t: String) -> String {
    let p = t.split(separator: ":").compactMap { Int($0) }
    let h = p[0], mm = p[1]
    return "\(h % 12 == 0 ? 12 : h % 12):\(String(format: "%02d", mm)) \(h < 12 ? "am" : "pm")"
}

/// Left-aligned wrapping row (`.chips.left`).
struct FlowLeft: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 340
        var x: CGFloat = 0, y: CGFloat = 0, rh: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x > 0 && x + z.width > w { x = 0; y += rh + spacing; rh = 0 }
            x += z.width + spacing; rh = max(rh, z.height)
        }
        return CGSize(width: w, height: y + rh)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, rh: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x > b.minX && x + z.width > b.maxX { x = b.minX; y += rh + spacing; rh = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(z))
            x += z.width + spacing; rh = max(rh, z.height)
        }
    }
}

struct DeviceSheet: View {
    @EnvironmentObject var m: AppModel
    @Environment(\.dismiss) var dismiss
    let onSave: (Answers) -> Void
    @State private var dev: Device = .disposable
    @State private var amt = "30"
    static let HITS = [Opt(id: "15", label: "10–20 times"), Opt(id: "30", label: "20–40 times"), Opt(id: "50", label: "40–60 times"), Opt(id: "75", label: "Honestly, all day")]
    static let POUCHES = [Opt(id: "4", label: "1–5 pouches"), Opt(id: "8", label: "6–10 pouches"), Opt(id: "12", label: "11–15 pouches"), Opt(id: "18", label: "16 or more")]
    var body: some View {
        let pouch = dev == .pouch
        SheetBox(top: 20, onClose: { dismiss() }) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    TitleText(text: "What do you use?").padding(.top, 18).padding(.bottom, 16)
                    Options(opts: DEVICES.map { Opt(id: $0.0.rawValue, label: $0.1, icon: $0.0.rawValue) }, selected: { $0 == dev.rawValue }) { id in
                        dev = Device(rawValue: id) ?? .disposable; amt = id == "pouch" ? "8" : "30"
                    }
                    Text(pouch ? "Pouches a day" : "Times a day you pick it up").font(sf(21, 700)).tracking(-0.6).foregroundStyle(T.text).padding(.top, 26).padding(.bottom, 12)
                    Options(opts: pouch ? Self.POUCHES : Self.HITS, selected: { $0 == amt }) { amt = $0 }
                }
                .padding(.bottom, 150)
            }
            .padding(.horizontal, -22).contentMargins(.horizontal, 22, for: .scrollContent)
        } bottom: {
            AppCTA(title: "Update my plan") {
                var a = m.s.answers
                a.device = dev
                if pouch { a.pouchesPerDay = Double(amt) } else { a.hitsPerDay = Double(amt) }
                onSave(a)
            }
        }
        .presentationBackground(T.bg)
        .onAppear {
            let a = m.s.answers
            dev = a.device ?? .disposable
            let opts = dev == .pouch ? Self.POUCHES : Self.HITS
            let cur = (dev == .pouch ? a.pouchesPerDay : a.hitsPerDay) ?? 0
            amt = opts.min { abs(Double($0.id)! - cur) < abs(Double($1.id)! - cur) }?.id ?? opts[1].id
        }
    }
}
