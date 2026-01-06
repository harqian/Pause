//
//  Settings.swift
//  Pause
//
//  Created by Harrison Qian on 10/22/25.
//

import Foundation
import Carbon.HIToolbox
import ServiceManagement

// Model for monitored apps that trigger activation
struct MonitoredApp: Codable, Identifiable, Equatable {
    let id: UUID
    let bundleIdentifier: String
    let name: String
    let iconPath: String?
    var activationDelay: TimeInterval  // Seconds to wait after app launch before triggering
    var customMessage: String?  // Custom message to display, or nil for default
    var isLocked: Bool?  // nil = use global setting
    var customDuration: Int?  // nil = use global duration

    init(bundleIdentifier: String, name: String, iconPath: String? = nil, activationDelay: TimeInterval = 5.0, customMessage: String? = nil, isLocked: Bool? = nil, customDuration: Int? = nil) {
        self.id = UUID()
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.iconPath = iconPath
        self.activationDelay = activationDelay
        self.customMessage = customMessage
        self.isLocked = isLocked
        self.customDuration = customDuration
    }
}

struct ScheduledTime: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var name: String
    var isRecurring: Bool  // false for one-time snooze activations (absolute time)
    var isLocked: Bool?  // nil = use global setting, true/false = override
    var customDuration: Int?  // nil = use global duration, otherwise override in seconds
    var repeatDays: Set<Int>  // 1=Sunday...7=Saturday. Empty = one-shot (disables after firing)
    var isEnabled: Bool  // Whether this scheduled time is active

    init(id: UUID = UUID(), date: Date, name: String = "", isRecurring: Bool = true, isLocked: Bool? = nil, customDuration: Int? = nil, repeatDays: Set<Int> = [], isEnabled: Bool = true) {
        self.id = id
        self.date = date
        self.name = name.isEmpty ? "Just Breathe" : name
        self.isRecurring = isRecurring
        self.isLocked = isLocked
        self.customDuration = customDuration
        // Default: one-shot (empty). User must select days for repeating.
        self.repeatDays = repeatDays
        self.isEnabled = isEnabled
    }

    // Custom decoding for backwards compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        name = try container.decode(String.self, forKey: .name)
        isRecurring = try container.decode(Bool.self, forKey: .isRecurring)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked)
        customDuration = try container.decodeIfPresent(Int.self, forKey: .customDuration)
        // Migration: old data won't have repeatDays, default to all days if recurring
        repeatDays = try container.decodeIfPresent(Set<Int>.self, forKey: .repeatDays) ?? (isRecurring ? Set(1...7) : [])
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}

struct NoGoTime: Codable, Identifiable, Equatable {
    var id: UUID
    var startTime: Date
    var endTime: Date
    var name: String
    var repeatDays: Set<Int>  // 1=Sunday...7=Saturday. Empty = one-shot
    var isEnabled: Bool

    init(id: UUID = UUID(), startTime: Date, endTime: Date, name: String = "", repeatDays: Set<Int> = [], isEnabled: Bool = true) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.name = name.isEmpty ? "No-Go Period" : name
        self.repeatDays = repeatDays
        self.isEnabled = isEnabled
    }

    // Custom decoding for backwards compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        name = try container.decode(String.self, forKey: .name)

        // Migration: convert old isRecurring + dayOfWeek to repeatDays
        if let repeatDays = try container.decodeIfPresent(Set<Int>.self, forKey: .repeatDays) {
            self.repeatDays = repeatDays
        } else {
            let isRecurring = try container.decodeIfPresent(Bool.self, forKey: .isRecurring) ?? true
            let dayOfWeek = try container.decodeIfPresent(Int.self, forKey: .dayOfWeek)
            if isRecurring {
                self.repeatDays = Set(1...7)  // Daily = all days
            } else if let day = dayOfWeek {
                self.repeatDays = [day]  // Single day
            } else {
                self.repeatDays = []
            }
        }
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(name, forKey: .name)
        try container.encode(repeatDays, forKey: .repeatDays)
        try container.encode(isEnabled, forKey: .isEnabled)
    }

    private enum CodingKeys: String, CodingKey {
        case id, startTime, endTime, name, repeatDays, isEnabled
        case isRecurring, dayOfWeek  // For migration (decode only)
    }
}

extension DateFormatter {
    static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

class Settings: ObservableObject {
    static let shared = Settings()

    // Undo/Redo stacks for scheduled times
    private var undoStack: [[ScheduledTime]] = []
    private var redoStack: [[ScheduledTime]] = []
    private let maxUndoStackSize = 50

    @Published var detectionEnabled: Bool {
        didSet {
            UserDefaults.standard.set(detectionEnabled, forKey: "detectionEnabled")
        }
    }

    // Minimum buffer in seconds: if next activation < this, reset it to this
    @Published var inputDelayBuffer: Int {
        didSet {
            UserDefaults.standard.set(inputDelayBuffer, forKey: "inputDelayBuffer")
        }
    }

    // Doom scroll detection settings
    @Published var doomScrollEnabled: Bool {
        didSet {
            UserDefaults.standard.set(doomScrollEnabled, forKey: "doomScrollEnabled")
        }
    }

    @Published var doomScrollVelocityThreshold: Int {
        didSet {
            UserDefaults.standard.set(doomScrollVelocityThreshold, forKey: "doomScrollVelocityThreshold")
        }
    }

    @Published var doomScrollDirectionalityThreshold: Double {
        didSet {
            UserDefaults.standard.set(doomScrollDirectionalityThreshold, forKey: "doomScrollDirectionalityThreshold")
        }
    }

    @Published var doomScrollPauseThreshold: Double {
        didSet {
            UserDefaults.standard.set(doomScrollPauseThreshold, forKey: "doomScrollPauseThreshold")
        }
    }

    @Published var doomScrollWindowDuration: Int {
        didSet {
            UserDefaults.standard.set(doomScrollWindowDuration, forKey: "doomScrollWindowDuration")
        }
    }

    @Published var doomScrollMessage: String? {
        didSet {
            if let value = doomScrollMessage {
                UserDefaults.standard.set(value, forKey: "doomScrollMessage")
            } else {
                UserDefaults.standard.removeObject(forKey: "doomScrollMessage")
            }
        }
    }

    @Published var doomScrollIsLocked: Bool? {
        didSet {
            if let value = doomScrollIsLocked {
                UserDefaults.standard.set(value, forKey: "doomScrollIsLocked")
            } else {
                UserDefaults.standard.removeObject(forKey: "doomScrollIsLocked")
            }
        }
    }

    @Published var doomScrollCustomDuration: Int? {
        didSet {
            if let value = doomScrollCustomDuration {
                UserDefaults.standard.set(value, forKey: "doomScrollCustomDuration")
            } else {
                UserDefaults.standard.removeObject(forKey: "doomScrollCustomDuration")
            }
        }
    }

    @Published var pauseDuration: Int {
        didSet {
            UserDefaults.standard.set(pauseDuration, forKey: "pauseDuration")
        }
    }

    @Published var pauseVariance: Int {
        didSet {
            UserDefaults.standard.set(pauseVariance, forKey: "pauseVariance")
        }
    }

    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
        }
    }

    @Published var soundVolume: Double {
        didSet {
            UserDefaults.standard.set(soundVolume, forKey: "soundVolume")
        }
    }

    @Published var soundRepeatRate: Int {
        didSet {
            UserDefaults.standard.set(soundRepeatRate, forKey: "soundRepeatRate")
        }
    }

    @Published var selectedAmbientSound: String {
        didSet {
            UserDefaults.standard.set(selectedAmbientSound, forKey: "selectedAmbientSound")
        }
    }

    @Published var startSoundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(startSoundEnabled, forKey: "startSoundEnabled")
        }
    }

    @Published var startSoundVolume: Double {
        didSet {
            UserDefaults.standard.set(startSoundVolume, forKey: "startSoundVolume")
        }
    }

    @Published var endSoundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(endSoundEnabled, forKey: "endSoundEnabled")
        }
    }

    @Published var endSoundVolume: Double {
        didSet {
            UserDefaults.standard.set(endSoundVolume, forKey: "endSoundVolume")
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLaunchAtLogin()
        }
    }

    @Published var showInMenuBar: Bool {
        didSet {
            UserDefaults.standard.set(showInMenuBar, forKey: "showInMenuBar")
            MenuBarManager.shared.updateMenuBarVisibility()
        }
    }

    @Published var menuBarShowTimer: Bool {
        didSet {
            UserDefaults.standard.set(menuBarShowTimer, forKey: "menuBarShowTimer")
            MenuBarManager.shared.updateCountdown()
        }
    }

    @Published var sessionDisplayText: String {
        didSet {
            UserDefaults.standard.set(sessionDisplayText, forKey: "sessionDisplayText")
        }
    }

    @Published var lockSessionEnabled: Bool {
        didSet {
            UserDefaults.standard.set(lockSessionEnabled, forKey: "lockSessionEnabled")
        }
    }

    @Published var completedSessions: Int {
        didSet {
            UserDefaults.standard.set(completedSessions, forKey: "completedSessions")
        }
    }

    @Published var completedSessionTime: Int {
        didSet {
            UserDefaults.standard.set(completedSessionTime, forKey: "completedSessionTime")
        }
    }

    // Activation settings - each mode can be toggled independently
    @Published var repeatedEnabled: Bool {
        didSet {
            UserDefaults.standard.set(repeatedEnabled, forKey: "repeatedEnabled")
            ActivationScheduler.shared.updateRepeatedTimer()
        }
    }

    @Published var repeatedInterval: Int {
        didSet {
            UserDefaults.standard.set(repeatedInterval, forKey: "repeatedInterval")
            ActivationScheduler.shared.updateRepeatedTimer()
        }
    }

    @Published var repeatedIsLocked: Bool? {
        didSet {
            if let value = repeatedIsLocked {
                UserDefaults.standard.set(value, forKey: "repeatedIsLocked")
            } else {
                UserDefaults.standard.removeObject(forKey: "repeatedIsLocked")
            }
        }
    }

    @Published var repeatedCustomDuration: Int? {
        didSet {
            if let value = repeatedCustomDuration {
                UserDefaults.standard.set(value, forKey: "repeatedCustomDuration")
            } else {
                UserDefaults.standard.removeObject(forKey: "repeatedCustomDuration")
            }
        }
    }

    @Published var repeatedMessage: String? {
        didSet {
            if let value = repeatedMessage {
                UserDefaults.standard.set(value, forKey: "repeatedMessage")
            } else {
                UserDefaults.standard.removeObject(forKey: "repeatedMessage")
            }
        }
    }

    @Published var randomEnabled: Bool {
        didSet {
            UserDefaults.standard.set(randomEnabled, forKey: "randomEnabled")
            ActivationScheduler.shared.updateRandomTimer()
        }
    }

    @Published var randomMinInterval: Int {
        didSet {
            UserDefaults.standard.set(randomMinInterval, forKey: "randomMinInterval")
            ActivationScheduler.shared.updateRandomTimer()
        }
    }

    @Published var randomMaxInterval: Int {
        didSet {
            UserDefaults.standard.set(randomMaxInterval, forKey: "randomMaxInterval")
            ActivationScheduler.shared.updateRandomTimer()
        }
    }

    @Published var randomIsLocked: Bool? {
        didSet {
            if let value = randomIsLocked {
                UserDefaults.standard.set(value, forKey: "randomIsLocked")
            } else {
                UserDefaults.standard.removeObject(forKey: "randomIsLocked")
            }
        }
    }

    @Published var randomCustomDuration: Int? {
        didSet {
            if let value = randomCustomDuration {
                UserDefaults.standard.set(value, forKey: "randomCustomDuration")
            } else {
                UserDefaults.standard.removeObject(forKey: "randomCustomDuration")
            }
        }
    }

    @Published var randomMessage: String? {
        didSet {
            if let value = randomMessage {
                UserDefaults.standard.set(value, forKey: "randomMessage")
            } else {
                UserDefaults.standard.removeObject(forKey: "randomMessage")
            }
        }
    }

    @Published var scheduledEnabled: Bool {
        didSet {
            UserDefaults.standard.set(scheduledEnabled, forKey: "scheduledEnabled")
            ActivationScheduler.shared.updateScheduledTimers()
        }
    }

    @Published var scheduledTimes: [ScheduledTime] {
        didSet {
            if let encoded = try? JSONEncoder().encode(scheduledTimes) {
                UserDefaults.standard.set(encoded, forKey: "scheduledTimes")
            }
            ActivationScheduler.shared.updateScheduledTimers()
        }
    }

    @Published var appLaunchEnabled: Bool {
        didSet {
            UserDefaults.standard.set(appLaunchEnabled, forKey: "appLaunchEnabled")
        }
    }

    @Published var monitoredApps: [MonitoredApp] {
        didSet {
            if let encoded = try? JSONEncoder().encode(monitoredApps) {
                UserDefaults.standard.set(encoded, forKey: "monitoredApps")
            }
        }
    }

    // Methods for undo/redo
    func saveUndoState() {
        undoStack.append(scheduledTimes)
        if undoStack.count > maxUndoStackSize {
            undoStack.removeFirst()
        }
        redoStack.removeAll() // Clear redo stack when new action is performed
    }

    func undo() {
        guard !undoStack.isEmpty else { return }
        redoStack.append(scheduledTimes)
        scheduledTimes = undoStack.removeLast()
    }

    func redo() {
        guard !redoStack.isEmpty else { return }
        undoStack.append(scheduledTimes)
        scheduledTimes = redoStack.removeLast()
    }

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }

    func deleteScheduledTime(at offsets: IndexSet) {
        saveUndoState()
        scheduledTimes.remove(atOffsets: offsets)
    }

    func deleteScheduledTime(id: UUID) {
        saveUndoState()
        scheduledTimes.removeAll { $0.id == id }
    }

    func clearAllScheduledTimes() {
        saveUndoState()
        scheduledTimes.removeAll()
    }

    @Published var recalculateOnActivation: Bool {
        didSet {
            UserDefaults.standard.set(recalculateOnActivation, forKey: "recalculateOnActivation")
        }
    }

    // No-Go times (times when activations should not trigger)
    @Published var noGoEnabled: Bool {
        didSet {
            UserDefaults.standard.set(noGoEnabled, forKey: "noGoEnabled")
        }
    }

    @Published var noGoTimes: [NoGoTime] {
        didSet {
            if let encoded = try? JSONEncoder().encode(noGoTimes) {
                UserDefaults.standard.set(encoded, forKey: "noGoTimes")
            }
        }
    }

    // Activate session hotkey settings (global)
    @Published var activateHotkeyModifiers: UInt32 {
        didSet {
            UserDefaults.standard.set(activateHotkeyModifiers, forKey: "activateHotkeyModifiers")
        }
    }

    @Published var activateHotkeyKeyCode: UInt32 {
        didSet {
            UserDefaults.standard.set(activateHotkeyKeyCode, forKey: "activateHotkeyKeyCode")
        }
    }

    // Exit hotkey settings
    @Published var exitHotkeyModifiers: UInt32 {
        didSet {
            UserDefaults.standard.set(exitHotkeyModifiers, forKey: "exitHotkeyModifiers")
        }
    }

    @Published var exitHotkeyKeyCode: UInt32 {
        didSet {
            UserDefaults.standard.set(exitHotkeyKeyCode, forKey: "exitHotkeyKeyCode")
        }
    }

    // Snooze settings
    @Published var snoozeDuration: Int {
        didSet {
            UserDefaults.standard.set(snoozeDuration, forKey: "snoozeDuration")
        }
    }

    @Published var snoozeHotkeyModifiers: UInt32 {
        didSet {
            UserDefaults.standard.set(snoozeHotkeyModifiers, forKey: "snoozeHotkeyModifiers")
        }
    }

    @Published var snoozeHotkeyKeyCode: UInt32 {
        didSet {
            UserDefaults.standard.set(snoozeHotkeyKeyCode, forKey: "snoozeHotkeyKeyCode")
        }
    }

    // UI State
    @Published var selectedTab: Int {
        didSet {
            UserDefaults.standard.set(selectedTab, forKey: "selectedTab")
        }
    }

    private init() {
        // Load from UserDefaults with default values
        self.detectionEnabled = UserDefaults.standard.object(forKey: "detectionEnabled") as? Bool ?? true
        self.inputDelayBuffer = UserDefaults.standard.object(forKey: "inputDelayBuffer") as? Int ?? 60

        // Load doom scroll detection settings
        self.doomScrollEnabled = UserDefaults.standard.object(forKey: "doomScrollEnabled") as? Bool ?? false
        self.doomScrollVelocityThreshold = UserDefaults.standard.object(forKey: "doomScrollVelocityThreshold") as? Int ?? 3000 // events per minute (40 * 75)
        self.doomScrollDirectionalityThreshold = UserDefaults.standard.object(forKey: "doomScrollDirectionalityThreshold") as? Double ?? 0.85 // 85% forward
        self.doomScrollPauseThreshold = UserDefaults.standard.object(forKey: "doomScrollPauseThreshold") as? Double ?? 1.5 // 1.5 seconds median gap
        self.doomScrollWindowDuration = UserDefaults.standard.object(forKey: "doomScrollWindowDuration") as? Int ?? 3 // 3 minutes rolling window
        self.doomScrollMessage = UserDefaults.standard.object(forKey: "doomScrollMessage") as? String
        self.doomScrollIsLocked = UserDefaults.standard.object(forKey: "doomScrollIsLocked") as? Bool
        self.doomScrollCustomDuration = UserDefaults.standard.object(forKey: "doomScrollCustomDuration") as? Int

        self.pauseDuration = UserDefaults.standard.object(forKey: "pauseDuration") as? Int ?? 60
        self.pauseVariance = UserDefaults.standard.object(forKey: "pauseVariance") as? Int ?? 0
        self.soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        self.soundVolume = UserDefaults.standard.object(forKey: "soundVolume") as? Double ?? 0.5
        self.soundRepeatRate = UserDefaults.standard.object(forKey: "soundRepeatRate") as? Int ?? 0
        self.selectedAmbientSound = UserDefaults.standard.object(forKey: "selectedAmbientSound") as? String ?? "random"
        self.startSoundEnabled = UserDefaults.standard.object(forKey: "startSoundEnabled") as? Bool ?? true
        self.startSoundVolume = UserDefaults.standard.object(forKey: "startSoundVolume") as? Double ?? 0.5
        self.endSoundEnabled = UserDefaults.standard.object(forKey: "endSoundEnabled") as? Bool ?? true
        self.endSoundVolume = UserDefaults.standard.object(forKey: "endSoundVolume") as? Double ?? 0.5

        // Launch at login - default to true for first launch
        self.launchAtLogin = UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool ?? true

        self.showInMenuBar = UserDefaults.standard.object(forKey: "showInMenuBar") as? Bool ?? true
        self.menuBarShowTimer = UserDefaults.standard.object(forKey: "menuBarShowTimer") as? Bool ?? true
        self.sessionDisplayText = UserDefaults.standard.object(forKey: "sessionDisplayText") as? String ?? "Just Breathe"
        self.lockSessionEnabled = UserDefaults.standard.object(forKey: "lockSessionEnabled") as? Bool ?? false
        self.completedSessions = UserDefaults.standard.object(forKey: "completedSessions") as? Int ?? 0
        self.completedSessionTime = UserDefaults.standard.object(forKey: "completedSessionTime") as? Int ?? 0

        // Load activation settings
        self.repeatedEnabled = UserDefaults.standard.object(forKey: "repeatedEnabled") as? Bool ?? false
        self.repeatedInterval = UserDefaults.standard.object(forKey: "repeatedInterval") as? Int ?? 60 // Default 60 minutes
        self.repeatedIsLocked = UserDefaults.standard.object(forKey: "repeatedIsLocked") as? Bool
        self.repeatedCustomDuration = UserDefaults.standard.object(forKey: "repeatedCustomDuration") as? Int
        self.repeatedMessage = UserDefaults.standard.object(forKey: "repeatedMessage") as? String

        self.randomEnabled = UserDefaults.standard.object(forKey: "randomEnabled") as? Bool ?? false
        self.randomMinInterval = UserDefaults.standard.object(forKey: "randomMinInterval") as? Int ?? 30 // Default 30 minutes
        self.randomMaxInterval = UserDefaults.standard.object(forKey: "randomMaxInterval") as? Int ?? 120 // Default 120 minutes
        self.randomIsLocked = UserDefaults.standard.object(forKey: "randomIsLocked") as? Bool
        self.randomCustomDuration = UserDefaults.standard.object(forKey: "randomCustomDuration") as? Int
        self.randomMessage = UserDefaults.standard.object(forKey: "randomMessage") as? String

        self.scheduledEnabled = UserDefaults.standard.object(forKey: "scheduledEnabled") as? Bool ?? false
        if let data = UserDefaults.standard.data(forKey: "scheduledTimes"),
           let decoded = try? JSONDecoder().decode([ScheduledTime].self, from: data) {
            self.scheduledTimes = decoded
        } else if let data = UserDefaults.standard.data(forKey: "scheduledTimes"),
                  let oldDates = try? JSONDecoder().decode([Date].self, from: data) {
            // Migration from old [Date] format to new [ScheduledTime] format
            self.scheduledTimes = oldDates.map { ScheduledTime(date: $0) }
        } else {
            self.scheduledTimes = []
        }

        self.appLaunchEnabled = UserDefaults.standard.object(forKey: "appLaunchEnabled") as? Bool ?? false

        if let data = UserDefaults.standard.data(forKey: "monitoredApps"),
           let decoded = try? JSONDecoder().decode([MonitoredApp].self, from: data) {
            self.monitoredApps = decoded
        } else {
            self.monitoredApps = []
        }

        self.recalculateOnActivation = UserDefaults.standard.object(forKey: "recalculateOnActivation") as? Bool ?? true

        // Load no-go times
        self.noGoEnabled = UserDefaults.standard.object(forKey: "noGoEnabled") as? Bool ?? false
        if let data = UserDefaults.standard.data(forKey: "noGoTimes"),
           let decoded = try? JSONDecoder().decode([NoGoTime].self, from: data) {
            self.noGoTimes = decoded
        } else {
            self.noGoTimes = []
        }

        // Load activate hotkey settings - default is Command-Shift-P
        let defaultModifiers = UInt32(cmdKey | shiftKey)
        let defaultKeyCode: UInt32 = 35 // Key code for 'P'

        // Try new key first, fallback to old key for backwards compatibility
        if let modifiers = UserDefaults.standard.object(forKey: "activateHotkeyModifiers") as? UInt32 {
            self.activateHotkeyModifiers = modifiers
        } else {
            self.activateHotkeyModifiers = UserDefaults.standard.object(forKey: "hotkeyModifiers") as? UInt32 ?? defaultModifiers
        }

        if let keyCode = UserDefaults.standard.object(forKey: "activateHotkeyKeyCode") as? UInt32 {
            self.activateHotkeyKeyCode = keyCode
        } else {
            self.activateHotkeyKeyCode = UserDefaults.standard.object(forKey: "hotkeyKeyCode") as? UInt32 ?? defaultKeyCode
        }

        let defaultExitModifiers: UInt32 = 0 // No modifiers
        let defaultExitKeyCode: UInt32 = 14
        self.exitHotkeyModifiers = UserDefaults.standard.object(forKey: "exitHotkeyModifiers") as? UInt32 ?? defaultExitModifiers
        self.exitHotkeyKeyCode = UserDefaults.standard.object(forKey: "exitHotkeyKeyCode") as? UInt32 ?? defaultExitKeyCode

        let defaultSnoozeModifiers: UInt32 = 0 // No modifiers
        let defaultSnoozeKeyCode: UInt32 = 49
        self.snoozeDuration = UserDefaults.standard.object(forKey: "snoozeDuration") as? Int ?? 5
        self.snoozeHotkeyModifiers = UserDefaults.standard.object(forKey: "snoozeHotkeyModifiers") as? UInt32 ?? defaultSnoozeModifiers
        self.snoozeHotkeyKeyCode = UserDefaults.standard.object(forKey: "snoozeHotkeyKeyCode") as? UInt32 ?? defaultSnoozeKeyCode

        // Load UI state
        self.selectedTab = UserDefaults.standard.object(forKey: "selectedTab") as? Int ?? 0

        // Apply launch at login setting on init
        updateLaunchAtLogin()
    }

    func getActualPauseDuration() -> Int {
        if pauseVariance == 0 {
            return pauseDuration
        }

        let variance = Int.random(in: -pauseVariance...pauseVariance)
        let duration = pauseDuration + variance
        return max(10, duration) // Minimum 10 seconds
    }

    // Get human-readable activate hotkey string
    func getActivateHotkeyString() -> String {
        return formatHotkeyString(modifiers: activateHotkeyModifiers, keyCode: activateHotkeyKeyCode)
    }

    // Get human-readable exit hotkey string
    func getExitHotkeyString() -> String {
        return formatHotkeyString(modifiers: exitHotkeyModifiers, keyCode: exitHotkeyKeyCode)
    }

    // Get human-readable snooze hotkey string
    func getSnoozeHotkeyString() -> String {
        return formatHotkeyString(modifiers: snoozeHotkeyModifiers, keyCode: snoozeHotkeyKeyCode)
    }

    private func formatHotkeyString(modifiers: UInt32, keyCode: UInt32) -> String {
        var parts: [String] = []

        // Add modifiers (if any)
        if modifiers & UInt32(controlKey) != 0 {
            parts.append("⌃")
        }
        if modifiers & UInt32(optionKey) != 0 {
            parts.append("⌥")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("⇧")
        }
        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("⌘")
        }

        // Add key name
        let keyName = keyCodeToString(keyCode)

        // If no modifiers, just return the key name
        if parts.isEmpty {
            return keyName
        }

        parts.append(keyName)
        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String {
        // Map common key codes to their string representations
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Escape"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 105: return "F13"
        case 106: return "F16"
        case 107: return "F14"
        case 109: return "F10"
        case 111: return "F12"
        case 113: return "F15"
        case 115: return "Home"
        case 116: return "Page Up"
        case 117: return "Fwd Delete"
        case 118: return "F4"
        case 119: return "End"
        case 120: return "F2"
        case 121: return "Page Down"
        case 122: return "F1"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "[\(keyCode)]"
        }
    }

    // MARK: - Launch at Login

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                if SMAppService.mainApp.status == .enabled {
                    print("✅ Launch at login already enabled")
                } else {
                    try SMAppService.mainApp.register()
                    print("✅ Launch at login enabled")
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    print("🔴 Launch at login disabled")
                } else {
                    print("🔴 Launch at login already disabled")
                }
            }
        } catch {
            print("❌ Failed to update launch at login: \(error.localizedDescription)")
        }
    }

    // Sync the setting with actual system status
    func syncLaunchAtLoginStatus() {
        let systemStatus = SMAppService.mainApp.status == .enabled
        if launchAtLogin != systemStatus {
            // Update without triggering didSet
            DispatchQueue.main.async {
                self.launchAtLogin = systemStatus
            }
        }
    }

    // MARK: - No-Go Time Management

    func deleteNoGoTime(at offsets: IndexSet) {
        noGoTimes.remove(atOffsets: offsets)
    }

    func deleteNoGoTime(id: UUID) {
        noGoTimes.removeAll { $0.id == id }
    }

    func clearAllNoGoTimes() {
        noGoTimes.removeAll()
    }

    // Check if current time is within a no-go period
    func isInNoGoTime() -> Bool {
        guard noGoEnabled else { return false }

        let calendar = Calendar.current
        let now = Date()
        let currentWeekday = calendar.component(.weekday, from: now)

        for noGoTime in noGoTimes {
            // Skip disabled no-go times
            guard noGoTime.isEnabled else { continue }

            // Check if today is in the repeat days (empty = applies to all days for one-shot)
            let appliestoday = noGoTime.repeatDays.isEmpty || noGoTime.repeatDays.contains(currentWeekday)
            guard appliestoday else { continue }

            // Extract hour and minute from the stored start/end times
            let startComponents = calendar.dateComponents([.hour, .minute], from: noGoTime.startTime)
            let endComponents = calendar.dateComponents([.hour, .minute], from: noGoTime.endTime)

            guard let startHour = startComponents.hour,
                  let startMinute = startComponents.minute,
                  let endHour = endComponents.hour,
                  let endMinute = endComponents.minute else {
                continue
            }

            // Create today's start and end times
            var todayStartComponents = calendar.dateComponents([.year, .month, .day], from: now)
            todayStartComponents.hour = startHour
            todayStartComponents.minute = startMinute
            todayStartComponents.second = 0

            var todayEndComponents = calendar.dateComponents([.year, .month, .day], from: now)
            todayEndComponents.hour = endHour
            todayEndComponents.minute = endMinute
            todayEndComponents.second = 0

            guard let todayStart = calendar.date(from: todayStartComponents),
                  var todayEnd = calendar.date(from: todayEndComponents) else {
                continue
            }

            // Handle case where end time is before start time (crosses midnight)
            if todayEnd <= todayStart {
                todayEnd = calendar.date(byAdding: .day, value: 1, to: todayEnd) ?? todayEnd
            }

            // Check if current time is within the no-go period
            if now >= todayStart && now <= todayEnd {
                return true
            }
        }

        return false
    }

    // MARK: - Reset Settings

    func resetAllSettings() {
        // Detection settings
        detectionEnabled = true
        inputDelayBuffer = 60

        // Doom scroll detection settings
        doomScrollEnabled = false
        doomScrollVelocityThreshold = 3000
        doomScrollDirectionalityThreshold = 0.85
        doomScrollPauseThreshold = 1.5
        doomScrollWindowDuration = 3
        doomScrollMessage = "Take a Break from Scrolling"

        // Session settings
        pauseDuration = 60
        pauseVariance = 0
        sessionDisplayText = "Just Breathe"
        lockSessionEnabled = false

        // Sound settings
        soundEnabled = true
        soundVolume = 0.5
        soundRepeatRate = 0
        selectedAmbientSound = "random"
        startSoundEnabled = true
        startSoundVolume = 0.5
        endSoundEnabled = true
        endSoundVolume = 0.5

        // General settings
        launchAtLogin = true

        // Menu bar settings
        showInMenuBar = true
        menuBarShowTimer = true

        // Activation settings
        repeatedEnabled = false
        repeatedInterval = 60
        randomEnabled = false
        randomMinInterval = 30
        randomMaxInterval = 120
        scheduledEnabled = false
        scheduledTimes = []
        appLaunchEnabled = false
        monitoredApps = []
        recalculateOnActivation = true

        // No-go settings
        noGoEnabled = false
        noGoTimes = []

        // Hotkey settings
        let defaultModifiers = UInt32(cmdKey | shiftKey)
        let defaultKeyCode: UInt32 = 35 // Key code for 'P'
        activateHotkeyModifiers = defaultModifiers
        activateHotkeyKeyCode = defaultKeyCode

        exitHotkeyModifiers = 0
        exitHotkeyKeyCode = 14

        snoozeHotkeyModifiers = 0
        snoozeHotkeyKeyCode = 49
        snoozeDuration = 5

        // Stats (don't reset these)
        // completedSessions
        // completedSessionTime

        // Clear undo/redo stacks
        undoStack.removeAll()
        redoStack.removeAll()

        // UI state (don't reset)
        // selectedTab
    }
}
