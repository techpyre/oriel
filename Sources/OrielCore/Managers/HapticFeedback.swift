import Foundation
import AppKit

@MainActor
public final class HapticFeedback {
    public static let shared = HapticFeedback()

    private var lastTrigger: Date = .distantPast
    private let debounceInterval: TimeInterval = 0.04

    private init() {}

    public func perform(_ pattern: NSHapticFeedbackManager.FeedbackPattern = .alignment) {
        guard AppSettings.shared.enableHaptics else { return }
        let now = Date()
        guard now.timeIntervalSince(lastTrigger) >= debounceInterval else { return }
        lastTrigger = now
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}
