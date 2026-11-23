import Foundation
import SwiftUI
import Combine

@MainActor
public final class FocusManager: ObservableObject {
    public static let shared = FocusManager()

    @Published public var isFocusActive: Bool = false
    @Published public var activeFocusMode: FocusMode?
    @Published public var knownModes: [FocusMode] = FocusManager.builtInModes

    public var onFocusChanged: ((FocusMode?, Bool) -> Void)?

    private var pollTimer: Timer?
    private var lastIdentifier: String?
    private var logProcess: Process?

    public static let builtInModes: [FocusMode] = [
        FocusMode(identifier: "com.apple.donotdisturb.mode.default", name: "Do Not Disturb", symbol: "moon.fill", tintColor: OrielColors.indigo),
        FocusMode(identifier: "com.apple.focus.work", name: "Work", symbol: "person.lanyardcard.fill", tintColor: OrielColors.teal),
        FocusMode(identifier: "com.apple.focus.personal-time", name: "Personal", symbol: "person.fill", tintColor: OrielColors.purple),
        FocusMode(identifier: "com.apple.sleep.sleep-mode", name: "Sleep", symbol: "bed.double.fill", tintColor: OrielColors.teal),
        FocusMode(identifier: "com.apple.donotdisturb.mode.driving", name: "Driving", symbol: "car.fill", tintColor: OrielColors.indigo),
        FocusMode(identifier: "com.apple.donotdisturb.mode.workout", name: "Fitness", symbol: "figure.run", tintColor: OrielColors.green),
        FocusMode(identifier: "com.apple.focus.reading", name: "Reading", symbol: "book.closed.fill", tintColor: OrielColors.orange),
        FocusMode(identifier: "com.apple.focus.mindfulness", name: "Mindfulness", symbol: "apple.mindfulness", tintColor: OrielColors.teal),
        FocusMode(identifier: "com.apple.focus.gaming", name: "Gaming", symbol: "gamecontroller.fill", tintColor: OrielColors.indigo),
        FocusMode(identifier: "com.apple.focus.reduce-interruptions", name: "Reduce Interruptions", symbol: "apple.intelligence", tintColor: OrielColors.purple)
    ]

    private init() {
        refreshFromDoNotDisturbDB(notify: false)
        startMonitoring()
    }

    public func startMonitoring() {
        // 1. Poll DoNotDisturb DB files (lightweight, works without special log entitlements)
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshFromDoNotDisturbDB(notify: true)
            }
        }
        // 2. Also stream donotdisturbd logs for instant response when permitted
        startLogStream()
    }

    public func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        logProcess?.terminate()
        logProcess = nil
    }

    private func startLogStream() {
        guard logProcess == nil else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        proc.arguments = [
            "stream",
            "--process", "donotdisturbd",
            "--style", "compact",
            "--predicate", "composedMessage CONTAINS \"Delivering state update\" OR composedMessage CONTAINS \"Delivering active mode update\""
        ]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            for line in chunk.components(separatedBy: .newlines) where !line.isEmpty {
                if let parsed = Self.parseLogLine(line) {
                    Task { @MainActor in
                        self?.applyFocusUpdate(identifier: parsed.identifier, symbol: parsed.symbol, tintName: parsed.tintColorName, notify: true)
                    }
                }
            }
        }

        do {
            try proc.run()
            logProcess = proc
        } catch {
            // DB polling still handles updates reliably
        }
    }

    public func refreshFromDoNotDisturbDB(notify: Bool) {
        let baseDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/DoNotDisturb/DB")
        let assertionsURL = baseDir.appendingPathComponent("Assertions.json")
        let configsURL = baseDir.appendingPathComponent("ModeConfigurations.json")

        if let cfgData = try? Data(contentsOf: configsURL),
           let cfgJSON = try? JSONSerialization.jsonObject(with: cfgData) as? [String: Any],
           let dataArr = cfgJSON["data"] as? [[String: Any]],
           let modeMap = dataArr.first?["modeConfigurations"] as? [String: Any] {
            var discovered = Self.builtInModes
            for (ident, raw) in modeMap {
                guard let dict = raw as? [String: Any],
                      let mode = dict["mode"] as? [String: Any] else { continue }
                let name = (mode["name"] as? String) ?? Self.defaultName(for: ident)
                let sym = (mode["symbolImageName"] as? String) ?? "moon.fill"
                let tint = (mode["tintColorName"] as? String) ?? "systemIndigoColor"
                let fm = FocusMode(identifier: ident, name: name, symbol: sym, tintColor: OrielColors.tintColor(named: tint))
                if let idx = discovered.firstIndex(where: { $0.identifier == ident }) {
                    discovered[idx] = fm
                } else {
                    discovered.append(fm)
                }
            }
            knownModes = discovered
        }

        guard let data = try? Data(contentsOf: assertionsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArr = json["data"] as? [[String: Any]],
              let store = dataArr.first else {
            return
        }

        let records = (store["storeAssertionRecords"] as? [[String: Any]]) ?? []
        if let active = records.first,
           let details = active["assertionDetails"] as? [String: Any],
           let modeId = details["assertionDetailsModeIdentifier"] as? String {
            applyFocusUpdate(identifier: modeId, symbol: nil, tintName: nil, notify: notify)
        } else {
            applyFocusUpdate(identifier: nil, symbol: nil, tintName: nil, notify: notify)
        }
    }

    private func applyFocusUpdate(identifier: String?, symbol: String?, tintName: String?, notify: Bool) {
        let normalizedID: String? = (identifier == "(null)" || identifier?.isEmpty == true) ? nil : identifier
        guard normalizedID != lastIdentifier else { return }
        lastIdentifier = normalizedID

        if let id = normalizedID {
            let existing = knownModes.first(where: { $0.identifier == id })
            let mode = FocusMode(
                identifier: id,
                name: existing?.name ?? Self.defaultName(for: id),
                symbol: symbol ?? existing?.symbol ?? Self.defaultSymbol(for: id),
                tintColor: tintName.map(OrielColors.tintColor(named:)) ?? existing?.tintColor ?? OrielColors.indigo
            )
            activeFocusMode = mode
            isFocusActive = true
            if notify {
                if id == "com.apple.sleep.sleep-mode" && AppSettings.shared.playSoundOnSleepFocus {
                    SoundManager.shared.play(.sleep)
                }
                onFocusChanged?(mode, true)
            }
        } else {
            let previous = activeFocusMode
            activeFocusMode = nil
            isFocusActive = false
            if notify, let prev = previous {
                onFocusChanged?(prev, false)
            }
        }
    }

    // Matches Oriel's FocusManager regexes against donotdisturbd logs
    nonisolated public static func parseLogLine(_ line: String) -> (identifier: String?, symbol: String?, tintColorName: String?)? {
        guard line.contains("activeModeIdentifier") else { return nil }
        let idPattern = #"activeModeIdentifier[:=]\s*([A-Za-z0-9._-]+|\(null\))"#
        let symPattern = #"symbolImageName:\s*([\w.]+)"#
        let tintPattern = #"tintColorName:\s*([\w.]+)"#

        let id = firstCapture(line, pattern: idPattern)
        let sym = firstCapture(line, pattern: symPattern)
        let tint = firstCapture(line, pattern: tintPattern)
        return (id == "(null)" ? nil : id, sym, tint)
    }

    nonisolated private static func firstCapture(_ text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[r])
    }

    public static func defaultName(for identifier: String) -> String {
        switch identifier {
        case "com.apple.donotdisturb.mode.default": return "Do Not Disturb"
        case "com.apple.donotdisturb.mode.driving": return "Driving"
        case "com.apple.donotdisturb.mode.workout": return "Fitness"
        case "com.apple.focus.gaming": return "Gaming"
        case "com.apple.focus.mindfulness": return "Mindfulness"
        case "com.apple.focus.personal-time": return "Personal"
        case "com.apple.focus.reading": return "Reading"
        case "com.apple.focus.reduce-interruptions": return "Reduce Interruptions"
        case "com.apple.sleep.sleep-mode": return "Sleep"
        case "com.apple.focus.work": return "Work"
        default:
            return identifier.components(separatedBy: ".").last?.capitalized ?? "Focus"
        }
    }

    public static func defaultSymbol(for identifier: String) -> String {
        builtInModes.first(where: { $0.identifier == identifier })?.symbol ?? "moon.fill"
    }
}
