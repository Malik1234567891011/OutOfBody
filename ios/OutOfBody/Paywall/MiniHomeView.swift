import SwiftUI

/// The app's home screen, small, playing inside the phone on paywall page 1 (MiniHome in paywall.tsx).
struct MiniHomeView: View {
    let a: Answers
    var animated = !Env.still
    @State private var used: Int?
    @State private var pulse = false
    let timer = Timer.publish(every: 1.4, on: .main, in: .common).autoconnect()

    var body: some View {
        let steps = Calc.plan(a)
        let budget = (steps.first ?? 0) == 0 ? 10 : steps[0]
        let unit = Calc.budgetUnit(a)
        let u = used ?? Int(jsRound(Double(budget) * 0.4))
        let left = budget - u
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(a.name.map { "Hey \($0)" } ?? "Today").font(sf(17, 700)).foregroundStyle(T.text)
                Spacer()
                Text("Day 3 · on plan").font(sf(10, 600)).foregroundStyle(T.accent)
            }
            ZStack {
                Circle().stroke(.white.opacity(0.1), lineWidth: 11).frame(width: 124, height: 124)
                Circle().trim(from: 0, to: 1 - Double(u) / Double(budget))
                    .stroke(T.accent, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                    .rotationEffect(.degrees(-90)).frame(width: 124, height: 124)
                    .animation(.easeInOut(duration: 0.4), value: u)
                VStack(spacing: 0) {
                    Text("\(left)").font(sf(34, 760)).tracking(-1).monospacedDigit().foregroundStyle(T.text)
                    Text("\(unit) left today").font(sf(10.5)).foregroundStyle(T.muted)
                }
            }
            .frame(width: 150, height: 150)
            .padding(.top, 16)
            Text("+ Log a \(unit == "pouches" ? "pouch" : "hit")").font(sf(13, 700)).foregroundStyle(T.accentInk)
                .frame(maxWidth: .infinity).frame(height: 38)
                .background(Capsule().fill(T.accent))
                .scaleEffect(pulse ? 0.94 : 1).animation(.easeInOut(duration: 0.15), value: pulse)
                .padding(.top, 14)
            HStack(spacing: 8) {
                miniTile(Calc.money(Int(jsRound(Double(Calc.yearlySpend(a)) / 365 * 3))), "kept so far")
                miniTile("SOS", "craving help", danger: true)
            }
            .padding(.top, 10)
            HStack(alignment: .bottom) {
                ForEach(Array(steps.prefix(6).enumerated()), id: \.offset) { i, s in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 4).fill(i == 0 ? T.accent : T.accentA(0.35))
                            .frame(width: 14, height: 8 + Double(s) / Double(max(1, steps[0])) * 26)
                        Text("W\(i + 1)").font(sf(8.5)).foregroundStyle(T.muted)
                    }
                    if i < min(6, steps.count) - 1 { Spacer(minLength: 0) }
                }
            }
            .padding(.vertical, 8).padding(.horizontal, 10)
            .frame(maxWidth: .infinity).frame(height: 62, alignment: .bottom)
            .background(RoundedRectangle(cornerRadius: 12).fill(T.surface))
            .padding(.top, 12)
            Spacer(minLength: 0)
        }
        .padding(.top, 40).padding(.horizontal, 14)
        .onReceive(timer) { _ in
            guard animated else { return }
            pulse = true
            let cur = used ?? Int(jsRound(Double(budget) * 0.4))
            used = Double(cur + 1) > Double(budget) * 0.9 ? Int(jsRound(Double(budget) * 0.4)) : cur + 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { pulse = false }
        }
    }

    func miniTile(_ k: String, _ l: String, danger: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(k).font(sf(15, 720)).foregroundStyle(danger ? T.danger : T.text)
            Text(l).font(sf(9.5)).foregroundStyle(T.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9).padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(T.surface))
    }
}

/// The 0.6× status bar drawn inside the phone mock.
struct MiniStatusBar: View {
    var body: some View {
        HStack {
            Text("9:41").font(.system(size: 10.2, weight: .semibold)).tracking(-0.12)
            Spacer()
            HStack(spacing: 3.6) {
                Image(systemName: "cellularbars").font(.system(size: 7.5, weight: .semibold))
                Image(systemName: "wifi").font(.system(size: 7.5, weight: .semibold))
                Image(systemName: "battery.100").font(.system(size: 9.5))
            }
        }
        .foregroundStyle(.white)
        .padding(.leading, 27.6).padding(.trailing, 18).padding(.top, 3.6)
        .frame(height: 32.4)
    }
}
