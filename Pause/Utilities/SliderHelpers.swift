//
//  SliderHelpers.swift
//  Pause
//
//  Helper functions for non-linear sliders and time formatting
//

import Foundation
import SwiftUI

struct SliderHelpers {
    // Duration steps for session length (in seconds)
    // 30s, 1m, 2m, 3m, 4m, 5m, 10m, 15m, 20m, 30m, 45m, 1h, 1.5h, 2h, 3h, 5h, 10h
    static func durationSteps() -> [Int] {
        return [30, 60, 120, 180, 240, 300, 600, 900, 1200, 1800, 2700, 3600, 5400, 7200, 10800, 18000, 36000]
    }

    // Activation interval steps (in minutes)
    // 30s, 1m, 5m, 10m, 15m, 20m, 25m, 30m, 45m, 1h, 1h30m, 2h, 3h, 5h, 10h
    static func activationSteps() -> [Int] {
        return [0, 1, 5, 10, 15, 20, 25, 30, 45, 60, 90, 120, 180, 300, 600]
    }

    // Variance steps for time randomization (in seconds)
    // 0s, 5s, 10s, 15s, 30s, 1m, 2m, 5m, 10m
    static func varianceSteps() -> [Int] {
        return [0, 5, 10, 15, 30, 60, 120, 300, 600]
    }

    // Buffer steps for input delay (in seconds)
    // 1s, 2s, 5s, 10s, 15s, 30s, 1m, 1.5m, 2m, 3m, 5m
    static func bufferSteps() -> [Int] {
        return [1, 2, 5, 10, 15, 30, 60, 90, 120, 180, 300]
    }

    // Find slider index for a given duration value
    static func indexForDuration(_ duration: Int) -> Double {
        let steps = durationSteps()
        if let index = steps.firstIndex(of: duration) {
            return Double(index)
        }
        // Find closest
        for (index, step) in steps.enumerated() {
            if duration <= step {
                return Double(index)
            }
        }
        return Double(steps.count - 1)
    }

    // Find slider index for a given activation interval
    static func indexForActivation(_ minutes: Int) -> Double {
        let steps = activationSteps()
        if let index = steps.firstIndex(of: minutes) {
            return Double(index)
        }
        // Find closest
        for (index, step) in steps.enumerated() {
            if minutes <= step {
                return Double(index)
            }
        }
        return Double(steps.count - 1)
    }

    // Find slider index for a given variance value
    static func indexForVariance(_ variance: Int) -> Double {
        let steps = varianceSteps()
        if let index = steps.firstIndex(of: variance) {
            return Double(index)
        }
        // Find closest
        for (index, step) in steps.enumerated() {
            if variance <= step {
                return Double(index)
            }
        }
        return Double(steps.count - 1)
    }

    // Find slider index for a given buffer value
    static func indexForBuffer(_ buffer: Int) -> Double {
        let steps = bufferSteps()
        if let index = steps.firstIndex(of: buffer) {
            return Double(index)
        }
        // Find closest
        for (index, step) in steps.enumerated() {
            if buffer <= step {
                return Double(index)
            }
        }
        return Double(steps.count - 1)
    }

    // Format duration in seconds to human-readable string
    static func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            let mins = seconds / 60
            return "\(mins)m"
        } else {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            if mins == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(mins)m"
            }
        }
    }

    // Format activation interval in minutes to human-readable string
    static func formatActivation(_ minutes: Int) -> String {
        if minutes == 0 {
            return "30s"
        } else if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(mins)m"
            }
        }
    }

    // Format buffer time in seconds to human-readable string
    static func formatBuffer(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            let mins = seconds / 60
            let secs = seconds % 60
            if secs == 0 {
                return "\(mins)m"
            } else {
                return "\(mins)m \(secs)s"
            }
        }
    }

    // Format session time in seconds to h/m/s format
    static func formatSessionTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, secs)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }

    // Parse time string like "30", "30s", "2m", "1h", "1h 30m" into seconds
    static func parseTimeString(_ input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed.isEmpty { return nil }

        // Try plain number first (interpret as seconds)
        if let seconds = Int(trimmed) {
            return max(1, seconds)
        }

        var totalSeconds = 0
        let pattern = #"(\d+)\s*(h|m|s)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = regex.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))

        if matches.isEmpty { return nil }

        for match in matches {
            guard let numRange = Range(match.range(at: 1), in: trimmed),
                  let num = Int(trimmed[numRange]) else { continue }

            var unit = "s"
            if let unitRange = Range(match.range(at: 2), in: trimmed) {
                unit = String(trimmed[unitRange])
            }

            switch unit {
            case "h": totalSeconds += num * 3600
            case "m": totalSeconds += num * 60
            default: totalSeconds += num
            }
        }

        return totalSeconds > 0 ? totalSeconds : nil
    }

    // Parse time string into minutes (for activation intervals)
    // Returns minutes, with special case: "30s" returns 0 (which means 30s in the activation system)
    static func parseActivationInterval(_ input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed.isEmpty { return nil }

        // Special case for 30s (stored as 0)
        if trimmed == "30s" || trimmed == "30 s" { return 0 }

        // Try plain number (interpret as minutes)
        if let mins = Int(trimmed) { return max(1, mins) }

        // Parse with units
        guard let seconds = parseTimeString(input) else { return nil }
        let minutes = seconds / 60
        return minutes > 0 ? minutes : 1
    }
}

// Editable time field that shows formatted time and allows manual input
struct EditableTimeField: View {
    @Binding var seconds: Int
    let formatter: (Int) -> String
    let parser: (String) -> Int?
    var width: CGFloat = 60

    @State private var text: String = ""
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $text, onCommit: commit)
            .textFieldStyle(.plain)
            .frame(width: width, alignment: .trailing)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .focused($isFocused)
            .onAppear { text = formatter(seconds) }
            .onChange(of: seconds) { newValue in
                if !isFocused { text = formatter(newValue) }
            }
            .onChange(of: isFocused) { focused in
                if focused {
                    isEditing = true
                } else if isEditing {
                    commit()
                    isEditing = false
                }
            }
    }

    private func commit() {
        if let parsed = parser(text) {
            seconds = parsed
        }
        text = formatter(seconds)
    }
}
