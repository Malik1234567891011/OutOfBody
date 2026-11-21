import SwiftUI

// CSS variables from web/src/index.css :root
extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

enum T {
    static let bg = Color(hex: 0x07090E)
    static let surface = Color(hex: 0x11151D)
    static let surface2 = Color(hex: 0x171C26)
    static let line = Color(hex: 0x232A37)
    static let text = Color(hex: 0xF3F5F9)
    static let muted = Color(hex: 0x8B93A5)
    static let accent = Color(hex: 0x4FE3B8)
    static let accentInk = Color(hex: 0x032018)
    static let accentSoft = Color(hex: 0x4FE3B8, alpha: 0.12)
    static let danger = Color(hex: 0xFF6B6B)
    static let warn = Color(hex: 0xFFB547)
    static let yellow = Color(hex: 0xE6D55A)
    static func accentA(_ a: Double) -> Color { Color(hex: 0x4FE3B8, alpha: a) }
    static func dangerA(_ a: Double) -> Color { Color(hex: 0xFF6B6B, alpha: a) }
    static func bgA(_ a: Double) -> Color { Color(hex: 0x07090E, alpha: a) }

    /// Dependence level colors (.lv0 … .lv3)
    static func level(_ l: Int) -> Color { [accent, yellow, warn, danger][max(0, min(3, l))] }
}

/// SF Pro at a CSS size + numeric weight (sizes map 1:1 px → pt).
func sf(_ size: CGFloat, _ weight: Int = 400) -> Font {
    let w: Font.Weight
    switch weight {
    case ..<450: w = .regular
    case ..<550: w = .medium
    case ..<660: w = .semibold
    case ..<745: w = .bold
    default: w = .heavy
    }
    return .system(size: size, weight: w)
}

/// Extra line spacing to reach a CSS line-height multiple (SF's natural line height ≈ 1.19 × size).
func lh(_ size: CGFloat, _ mult: CGFloat) -> CGFloat { max(0, size * (mult - 1.19)) }

/// Global "still" mode (OOB_STILL=1) skips animations, like ?still in the prototype.
enum Env {
    static let env = ProcessInfo.processInfo.environment
    static let still = env["OOB_STILL"] == "1"
    static let preset = env["OOB_PRESET"]
    static let screen = env["OOB_SCREEN"]
    /// App screenshots: OOB_SCENARIO=midweek OOB_TAB=plan OOB_SCROLL=560|end (OOB_SCREEN=none keeps auto overlays away)
    static let scenario = env["OOB_SCENARIO"]
    static let tab = env["OOB_TAB"]
    static let scroll = env["OOB_SCROLL"]
}
