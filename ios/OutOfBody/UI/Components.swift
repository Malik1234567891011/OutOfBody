import SwiftUI

// MARK: - Icons (ported from the 24×24 SVGs in web/src/ui.tsx)

struct IconPath: Shape {
    let name: String
    func path(in rect: CGRect) -> Path {
        var p = Path()
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
        func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) {
            p.addRoundedRect(in: CGRect(x: x, y: y, width: w, height: h), cornerSize: CGSize(width: r, height: r), style: .circular)
        }
        func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
            p.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
        }
        func poly(_ pts: [CGPoint], close: Bool = false) {
            p.move(to: pts[0]); for q in pts.dropFirst() { p.addLine(to: q) }
            if close { p.closeSubpath() }
        }
        switch name {
        case "back": poly([P(15, 5), P(8, 12), P(15, 19)])
        case "close": poly([P(6, 6), P(18, 18)]); poly([P(18, 6), P(6, 18)])
        case "check": poly([P(5, 12.5), P(9.5, 17), P(19, 7.5)])
        case "disposable":
            rr(8, 2.5, 8, 19, 3); poly([P(8, 7), P(16, 7)]); circle(12, 17, 1)
        case "pod":
            rr(7.5, 7, 9, 14.5, 2.5)
            p.move(to: P(9.5, 7)); p.addLine(to: P(9.5, 4.5))
            p.addArc(center: P(10.5, 4.5), radius: 1, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            p.addLine(to: P(13.5, 3.5))
            p.addArc(center: P(13.5, 4.5), radius: 1, startAngle: .degrees(270), endAngle: .degrees(360), clockwise: false)
            p.addLine(to: P(14.5, 7))
            circle(12, 16.5, 1)
        case "refill":
            rr(7, 9, 10, 12.5, 2)
            poly([P(10, 9), P(10, 5), P(14, 5), P(14, 9)])
            poly([P(11, 2.5), P(13, 2.5), P(13, 5), P(11, 5)], close: true)
            poly([P(9.5, 13), P(14.5, 13)])
        case "pouch": circle(12, 12, 8.5); circle(12, 12, 5)
        case "combo": rr(4, 4, 6, 16, 2.2); circle(16.5, 14, 4.5)
        case "bell":
            p.move(to: P(6, 16)); p.addLine(to: P(6, 11))
            p.addArc(center: P(12, 11), radius: 6, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            p.addLine(to: P(18, 16)); p.addLine(to: P(19.5, 18)); p.addLine(to: P(4.5, 18)); p.closeSubpath()
            p.move(to: P(10, 20.5))
            p.addArc(center: P(12, 20.5), radius: 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
        case "lock":
            rr(5, 10.5, 14, 10, 2.5)
            p.move(to: P(8, 10.5)); p.addLine(to: P(8, 8))
            p.addArc(center: P(12, 8), radius: 4, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            p.addLine(to: P(16, 10.5))
        case "spark":
            for (a, b) in [(P(12, 3), P(12, 7)), (P(12, 17), P(12, 21)), (P(3, 12), P(7, 12)), (P(17, 12), P(21, 12)),
                           (P(6, 6), P(8.5, 8.5)), (P(15.5, 15.5), P(18, 18)), (P(6, 18), P(8.5, 15.5)), (P(15.5, 8.5), P(18, 6))] {
                poly([a, b])
            }
        case "star":
            poly([P(12, 2.8), P(14.8, 8.6), P(21.1, 9.5), P(16.5, 13.9), P(17.6, 20.2), P(12, 17.2),
                  P(6.4, 20.2), P(7.5, 13.9), P(2.9, 9.5), P(9.2, 8.6)], close: true)
        default: break
        }
        let s = rect.width / 24
        return p.applying(CGAffineTransform(scaleX: s, y: s).translatedBy(x: rect.minX / s, y: rect.minY / s))
    }
}

struct Icon: View {
    let name: String
    var size: CGFloat = 22
    var body: some View {
        let s = size / 24
        Group {
            if name == "star" {
                IconPath(name: name).fill()
            } else {
                IconPath(name: name).stroke(style: StrokeStyle(lineWidth: (name == "check" ? 2.6 : 1.8) * s, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Layout primitives

/// `.screen`: absolute inset 0, padding 56 top / 22 sides, column. Ignores safe area like the prototype.
struct ScreenBox<Content: View, Bottom: View>: View {
    var top: CGFloat = 56
    @ViewBuilder var content: Content
    @ViewBuilder var bottom: Bottom
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(.top, top)
                .padding(.horizontal, 22)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            bottom
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container)
    }
}

extension ScreenBox where Bottom == EmptyView {
    init(top: CGFloat = 56, @ViewBuilder content: () -> Content) {
        self.top = top; self.content = content(); self.bottom = EmptyView()
    }
}

/// `.bottom`: pinned to the bottom, padding 26/22/34, fades in from transparent to bg over 26pt.
struct BottomBar<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.top, 26).padding(.horizontal, 22).padding(.bottom, 34)
            .frame(maxWidth: .infinity)
            .background(
                VStack(spacing: 0) {
                    LinearGradient(colors: [T.bgA(0), T.bg], startPoint: .top, endPoint: .bottom).frame(height: 26)
                    T.bg
                }
            )
    }
}

struct TopBar: View {
    var progress: Double?
    var onBack: (() -> Void)?
    var body: some View {
        HStack(spacing: 12) {
            Button { onBack?() } label: {
                Icon(name: "back").foregroundStyle(T.text).frame(width: 40, height: 40).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(onBack == nil ? 0 : 1)
            .disabled(onBack == nil)
            .accessibilityLabel("Back")
            if let progress {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(T.line)
                        Capsule().fill(T.accent).frame(width: g.size.width * max(0.04, progress))
                            .animation(.easeInOut(duration: 0.4), value: progress)
                    }
                }
                .frame(height: 5)
            } else {
                Spacer(minLength: 0)
            }
            Color.clear.frame(width: 40, height: 40)
        }
        .frame(height: 44)
        .padding(.horizontal, -8)
    }
}

struct TitleText: View {
    let text: String
    var size: CGFloat = 30
    var align: TextAlignment = .leading
    var body: some View {
        Text(text)
            .font(sf(size, 700)).tracking(-0.6)
            .foregroundStyle(T.text)
            .multilineTextAlignment(align)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SubText: View {
    let text: String
    var size: CGFloat = 16
    var align: TextAlignment = .leading
    var body: some View {
        Text(text)
            .font(sf(size)).lineSpacing(lh(size, 1.4))
            .foregroundStyle(T.muted)
            .multilineTextAlignment(align)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// `.title-wrap`: margin 18 top / 24 bottom
struct TitleBlock: View {
    let title: String
    var sub: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TitleText(text: title)
            if let sub { SubText(text: sub) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 18).padding(.bottom, 24)
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = T.accent
    var body: some View {
        Text(text.uppercased()).font(sf(13, 600)).tracking(0.6).foregroundStyle(color)
            .padding(.top, 12).padding(.bottom, 6)
    }
}

struct Fine: View {
    let text: String
    var align: TextAlignment = .center
    var body: some View {
        Text(text).font(sf(12.5)).lineSpacing(lh(12.5, 1.4)).foregroundStyle(T.muted)
            .multilineTextAlignment(align).fixedSize(horizontal: false, vertical: true)
    }
}

/// `.fine.ok`: check + "No payment due now"
struct FineOK: View {
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Icon(name: "check", size: 14).foregroundStyle(T.accent)
            Text(text).font(sf(12.5, 500)).foregroundStyle(T.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10).padding(.bottom, 10)
    }
}

// MARK: - Options

struct Opt: Identifiable {
    let id: String
    let label: String
    var detail: String?
    var icon: String?
    var tag: String?
}

struct PressScale: ButtonStyle {
    var scale: CGFloat = 0.985
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct OptionRow: View {
    let o: Opt
    let on: Bool
    var multi = false
    let tap: () -> Void
    var body: some View {
        Button(action: tap) {
            HStack(spacing: 14) {
                if let icon = o.icon {
                    Icon(name: icon)
                        .foregroundStyle(on ? T.accent : T.text)
                        .frame(width: 38, height: 38)
                        .background(RoundedRectangle(cornerRadius: 11).fill(on ? T.accentA(0.14) : T.surface2))
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(o.label).font(sf(17, 600)).tracking(-0.2).foregroundStyle(T.text)
                        if let tag = o.tag {
                            Text(tag.uppercased()).font(sf(11, 700)).tracking(0.3).foregroundStyle(T.accentInk)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 6).fill(T.accent))
                        }
                    }
                    if let d = o.detail { Text(d).font(sf(13.5)).foregroundStyle(T.muted) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    let shape = RoundedRectangle(cornerRadius: multi ? 7 : 11)
                    shape.fill(on ? T.accent : .clear)
                    shape.strokeBorder(on ? T.accent : Color(hex: 0x3A4253), lineWidth: 1.5)
                    if on { Icon(name: "check", size: 14).foregroundStyle(T.accentInk) }
                }
                .frame(width: 22, height: 22)
            }
            .padding(.vertical, 14).padding(.horizontal, 16)
            .frame(minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 16).fill(on ? T.accentSoft : T.surface)
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(on ? T.accent : T.surface, lineWidth: 1.5))
            )
            .animation(.easeOut(duration: 0.15), value: on)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
    }
}

struct Options: View {
    let opts: [Opt]
    let selected: (String) -> Bool
    var multi = false
    let pick: (String) -> Void
    var body: some View {
        VStack(spacing: 10) {
            ForEach(opts) { o in OptionRow(o: o, on: selected(o.id), multi: multi) { pick(o.id) } }
        }
    }
}

/// `.seg` 4-column segmented row
struct Seg<V: Equatable>: View {
    let items: [(V, String)]
    let value: V?
    let pick: (V) -> Void
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                let on = value == it.0
                Button { pick(it.0) } label: {
                    Text(it.1).font(sf(15.5, 600)).foregroundStyle(on ? T.accent : T.text)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14).fill(on ? T.accentSoft : T.surface)
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(on ? T.accent : T.surface, lineWidth: 1.5))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct FieldLabel: View {
    let text: String
    var body: some View {
        Text(text).font(sf(14, 600)).foregroundStyle(T.muted).padding(.bottom, 8)
    }
}

// MARK: - CTA

struct CTA: View {
    let title: String
    var disabled = false
    var light = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(sf(17.5, 650)).tracking(-0.2)
                .foregroundStyle(disabled ? Color(hex: 0x556666) : (light ? .black : T.accentInk))
                .frame(maxWidth: .infinity).frame(height: 58)
                .background(Capsule().fill(disabled ? T.surface2 : (light ? .white : T.accent)))
                .contentShape(Capsule())
        }
        .buttonStyle(PressScale(scale: 0.98))
        .disabled(disabled)
    }
}

// MARK: - Count-up number (ease-out cubic, like useCountUp)

struct CountUp<Label: View>: View {
    let target: Double
    var ms: Double = 1200
    @ViewBuilder let label: (Double) -> Label
    @State private var start = Date()
    var body: some View {
        if Env.still {
            label(target)
        } else {
            TimelineView(.animation) { ctx in
                let k = min(1, ctx.date.timeIntervalSince(start) * 1000 / ms)
                label(target * (1 - pow(1 - k, 3)))
            }
            .onAppear { start = Date() }
        }
    }
}

// MARK: - Cards / rows

struct Card<Content: View>: View {
    var padding = EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 20).fill(T.surface))
    }
}

struct KVRow: View {
    let l: String
    let r: String
    var body: some View {
        HStack(spacing: 10) {
            Text(l).font(sf(15.5)).foregroundStyle(T.muted).lineLimit(1).minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            Text(r).font(sf(15.5, 650)).monospacedDigit().foregroundStyle(T.text).lineLimit(1).fixedSize()
        }
    }
}

struct ListCard: View {
    let rows: [(String, String)]
    var body: some View {
        Card {
            VStack(spacing: 12) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, r in KVRow(l: r.0, r: r.1) }
            }
        }
    }
}

/// The breathing radial glow (`.breath-orb`)
struct BreathOrb: View {
    var size: CGFloat
    @State private var on = false
    var body: some View {
        Circle()
            .fill(RadialGradient(stops: [
                .init(color: T.accentA(0.42), location: 0),
                .init(color: T.accentA(0.12), location: 0.38),
                .init(color: T.accentA(0), location: 0.68),
            ], center: .center, startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
            .scaleEffect(Env.still ? 0.82 : (on ? 1.06 : 0.82))
            .opacity(Env.still ? 0.75 : (on ? 1 : 0.75))
            .onAppear {
                guard !Env.still else { return }
                withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) { on = true }
            }
            .allowsHitTesting(false)
    }
}

/// Explicit multi-line heading with a CSS line-height tighter than SF's natural one
/// (SwiftUI ignores negative lineSpacing, so each line is its own Text).
struct Lines: View {
    let text: String
    let size: CGFloat
    var weight: Int = 700
    var lineHeight: CGFloat = 1.12
    var tracking: CGFloat = 0
    var body: some View {
        let natural = UIFont.systemFont(ofSize: size, weight: .bold).lineHeight
        VStack(spacing: size * lineHeight - natural) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, l in
                Text(l).font(sf(size, weight)).tracking(tracking).foregroundStyle(T.text).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
