//
//  ActivationScheduler.swift
//  Pause
//
//  Created by Harrison Qian on 10/22/25.
//

import Foundation

class ActivationScheduler: ObservableObject {
    static let shared = ActivationScheduler()

    @Published var nextRepeatedActivation: Date?
    @Published var nextScheduledActivation: Date?

    private var repeatedTimer: Timer?
    private var scheduledTimers: [Timer] = []

    // Paused state tracking
    private var isPaused = false
    private var pausedRepeatedActivation: Date?
    private var pausedScheduledActivation: Date?

    private init() {
        // Initial setup
        updateSchedule()
    }

    func updateSchedule() {
        // Clear existing timers
        clearAllTimers()

        let settings = Settings.shared

        // Each mode can be enabled independently
        if settings.repeatedEnabled {
            setupRepeatedTimer()
        }

        if settings.scheduledEnabled {
            setupScheduledTimers()
        }
    }

    func updateRepeatedTimer() {
        clearRepeatedTimer()
        if Settings.shared.repeatedEnabled {
            setupRepeatedTimer()
        }
    }

    func updateScheduledTimers() {
        clearScheduledTimers()
        if Settings.shared.scheduledEnabled {
            setupScheduledTimers()
        }
    }

    // Public method to recalculate timers when an activation occurs
    func recalculateTimers() {
        print("Recalculating all timers due to activation")

        // Reset paused state when recalculating
        isPaused = false
        pausedRepeatedActivation = nil
        pausedScheduledActivation = nil

        updateSchedule()
    }

    // Public method to enforce minimum buffer on input detection
    func enforceMinimumBuffer() {
        guard Settings.shared.detectionEnabled else { return }

        let bufferSeconds = TimeInterval(Settings.shared.inputDelayBuffer)
        let now = Date()
        let minimumFireDate = now.addingTimeInterval(bufferSeconds)

        var didReschedule = false

        // Check repeated timer
        if let repeatedDate = nextRepeatedActivation, repeatedDate < minimumFireDate {
            print("⌨️ Input detected: Rescheduling repeated timer from \(Int(repeatedDate.timeIntervalSinceNow))s to \(Int(bufferSeconds))s")
            clearRepeatedTimer()
            if Settings.shared.repeatedEnabled {
                setupRepeatedTimerWithDelay(bufferSeconds)
            }
            didReschedule = true
        }

        // Check scheduled timer
        if let scheduledDate = nextScheduledActivation, scheduledDate < minimumFireDate {
            print("⌨️ Input detected: Rescheduling scheduled timer from \(Int(scheduledDate.timeIntervalSinceNow))s to \(Int(bufferSeconds))s")
            clearScheduledTimers()
            if Settings.shared.scheduledEnabled {
                setupScheduledTimersWithDelay(bufferSeconds)
            }
            didReschedule = true
        }

        if !didReschedule && Settings.shared.detectionEnabled {
            // No timers were close enough to reschedule - this is expected for distant timers
        }
    }

    private func setupRepeatedTimer() {
        let intervalMinutes = Settings.shared.repeatedInterval
        // Special case: 0 minutes means 30 seconds
        let intervalSeconds = intervalMinutes == 0 ? TimeInterval(30) : TimeInterval(intervalMinutes * 60)

        print("Setting up repeated timer: every \(intervalMinutes == 0 ? "30 seconds" : "\(intervalMinutes) minutes")")

        // Calculate when it will fire
        let fireDate = Date().addingTimeInterval(intervalSeconds)

        DispatchQueue.main.async {
            self.nextRepeatedActivation = fireDate
        }

        repeatedTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            print("Repeated timer fired")

            // Skip if a session is already active
            if AppState.shared.isPauseMode {
                print("Skipping activation - session already active")
            } else if Settings.shared.isInNoGoTime() {
                print("Skipping activation - in no-go time")
            } else {
                print("Triggering pause mode (repeated)")
                AppState.shared.triggerPauseMode(displayText: Settings.shared.repeatedMessage, isLocked: Settings.shared.repeatedIsLocked, customDuration: Settings.shared.repeatedCustomDuration)
            }

            // Update the next fire date for the next interval
            let nextFire = Date().addingTimeInterval(intervalSeconds)
            DispatchQueue.main.async {
                self?.nextRepeatedActivation = nextFire
            }
        }
    }

    private func setupRepeatedTimerWithDelay(_ delaySeconds: TimeInterval) {
        let intervalMinutes = Settings.shared.repeatedInterval
        let intervalSeconds = intervalMinutes == 0 ? TimeInterval(30) : TimeInterval(intervalMinutes * 60)

        let fireDate = Date().addingTimeInterval(delaySeconds)

        DispatchQueue.main.async {
            self.nextRepeatedActivation = fireDate
        }

        repeatedTimer = Timer.scheduledTimer(withTimeInterval: delaySeconds, repeats: true) { [weak self] _ in
            print("Repeated timer fired")

            // Skip if a session is already active
            if AppState.shared.isPauseMode {
                print("Skipping activation - session already active")
            } else if Settings.shared.isInNoGoTime() {
                print("Skipping activation - in no-go time")
            } else {
                print("Triggering pause mode (repeated)")
                AppState.shared.triggerPauseMode(displayText: Settings.shared.repeatedMessage, isLocked: Settings.shared.repeatedIsLocked, customDuration: Settings.shared.repeatedCustomDuration)
            }

            // After first fire, use normal interval
            let nextFire = Date().addingTimeInterval(intervalSeconds)
            DispatchQueue.main.async {
                self?.nextRepeatedActivation = nextFire
            }
        }
    }

    private func setupScheduledTimers() {
        let scheduledTimes = Settings.shared.scheduledTimes

        print("Setting up scheduled timers for \(scheduledTimes.count) times")

        var earliestDate: Date?

        for scheduledTime in scheduledTimes {
            if let (timer, fireDate) = createDailyTimer(for: scheduledTime) {
                scheduledTimers.append(timer)

                // Track the earliest scheduled activation
                if let earliest = earliestDate {
                    if fireDate < earliest {
                        earliestDate = fireDate
                    }
                } else {
                    earliestDate = fireDate
                }
            }
        }

        DispatchQueue.main.async {
            self.nextScheduledActivation = earliestDate
        }
    }

    private func setupScheduledTimersWithDelay(_ delaySeconds: TimeInterval) {
        // For scheduled timers, we just delay them all by creating a single timer
        // that will re-setup all scheduled timers after the delay
        let fireDate = Date().addingTimeInterval(delaySeconds)

        DispatchQueue.main.async {
            self.nextScheduledActivation = fireDate
        }

        let delayTimer = Timer.scheduledTimer(withTimeInterval: delaySeconds, repeats: false) { [weak self] _ in
            print("Scheduled timer delay expired - setting up scheduled timers normally")
            self?.setupScheduledTimers()
        }

        scheduledTimers.append(delayTimer)
    }

    private func createDailyTimer(for scheduledTime: ScheduledTime) -> (Timer, Date)? {
        // Skip disabled scheduled times
        guard scheduledTime.isEnabled else {
            print("Skipping disabled timer for '\(scheduledTime.name)'")
            return nil
        }

        let calendar = Calendar.current
        let now = Date()

        let scheduledDate: Date

        if scheduledTime.isRecurring {
            // Get the target time
            let components = calendar.dateComponents([.hour, .minute], from: scheduledTime.date)
            guard let hour = components.hour, let minute = components.minute else {
                return nil
            }

            // Find next valid date based on repeatDays
            guard let nextDate = findNextValidDate(hour: hour, minute: minute, repeatDays: scheduledTime.repeatDays, from: now) else {
                print("No valid day found for '\(scheduledTime.name)' - repeatDays: \(scheduledTime.repeatDays)")
                return nil
            }
            scheduledDate = nextDate
        } else {
            // One-time timer (e.g., snooze) - use absolute date
            scheduledDate = scheduledTime.date

            // Skip if the scheduled time is in the past
            if scheduledDate < now {
                print("Skipping one-time timer for '\(scheduledTime.name)' - time has passed")
                return nil
            }
        }

        let timeInterval = scheduledDate.timeIntervalSinceNow
        let repeatInfo = scheduledTime.repeatDays.isEmpty ? "one-shot" : "repeats \(scheduledTime.repeatDays.sorted())"
        print("Scheduling timer for '\(scheduledTime.name)' (\(repeatInfo)) - fires in \(Int(timeInterval/60)) minutes")

        let timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            print("Scheduled timer fired for '\(scheduledTime.name)'")

            // Skip if a session is already active
            if AppState.shared.isPauseMode {
                print("Skipping activation - session already active")
            } else if Settings.shared.isInNoGoTime() {
                print("Skipping activation - in no-go time")
            } else {
                AppState.shared.triggerPauseMode(displayText: scheduledTime.name, isLocked: scheduledTime.isLocked, customDuration: scheduledTime.customDuration)
            }

            if scheduledTime.isRecurring {
                if scheduledTime.repeatDays.isEmpty {
                    // One-shot: disable after firing (keep in list but turn off)
                    if let index = Settings.shared.scheduledTimes.firstIndex(where: { $0.id == scheduledTime.id }) {
                        Settings.shared.scheduledTimes[index].isEnabled = false
                    }
                } else {
                    // Has repeat days: reschedule for next valid day
                    if let (newTimer, _) = self?.createDailyTimer(for: scheduledTime) {
                        self?.scheduledTimers.append(newTimer)
                    }
                }
                self?.updateNextScheduledActivation()
            } else {
                // Snooze (absolute one-time) - remove from list
                Settings.shared.scheduledTimes.removeAll { $0.id == scheduledTime.id }
                self?.updateNextScheduledActivation()
            }
        }

        return (timer, scheduledDate)
    }

    // Find next date that matches repeatDays (1=Sunday...7=Saturday)
    private func findNextValidDate(hour: Int, minute: Int, repeatDays: Set<Int>, from now: Date) -> Date? {
        let calendar = Calendar.current

        // If repeatDays is empty, treat as "today or tomorrow" (one-shot)
        let daysToCheck = repeatDays.isEmpty ? Set(1...7) : repeatDays

        // Check up to 7 days ahead
        for dayOffset in 0..<7 {
            guard let checkDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }

            // Get weekday (1=Sunday...7=Saturday)
            let weekday = calendar.component(.weekday, from: checkDate)

            if daysToCheck.contains(weekday) {
                // Build the date with target hour/minute
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: checkDate)
                dateComponents.hour = hour
                dateComponents.minute = minute
                dateComponents.second = 0

                guard let candidateDate = calendar.date(from: dateComponents) else { continue }

                // If same day but time has passed, skip
                if candidateDate > now {
                    return candidateDate
                }
            }
        }

        return nil
    }

    private func updateNextScheduledActivation() {
        let scheduledTimes = Settings.shared.scheduledTimes
        let calendar = Calendar.current
        let now = Date()

        var earliestDate: Date?

        for scheduledTime in scheduledTimes {
            // Skip disabled times
            guard scheduledTime.isEnabled else { continue }

            if scheduledTime.isRecurring {
                let components = calendar.dateComponents([.hour, .minute], from: scheduledTime.date)
                guard let hour = components.hour, let minute = components.minute else { continue }

                if let nextDate = findNextValidDate(hour: hour, minute: minute, repeatDays: scheduledTime.repeatDays, from: now) {
                    if earliestDate == nil || nextDate < earliestDate! {
                        earliestDate = nextDate
                    }
                }
            } else {
                // One-time (snooze) - use absolute date
                if scheduledTime.date > now {
                    if earliestDate == nil || scheduledTime.date < earliestDate! {
                        earliestDate = scheduledTime.date
                    }
                }
            }
        }

        DispatchQueue.main.async {
            self.nextScheduledActivation = earliestDate
        }
    }

    private func clearAllTimers() {
        clearRepeatedTimer()
        clearScheduledTimers()
    }

    private func clearRepeatedTimer() {
        repeatedTimer?.invalidate()
        repeatedTimer = nil
        nextRepeatedActivation = nil
    }

    private func clearScheduledTimers() {
        scheduledTimers.forEach { $0.invalidate() }
        scheduledTimers.removeAll()
        nextScheduledActivation = nil
    }

    // MARK: - Helper Methods

    /// Returns the next activation time and its type
    func getNextActivation() -> (date: Date, type: String)? {
        var soonest: (date: Date, type: String)?

        if let repeatedDate = nextRepeatedActivation {
            soonest = (repeatedDate, "Repeated")
        }

        if let scheduledDate = nextScheduledActivation {
            if let current = soonest {
                if scheduledDate < current.date {
                    soonest = (scheduledDate, "Scheduled")
                }
            } else {
                soonest = (scheduledDate, "Scheduled")
            }
        }

        return soonest
    }

    // MARK: - Pause/Resume Timer Management

    /// Pause all activation timers during a session
    func pauseTimers() {
        guard !isPaused else { return }

        print("⏸️ Pausing all activation timers during session")

        isPaused = true

        // Save current activation dates
        pausedRepeatedActivation = nextRepeatedActivation
        pausedScheduledActivation = nextScheduledActivation

        // Invalidate all timers (but don't clear the next activation dates yet)
        repeatedTimer?.invalidate()
        repeatedTimer = nil

        scheduledTimers.forEach { $0.invalidate() }
        scheduledTimers.removeAll()

        print("⏸️ Timers paused - will resume after session")
    }

    /// Resume all activation timers after a session
    func resumeTimers() {
        guard isPaused else { return }

        print("▶️ Resuming activation timers after session")

        isPaused = false
        let now = Date()

        // Resume repeated timer if it was active
        if let pausedDate = pausedRepeatedActivation, Settings.shared.repeatedEnabled {
            let remainingTime = pausedDate.timeIntervalSince(now)

            if remainingTime > 0 {
                print("▶️ Resuming repeated timer with \(Int(remainingTime))s remaining")
                setupRepeatedTimerWithDelay(remainingTime)
            } else {
                // Timer should have fired during session - reschedule normally
                print("▶️ Repeated timer expired during session - rescheduling")
                setupRepeatedTimer()
            }
        }

        // Resume scheduled timers if they were active
        if pausedScheduledActivation != nil, Settings.shared.scheduledEnabled {
            print("▶️ Resuming scheduled timers")
            setupScheduledTimers()
        }

        // Clear paused state
        pausedRepeatedActivation = nil
        pausedScheduledActivation = nil

        print("▶️ All timers resumed")
    }

    deinit {
        clearAllTimers()
    }
}
