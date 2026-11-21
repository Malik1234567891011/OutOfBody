import SwiftUI

/// Tabs (Today · Plan · SOS · You) + toast + celebrations + full-screen overlays (AppShell.tsx).
struct AppShell: View {
    @ObservedObject var m: AppModel
    @Environment(\.scenePhase) private var phase

    var body: some View {
        let d = m.d
        let celebrate = m.overlay == nil && m.screen == nil ? earned(m.s, d).first : nil
        ZStack {
            T.bg.ignoresSafeArea()
            TabScroll(tab: m.tab, focusCheckin: m.screen?.hasPrefix("checkin") ?? false)
                .id(m.tab)
                .accessibilityHidden(m.overlay != nil)
            // `.app::before`: content fades under the status bar
            VStack(spacing: 0) {
                LinearGradient(stops: [.init(color: T.bg, location: 0.7), .init(color: T.bgA(0), location: 1)], startPoint: .top, endPoint: .bottom).frame(height: 58)
                Spacer()
            }
            .ignoresSafeArea().allowsHitTesting(false)
            TabBar().accessibilityHidden(m.overlay != nil)
            if let t = m.toast {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Text(t.text).font(sf(15, 600)).foregroundStyle(T.text).lineLimit(1).minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                        if t.hasUndo {
                            Button("Undo") { m.runUndo() }.font(sf(15, 700)).foregroundStyle(T.accent).padding(.vertical, 10).padding(.horizontal, 12).buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 18).padding(.trailing, 8).frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color(hex: 0x1F2532)).shadow(color: .black.opacity(0.45), radius: 15, y: 12))
                    .padding(.horizontal, 18).padding(.bottom, 104)
                }
                .ignoresSafeArea()
                .transition(.offset(y: 16).combined(with: .opacity))
                .id(t.id)
            }
            if let c = celebrate {
                ZStack {
                    Color.black.opacity(0.58)
                    Confetti(top: 300, around: true)
                    VStack(spacing: 0) {
                        Icon(name: "star", size: 26).foregroundStyle(T.accentInk).frame(width: 64, height: 64).background(Circle().fill(T.accent)).padding(.bottom, 14)
                        Text(c.title).font(sf(22, 750)).tracking(-0.4).multilineTextAlignment(.center).foregroundStyle(T.text)
                        Text(c.sub).font(sf(14.5)).lineSpacing(lh(14.5, 1.4)).multilineTextAlignment(.center).foregroundStyle(T.muted).padding(.top, 6).padding(.bottom, 18)
                        AppCTA(title: "Nice") { m.update { $0.celebrated.append(c.key) } }
                    }
                    .padding(EdgeInsets(top: 26, leading: 22, bottom: 22, trailing: 22))
                    .frame(width: 312)
                    .background(RoundedRectangle(cornerRadius: 26).fill(T.surface).overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(T.accentA(0.25), lineWidth: 1)))
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .onAppear { Analytics.track("celebration_shown", ["key": c.key]) }
            }
            if let o = m.overlay {
                overlayView(o)
                    .transition(Env.still ? .identity : .offset(y: 36).combined(with: .opacity))
                    .zIndex(5)
            }
        }
        .environmentObject(m)
        .preferredColorScheme(.dark)
        .onChange(of: phase) { _, p in if p == .active { m.reloadFromDisk() } }
    }

    @ViewBuilder func overlayView(_ o: Overlay) -> some View {
        switch o {
        case .welcome(let s): WelcomeView(step: s).id("welcome")
        case .sos(let s): SosView(step: s).id("sos-\(s.rawValue)")
        case .review: ReviewView()
        case .quitday: QuitDayView()
        case .widgetguide: WidgetGuideView()
        }
    }
}

struct TabScroll: View {
    @EnvironmentObject var m: AppModel
    let tab: Tab
    let focusCheckin: Bool
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                Group {
                    switch tab {
                    case .today: TodayView(focus: focusCheckin)
                    case .plan: PlanView()
                    case .you: YouView()
                    }
                }
                .padding(.top, 54).padding(.horizontal, 20).padding(.bottom, 118)
            }
            .modifier(EnvScroll())
            .ignoresSafeArea()
            .onAppear {
                if focusCheckin { DispatchQueue.main.async { proxy.scrollTo("checkin", anchor: .center) } }
            }
        }
    }
}

/// OOB_SCROLL=<points>|end for screenshots (same offsets as shoot-app.mjs).
struct EnvScroll: ViewModifier {
    @State private var pos: Any?
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), let sc = Env.scroll {
            content.modifier(EnvScroll18(target: sc))
        } else {
            content
        }
    }
}

@available(iOS 18.0, *)
struct EnvScroll18: ViewModifier {
    let target: String
    @State private var pos = ScrollPosition(edge: .top)
    func body(content: Content) -> some View {
        content.scrollPosition($pos)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if target == "end" { pos.scrollTo(edge: .bottom) } else if let y = Double(target) { pos.scrollTo(y: y) }
                }
            }
    }
}

struct TabBar: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: 0) {
                tab(.today, "today", "Today")
                tab(.plan, "chart", "Plan")
                Button { haptic(20); m.openSos(source: "tab") } label: {
                    VStack(spacing: 3) {
                        AppIcon(name: "wind", size: 22).foregroundStyle(.white)
                            .frame(width: 54, height: 54)
                            .background(Circle().fill(T.danger).shadow(color: T.dangerA(0.4), radius: 11, y: 8))
                            .background(Circle().fill(T.bg).frame(width: 64, height: 64))
                            .padding(.top, -26)
                        Text("SOS").font(sf(11, 750)).foregroundStyle(T.danger)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PressScale(scale: 0.93))
                .accessibilityLabel("SOS")
                tab(.you, "you", "You")
            }
            .padding(.top, 8).padding(.horizontal, 10).padding(.bottom, 26)
            .frame(height: 86, alignment: .top)
            .background(
                Rectangle().fill(.ultraThinMaterial).overlay(Color(hex: 0x090B11).opacity(0.9))
                    .overlay(alignment: .top) { Rectangle().fill(T.line).frame(height: 1) }
            )
        }
        .ignoresSafeArea()
    }
    func tab(_ t: Tab, _ icon: String, _ label: String) -> some View {
        Button { m.setTab(t) } label: {
            VStack(spacing: 3) {
                AppIcon(name: icon, size: 23)
                Text(label).font(sf(11, 600))
            }
            .foregroundStyle(m.tab == t ? T.accent : Color(hex: 0x6C7486))
            .frame(maxWidth: .infinity).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
