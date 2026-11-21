import AppIntents
import Foundation

/// One tap = one logged hit. Runs in whichever process hosts it (widget extension for interactive
/// widgets and the Control Center control, the app for Shortcuts / Action Button) and writes straight
/// to the shared App Group state, then reloads every widget timeline.
struct LogHitIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a hit"
    static var description = IntentDescription("Adds one to today's count in OutOfBody.")
    static var openAppWhenRun = false

    @Parameter(title: "Source", default: "widget")
    var source: String

    init() {}
    init(source: String) { self.source = source }

    func perform() async throws -> some IntentResult {
        SharedStore.logFromOutside(source: Source(rawValue: source) ?? .widget)
        return .result()
    }
}
