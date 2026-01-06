//
//  ActivationScheduler.swift
//  Pause
//
//  Created by Harrison Qian on 10/22/25.
//

import Foundation

class ActivationScheduler: ObservableObject {
    static let shared = ActivationScheduler()

    @Published var nextRandomActivation: Date?
    @Published var nextRepeatedActivation: Date?
    @Published var nextScheduledActivation: Date?

    private var repeatedTimer: Timer?
    private var randomTimer: Timer?
    private var scheduledTimers: [Timer] = []

    // Paused state tracking
    private var isPaused = false
    private var pausedRepeatedActivation: Date?
    private var pausedRandomActivation: Date?
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

        if settings.randomEnabled {
            setupRandomTimer()
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

    func updateRandomTimer() {
        clearRandomTimer()
        if Settings.shared.randomEnabled {
            setupRandomTimer()
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
        pausedRandomActivation = nil
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

        // Check random timer
        if let randomDate = nextRandomActivation, randomDate < minimumFireDate {
            print("⌨️ Input detected: Rescheduling random timer from \(Int(randomDate.timeIntervalSinceNow))s to \(Int(bufferSeconds))s")
            clearRandomTimer()
            if Settings.shared.randomEnabled {
                setupRandomTimerWithDelay(bufferSeconds)
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

    private func setupRandomTimer() {
        let minMinutes = Settings.shared.randomMinInterval
        let maxMinutes = Settings.shared.randomMaxInterval

        // Ensure min <= max to avoid crash
        guard minMinutes <= maxMinutes else {
            print("Error: Random min (\(minMinutes)) is greater than max (\(maxMinutes)). Skipping random timer setup.")
            return
        }

        let randomMinutes = Int.random(in: minMinutes...maxMinutes)
        // Special case: 0 minutes means 30 seconds
        let intervalSeconds = randomMinutes == 0 ? TimeInterval(30) : TimeInterval(randomMinutes * 60)

        // Calculate when it will fire
        let fireDate = Date().addingTimeInterval(intervalSeconds)

        // Update published properties
        DispatchQueue.main.async {
            self.nextRandomActivation = fireDate
        }

        print("Setting up random timer: will fire in \(randomMinutes) minutes (range: \(minMinutes)-\(maxMinutes) min)")
        print("Next random activation at: \(fireDate.formatted(date: .omitted, time: .shortened))")

        randomTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: false) { [weak self] _ in
            print("Random timer fired")

            // Skip if a session is already active
            if AppState.shared.isPauseMode {
                print("Skipping activation - session already active")
            } else if Settings.shared.isInNoGoTime() {
                print("Skipping activation - in no-go time")
            } else {
                print("Triggering pause mode (random)")
                AppState.shared.triggerPauseMode(displayText: Settings.shared.randomMessage, isLocked: Settings.shared.randomIsLocked, customDuration: Settings.shared.randomCustomDuration)
            }

            // Schedule the next random timer
            self?.setupRandomTimer()
        }
    }

    private func setupRandomTimerWithDelay(_ delaySeconds: TimeInterval) {
        let fireDate = Date().addingTimeInterval(delaySeconds)

        DispatchQueue.main.async {
            self.nextRandomActivation = fireDate
        }

        randomTimer = Timer.scheduledTimer(withTimeInterval: delaySeconds, repeats: false) { [weak self] _ in
            print("Random timer fired (after delay)")

            // Skip if a session is already active
            if AppState.shared.isPauseMode {
                print("Skipping activation - session already active")
            } else if Settings.shared.isInNoGoTime() {
                print("Skipping activation - in no-go time")
            } else {
                print("Triggering pause mode (random)")
                AppState.shared.triggerPauseMode(displayText: Settings.shared.randomMessage, isLocked: Settings.shared.randomIsLocked, customDuration: Settings.shared.randomCustomDuration)
            }

            // Schedule next random timer normally
            self?.setupRandomTimer()
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
        let calendar = Calendar.current
        let now = Date()

        let scheduledDate: Date

        if scheduledTime.isRecurring {
            // Daily recurring timer - schedule for today or tomorrow
            let components = calendar.dateComponents([.hour, .minute], from: scheduledTime.date)

            guard let hour = components.hour, let minute = components.minute else {
                return nil
            }

            var todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
            todayComponents.hour = hour
            todayComponents.minute = minute
            todayComponents.second = 0

            guard var date = calendar.date(from: todayComponents) else {
                return nil
            }

            // If the time has already passed today, schedule for tomorrow
            if date < now {
                date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            }

            scheduledDate = date
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

        print("Scheduling \(scheduledTime.isRecurring ? "recurring" : "one-time") timer for '\(scheduledTime.name)' - fires in \(Int(timeInterval/60)) minutes")

        let timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            print("Scheduled timer fired")

            // Skip if a session is already active
            if AppState.shared.isPauseMode {
                print("Skipping activation - session already active")
            } else if Settings.shared.isInNoGoTime() {
                print("Skipping activation - in no-go time")
            } else {
                print("Triggering pause mode with text: \(scheduledTime.name), locked: \(String(describing: scheduledTime.isLocked)), duration: \(String(describing: scheduledTime.customDuration))")
                AppState.shared.triggerPauseMode(displayText: scheduledTime.name, isLocked: scheduledTime.isLocked, customDuration: scheduledTime.customDuration)
            }

            if scheduledTime.isRecurring {
                // Reschedule for tomorrow and update next scheduled activation
                if let (newTimer, newFireDate) = self?.createDailyTimer(for: scheduledTime) {
                    self?.scheduledTimers.append(newTimer)
                    self?.updateNextScheduledActivation()
                }
            } else {
                // One-time timer - remove from scheduled times after firing
                Settings.shared.scheduledTimes.removeAll { $0.id == scheduledTime.id }
                self?.updateNextScheduledActivation()
            }
        }

        return (timer, scheduledDate)
    }

    private func updateNextScheduledActivation() {
        // This would be called after a scheduled timer fires to update the next earliest time
        // For now, we can just recalculate by looking at all scheduled times again
        let scheduledTimes = Settings.shared.scheduledTimes
        let calendar = Calendar.current
        let now = Date()

        var earliestDate: Date?

        for scheduledTime in scheduledTimes {
            let components = calendar.dateComponents([.hour, .minute], from: scheduledTime.date)
            guard let hour = components.hour, let minute = components.minute else { continue }

            var todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
            todayComponents.hour = hour
            todayComponents.minute = minute
            todayComponents.second = 0

            guard var scheduledDate = calendar.date(from: todayComponents) else { continue }

            if scheduledDate < now {
                scheduledDate = calendar.date(byAdding: .day, value: 1, to: scheduledDate) ?? scheduledDate
            }

            if let earliest = earliestDate {
                if scheduledDate < earliest {
                    earliestDate = scheduledDate
                }
            } else {
                earliestDate = scheduledDate
            }
        }

        DispatchQueue.main.async {
            self.nextScheduledActivation = earliestDate
        }
    }

    private func clearAllTimers() {
        clearRepeatedTimer()
        clearRandomTimer()
        clearScheduledTimers()
    }

    private func clearRepeatedTimer() {
        repeatedTimer?.invalidate()
        repeatedTimer = nil
        nextRepeatedActivation = nil
    }

    private func clearRandomTimer() {
        randomTimer?.invalidate()
        randomTimer = nil
        nextRandomActivation = nil
    }

    private func clearScheduledTimers() {
        scheduledTimers.forEach { $0.invalidate() }
        scheduledTimers.removeAll()
        nextScheduledActivation = nil
    }

    // MARK: - Helper Methods

    /// Returns the next activation time and its type (Repeated, Random, or Scheduled)
    func getNextActivation() -> (date: Date, type: String)? {
        var soonest: (date: Date, type: String)?

        // Check repeated timer
        if let repeatedDate = nextRepeatedActivation {
            soonest = (repeatedDate, "Repeated")
        }

        // Check random timer
        if let randomDate = nextRandomActivation {
            if let current = soonest {
                if randomDate < current.date {
                    soonest = (randomDate, "Random")
                }
            } else {
                soonest = (randomDate, "Random")
            }
        }

        // Check scheduled timer
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
        pausedRandomActivation = nextRandomActivation
        pausedScheduledActivation = nextScheduledActivation

        // Invalidate all timers (but don't clear the next activation dates yet)
        repeatedTimer?.invalidate()
        repeatedTimer = nil

        randomTimer?.invalidate()
        randomTimer = nil

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

        // Resume random timer if it was active
        if let pausedDate = pausedRandomActivation, Settings.shared.randomEnabled {
            let remainingTime = pausedDate.timeIntervalSince(now)

            if remainingTime > 0 {
                print("▶️ Resuming random timer with \(Int(remainingTime))s remaining")
                setupRandomTimerWithDelay(remainingTime)
            } else {
                // Timer should have fired during session - reschedule normally
                print("▶️ Random timer expired during session - rescheduling")
                setupRandomTimer()
            }
        }

        // Resume scheduled timers if they were active
        if pausedScheduledActivation != nil, Settings.shared.scheduledEnabled {
            print("▶️ Resuming scheduled timers")
            setupScheduledTimers()
        }

        // Clear paused state
        pausedRepeatedActivation = nil
        pausedRandomActivation = nil
        pausedScheduledActivation = nil

        print("▶️ All timers resumed")
    }

    deinit {
        clearAllTimers()
    }
}
