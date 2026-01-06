//
//  DoomScrollDetector.swift
//  Pause
//
//  Detects doom scrolling patterns based on velocity, directionality, and minimal pauses
//

import Foundation
import AppKit

enum ScrollEventType {
    case scrollDown
    case scrollUp
    case keyDown
    case keyRight
    case keyUp
    case keyLeft
}

struct ScrollEvent {
    let timestamp: Date
    let type: ScrollEventType
    let delta: Double // For scroll wheel - magnitude of scroll
}

class DoomScrollDetector: ObservableObject {
    static let shared = DoomScrollDetector()

    private var eventQueue: [ScrollEvent] = []
    private let queueLock = NSLock()
    private var lastCheckTime: Date = Date()

    private let settings = Settings.shared

    // Published metrics for display in settings
    @Published var currentVelocity: Double = 0.0
    @Published var currentDirectionality: Double = 0.0
    @Published var currentMedianPause: Double = 0.0
    @Published var eventCount: Int = 0

    private init() {
        print("🎯 DoomScrollDetector: Initializing...")

        // Initialize with balanced event history to prevent false positives
        initializeEventQueueWithBalancedHistory()

        // Start periodic check timer (every 1 second) on main runloop
        DispatchQueue.main.async {
            let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.checkForDoomScrolling()
            }
            // Add to common run loop modes so it runs even when scrolling
            RunLoop.main.add(timer, forMode: .common)
            print("🎯 DoomScrollDetector: Timer scheduled on main runloop")
        }
        print("🎯 DoomScrollDetector: Initialized with 5-second check timer")
    }

    // MARK: - Event Recording

    func recordScrollEvent(deltaY: Double) {
        guard settings.doomScrollEnabled else {
            print("⚠️ Doom Scroll: Scroll event ignored - detection disabled in settings")
            return
        }

        // Ignore zero-delta events (momentum/noise)
        guard abs(deltaY) > 0.1 else {
            return
        }

        // In macOS with natural scrolling (default):
        // - Swipe UP on trackpad (consuming more content going down) = NEGATIVE deltaY = scrollDown (forward)
        // - Swipe DOWN on trackpad (going back up) = POSITIVE deltaY = scrollUp (backward)
        let type: ScrollEventType = deltaY < 0 ? .scrollDown : .scrollUp
        let event = ScrollEvent(timestamp: Date(), type: type, delta: abs(deltaY))

        queueLock.lock()
        eventQueue.append(event)
        let count = eventQueue.count
        queueLock.unlock()

        if count <= 10 {
            // Log first few events for debugging
            print("📝 Doom Scroll Event #\(count): \(type == .scrollDown ? "↓" : "↑") scroll (delta: \(String(format: "%.1f", abs(deltaY))))")
        }

        pruneOldEvents()
    }

    func recordKeyEvent(keyCode: UInt16) {
        guard settings.doomScrollEnabled else {
            print("⚠️ Doom Scroll: Key event ignored - detection disabled in settings")
            return
        }

        let type: ScrollEventType?
        let arrow: String

        switch keyCode {
        case 125: // Down arrow
            type = .keyDown
            arrow = "↓"
        case 126: // Up arrow
            type = .keyUp
            arrow = "↑"
        case 124: // Right arrow
            type = .keyRight
            arrow = "→"
        case 123: // Left arrow
            type = .keyLeft
            arrow = "←"
        default:
            type = nil
            arrow = ""
        }

        guard let eventType = type else { return }

        let event = ScrollEvent(timestamp: Date(), type: eventType, delta: 1.0)

        queueLock.lock()
        eventQueue.append(event)
        let count = eventQueue.count
        queueLock.unlock()

        // Log all key events for debugging
        print("📝 Doom Scroll Event #\(count): \(arrow) key")

        pruneOldEvents()
    }

    // MARK: - Event Management

    /// Initialize event queue with ~200 balanced events to prevent false positives at startup
    /// and after scroll-triggered activations. Half down, half up, low deltas, large pauses.
    private func initializeEventQueueWithBalancedHistory() {
        let eventCount = 200
        let halfCount = eventCount / 2
        let lowDelta = 2.0 // Low scroll delta
        let largePause = 3.0 // 3 seconds between events

        queueLock.lock()
        eventQueue.removeAll()

        // Create events starting from far in the past
        let startTime = Date().addingTimeInterval(-Double(eventCount) * largePause)

        // First half: scroll down events
        for i in 0..<halfCount {
            let timestamp = startTime.addingTimeInterval(Double(i * 2) * largePause)
            let event = ScrollEvent(timestamp: timestamp, type: .scrollDown, delta: lowDelta)
            eventQueue.append(event)
        }

        // Second half: scroll up events
        for i in 0..<halfCount {
            let timestamp = startTime.addingTimeInterval(Double(halfCount * 2 + i * 2) * largePause)
            let event = ScrollEvent(timestamp: timestamp, type: .scrollUp, delta: lowDelta)
            eventQueue.append(event)
        }

        queueLock.unlock()

        print("🎯 DoomScrollDetector: Initialized event queue with \(eventCount) balanced events (low delta, large pauses)")
    }

    private func pruneOldEvents() {
        let windowDuration = TimeInterval(settings.doomScrollWindowDuration * 60) // Convert minutes to seconds
        let cutoffTime = Date().addingTimeInterval(-windowDuration)

        queueLock.lock()
        eventQueue.removeAll { $0.timestamp < cutoffTime }
        queueLock.unlock()
    }

    // MARK: - Detection Logic

    private func checkForDoomScrolling() {
        print("⏰ DoomScrollDetector: checkForDoomScrolling() called - enabled: \(settings.doomScrollEnabled)")

        guard settings.doomScrollEnabled else {
            // Reset metrics when disabled
            DispatchQueue.main.async {
                self.currentVelocity = 0.0
                self.currentDirectionality = 0.0
                self.currentMedianPause = 0.0
                self.eventCount = 0
            }
            print("⏰ DoomScrollDetector: Detection disabled, skipping check")
            return
        }

        queueLock.lock()
        let events = eventQueue
        let count = eventQueue.count
        queueLock.unlock()

        print("⏰ DoomScrollDetector: Event queue contains \(count) events")

        // Update event count
        DispatchQueue.main.async {
            self.eventCount = count
        }

        guard !events.isEmpty else {
            // Update with zero values if no events
            DispatchQueue.main.async {
                self.currentVelocity = 0.0
                self.currentDirectionality = 0.0
                self.currentMedianPause = 0.0
            }
            print("⏰ DoomScrollDetector: No events in queue, skipping metric calculation")
            return
        }

        // Calculate metrics
        let velocity = calculateVelocity(events: events)
        let directionality = calculateDirectionality(events: events)
        let medianPause = calculateMedianPause(events: events)

        // Update published metrics
        DispatchQueue.main.async {
            self.currentVelocity = velocity
            self.currentDirectionality = directionality
            self.currentMedianPause = medianPause
        }

        // Log current values every check (helpful for debugging)
        print("📊 Doom Scroll Metrics - Events: \(count), Velocity: \(String(format: "%.1f", velocity))/min (need ≥\(settings.doomScrollVelocityThreshold)), Directionality: \(String(format: "%.2f", directionality)) (need ≥\(String(format: "%.2f", settings.doomScrollDirectionalityThreshold))), Median pause: \(String(format: "%.2f", medianPause))s (need ≤\(String(format: "%.1f", settings.doomScrollPauseThreshold)))")

        // Check if all conditions are met
        let velocityMet = velocity >= Double(settings.doomScrollVelocityThreshold)
        let directionalityMet = directionality >= settings.doomScrollDirectionalityThreshold
        let pauseMet = medianPause <= settings.doomScrollPauseThreshold

        if velocityMet && directionalityMet && pauseMet {
            // Doom scrolling detected! Trigger pause session
            DispatchQueue.main.async {
                AppState.shared.startPauseMode(displayText: self.settings.doomScrollMessage, isLocked: self.settings.doomScrollIsLocked, customDuration: self.settings.doomScrollCustomDuration)
            }

            // Reinitialize with balanced history to avoid immediate re-triggering
            initializeEventQueueWithBalancedHistory()

            // Reset metrics immediately
            DispatchQueue.main.async {
                self.currentVelocity = 0.0
                self.currentDirectionality = 0.0
                self.currentMedianPause = 0.0
                self.eventCount = 0
            }

            print("🚨 Doom scrolling detected! Velocity: \(String(format: "%.1f", velocity))/min, Directionality: \(String(format: "%.2f", directionality)), Median pause: \(String(format: "%.2f", medianPause))s")
        }
    }

    // MARK: - Metric Calculations

    /// Calculate velocity: forward actions per minute
    private func calculateVelocity(events: [ScrollEvent]) -> Double {
        guard !events.isEmpty else { return 0 }

        let forwardEvents = events.filter { isForwardEvent($0.type) }

        // Calculate duration of the window
        guard let firstTime = events.first?.timestamp,
              let lastTime = events.last?.timestamp else { return 0 }

        let duration = lastTime.timeIntervalSince(firstTime)
        guard duration > 0 else { return 0 }

        let durationInMinutes = duration / 60.0
        return Double(forwardEvents.count) / durationInMinutes
    }

    /// Calculate directionality: ratio of forward to total actions
    private func calculateDirectionality(events: [ScrollEvent]) -> Double {
        guard !events.isEmpty else { return 0 }

        let forwardCount = events.filter { isForwardEvent($0.type) }.count
        let backwardCount = events.filter { isBackwardEvent($0.type) }.count
        let total = forwardCount + backwardCount

        guard total > 0 else { return 0 }

        return Double(forwardCount) / Double(total)
    }

    /// Calculate median pause duration between events
    private func calculateMedianPause(events: [ScrollEvent]) -> Double {
        guard events.count > 1 else { return Double.infinity }

        var gaps: [TimeInterval] = []

        for i in 0..<(events.count - 1) {
            let gap = events[i + 1].timestamp.timeIntervalSince(events[i].timestamp)
            gaps.append(gap)
        }

        guard !gaps.isEmpty else { return Double.infinity }

        // Calculate median
        let sorted = gaps.sorted()
        let count = sorted.count

        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        } else {
            return sorted[count / 2]
        }
    }

    // MARK: - Helper Functions

    private func isForwardEvent(_ type: ScrollEventType) -> Bool {
        return type == .scrollDown || type == .keyDown || type == .keyRight
    }

    private func isBackwardEvent(_ type: ScrollEventType) -> Bool {
        return type == .scrollUp || type == .keyUp || type == .keyLeft
    }
}
