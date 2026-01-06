//
//  AppState.swift
//  Pause
//
//  Created by Harrison Qian on 10/22/25.
//

import SwiftUI
import AppKit
import AVFoundation
import Carbon.HIToolbox

class AppState: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AppState()

    @Published var isPauseMode: Bool = false
    @Published var timeRemaining: Int = 60
    @Published var currentDisplayText: String = "Just Breathe"

    var timer: Timer?
    var audioPlayer: AVAudioPlayer?
    var startSoundPlayer: AVAudioPlayer?
    var endSoundPlayer: AVAudioPlayer?
    var eventMonitor: Any?
    var createdWindows: [NSWindow] = []  // Keep strong references to windows we create
    var soundRepeatTimer: Timer?
    var currentSessionDuration: Int = 0  // Track the duration of the current session

    // Available ambient sound files
    let ambientSounds = [
        "pad",
        "pad2",
        "keys",
        "rain",
        "walking",
        "birds",
        "waves",
        "chords"
    ]

    private override init() {
        super.init()

        // Set up observer to handle window closing during pause mode
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,  // Observe all windows
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let window = notification.object as? NSWindow,
                  window.title == "Pause" else { return }

            // If we're in pause mode and the Pause window is closing, end the session
            if self.isPauseMode {
                print("Window closing during pause mode - ending session")
                self.endPauseMode(completed: false)

                // Only remove fullscreen windows from array when in pause mode
                // Settings windows should stay in the array for reuse
                if window.styleMask.contains(.fullScreen) {
                    self.createdWindows.removeAll { $0 === window }
                }
            }
            // Don't remove settings windows from createdWindows - keep them for reuse
        }
    }

    func triggerPauseMode(displayText: String? = nil, isLocked: Bool? = nil, customDuration: Int? = nil) {
        if isPauseMode {
            // If already in pause mode, exit it early (not completed)
            endPauseMode(completed: false)
        } else {
            // Enter pause mode
            startPauseMode(displayText: displayText, isLocked: isLocked, customDuration: customDuration)
        }
    }

    func snoozeSession() {
        guard isPauseMode else { return }

        // Save the current display text for the snooze label
        let snoozeLabel = "Snooze of: \(currentDisplayText)"

        // Calculate snooze time BEFORE ending pause mode
        let snoozeDuration = Settings.shared.snoozeDuration
        let now = Date()
        let snoozeDate = now.addingTimeInterval(TimeInterval(snoozeDuration * 60))

        print("Snooze: duration=\(snoozeDuration) min, now=\(now), snoozeDate=\(snoozeDate), interval=\(snoozeDate.timeIntervalSince(now))s")

        // End the current session (not completed)
        endPauseMode(completed: false)

        // Add a one-time scheduled activation for the snooze
        let snoozeTime = ScheduledTime(date: snoozeDate, name: snoozeLabel, isRecurring: false)
        Settings.shared.scheduledTimes.append(snoozeTime)

        print("Snooze scheduled for \(snoozeDuration) minutes from now at \(snoozeDate.formatted(date: .omitted, time: .standard)): '\(snoozeLabel)'")
    }

    func startPauseMode(displayText: String? = nil, isLocked: Bool? = nil, customDuration: Int? = nil) {
        isPauseMode = true

        // Pause activation timers during the session
        ActivationScheduler.shared.pauseTimers()

        // Set the display text (use provided text, or default from settings)
        currentDisplayText = displayText ?? Settings.shared.sessionDisplayText

        // Use custom duration if provided, otherwise use global settings with variance
        if let duration = customDuration {
            currentSessionDuration = duration
        } else {
            currentSessionDuration = Settings.shared.getActualPauseDuration()
        }
        timeRemaining = currentSessionDuration

        // Ensure a window exists and go fullscreen
        ensureWindowAndFullscreen()

        // Play start sound
        playStartSound()

        // Start playing a random ambient sound if enabled
        if Settings.shared.soundEnabled {
            playRandomAmbientSound()
        }

        // Enable input locking: use per-activation override if provided, otherwise global setting
        let shouldLock = isLocked ?? Settings.shared.lockSessionEnabled
        if shouldLock {
            InputLockManager.shared.startBlocking()
        }

        // Start the countdown timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                // Timer completed naturally - this is a completed session
                self.endPauseMode(completed: true)
            }
        }

        // Add event monitor for exit and snooze hotkeys
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let settings = Settings.shared

            // Convert NSEvent modifiers to Carbon modifiers (only count the ones we care about)
            var carbonModifiers: UInt32 = 0
            if event.modifierFlags.contains(.control) {
                carbonModifiers |= UInt32(controlKey)
            }
            if event.modifierFlags.contains(.option) {
                carbonModifiers |= UInt32(optionKey)
            }
            if event.modifierFlags.contains(.shift) {
                carbonModifiers |= UInt32(shiftKey)
            }
            if event.modifierFlags.contains(.command) {
                carbonModifiers |= UInt32(cmdKey)
            }

            // Check if the pressed key matches the exit hotkey
            if UInt32(event.keyCode) == settings.exitHotkeyKeyCode && carbonModifiers == settings.exitHotkeyModifiers {
                self.endPauseMode(completed: false)
                return nil // Consume the event
            }

            // Check if the pressed key matches the snooze hotkey
            if UInt32(event.keyCode) == settings.snoozeHotkeyKeyCode && carbonModifiers == settings.snoozeHotkeyModifiers {
                self.snoozeSession()
                return nil // Consume the event
            }

            return event
        }
    }

    func endPauseMode(completed: Bool) {
        // If session was completed (timer reached 0), track it
        if completed {
            Settings.shared.completedSessions += 1
            Settings.shared.completedSessionTime += currentSessionDuration
            print("Session completed! Total sessions: \(Settings.shared.completedSessions), Total time: \(Settings.shared.completedSessionTime)s")

            // Play end sound
            playEndSound()
        } else {
            print("Session ended early (not counted)")
        }

        // Resume or recalculate timers after session ends
        if Settings.shared.recalculateOnActivation {
            // Recalculate timers from scratch (creates new timers)
            print("Recalculating timers after session ended")
            ActivationScheduler.shared.recalculateTimers()
        } else {
            // Resume paused timers with their remaining time
            ActivationScheduler.shared.resumeTimers()
        }

        // Stop the timer
        timer?.invalidate()
        timer = nil

        // Stop the sound repeat timer
        soundRepeatTimer?.invalidate()
        soundRepeatTimer = nil

        // Stop the audio players
        audioPlayer?.stop()
        audioPlayer = nil

        startSoundPlayer?.stop()
        startSoundPlayer = nil

        // Disable input locking
        InputLockManager.shared.stopBlocking()

        // Remove event monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        // Exit fullscreen
        exitFullscreen()

        // Exit pause mode
        isPauseMode = false

        // Reset current session duration
        currentSessionDuration = 0
    }

    private func ensureWindowAndFullscreen() {
        // Activate the app first
        NSApp.activate(ignoringOtherApps: true)

        // Find existing window - look for the Pause window (from WindowGroup or previously created)
        let window = NSApplication.shared.windows.first { window in
            // Look for our main Pause window regardless of current style mask
            return window.title == "Pause"
        }

        if let window = window {
            // Use existing window
            window.makeKeyAndOrderFront(nil)

            // Ensure Mission Control treats this as the primary fullscreen window
            window.collectionBehavior.insert(.fullScreenPrimary)

            // Wait for window to be ready before toggling fullscreen (same delay as new windows)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Only toggle fullscreen if not already fullscreen
                if !window.styleMask.contains(.fullScreen) {
                    window.toggleFullScreen(nil)
                }
            }
        } else {
            // No window exists, create one manually
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            newWindow.center()
            newWindow.title = "Pause"
            newWindow.setFrameAutosaveName("Main Window")
            newWindow.isReleasedWhenClosed = false  // Keep window alive when closed

            newWindow.collectionBehavior.insert(.fullScreenPrimary)

            // Create ContentView with shared state
            newWindow.contentView = NSHostingView(rootView: ContentView())

            // Keep a strong reference to the window
            createdWindows.append(newWindow)

            newWindow.makeKeyAndOrderFront(nil)

            // Wait for the window to be ready, then go fullscreen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                newWindow.toggleFullScreen(nil)
            }
        }
    }

    private func exitFullscreen() {
        // Find all fullscreen windows and exit them
        for window in NSApplication.shared.windows {
            if window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        }
    }

    private func playRandomAmbientSound() {
        let selectedSound = Settings.shared.selectedAmbientSound

        if selectedSound == "random" {
            // Select a random ambient sound
            guard let randomSound = ambientSounds.randomElement() else { return }
            playAmbientSound(randomSound)
        } else {
            // Play the specifically selected sound
            playAmbientSound(selectedSound)
        }
    }

    private func playAmbientSound(_ soundName: String) {
        // Get the URL for the sound file (Xcode copies them to the main bundle Resources)
        guard let soundURL = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            print("Could not find audio file: \(soundName).mp3")
            return
        }

        do {
            // Create and configure audio player
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.delegate = self
            audioPlayer?.volume = Float(Settings.shared.soundVolume)

            let repeatRate = Settings.shared.soundRepeatRate
            if repeatRate > 0 {
                // Play once, then wait for repeat rate before playing again
                audioPlayer?.numberOfLoops = 0
            } else {
                // No silence between - loop indefinitely
                audioPlayer?.numberOfLoops = -1
            }

            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            print("Playing ambient sound: \(soundName).mp3 (volume: \(Int(Settings.shared.soundVolume * 100))%)")
        } catch {
            print("Error playing audio: \(error.localizedDescription)")
        }
    }

    private func playStartSound() {
        guard Settings.shared.startSoundEnabled else {
            print("Start sound is disabled")
            return
        }

        guard let soundURL = Bundle.main.url(forResource: "start", withExtension: "mp3") else {
            print("Could not find start.mp3")
            return
        }

        do {
            startSoundPlayer = try AVAudioPlayer(contentsOf: soundURL)
            startSoundPlayer?.volume = Float(Settings.shared.startSoundVolume)
            startSoundPlayer?.prepareToPlay()
            startSoundPlayer?.play()
            print("Playing start.mp3 (volume: \(Int(Settings.shared.startSoundVolume * 100))%)")
        } catch {
            print("Error playing start sound: \(error.localizedDescription)")
        }
    }

    private func playEndSound() {
        guard Settings.shared.endSoundEnabled else {
            print("End sound is disabled")
            return
        }

        guard let soundURL = Bundle.main.url(forResource: "end", withExtension: "mp3") else {
            print("Could not find end.mp3")
            return
        }

        do {
            endSoundPlayer = try AVAudioPlayer(contentsOf: soundURL)
            endSoundPlayer?.volume = Float(Settings.shared.endSoundVolume)
            endSoundPlayer?.prepareToPlay()
            endSoundPlayer?.play()
            print("Playing end.mp3 (volume: \(Int(Settings.shared.endSoundVolume * 100))%)")
        } catch {
            print("Error playing end sound: \(error.localizedDescription)")
        }
    }

    // AVAudioPlayerDelegate method - called when audio finishes playing
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard isPauseMode, Settings.shared.soundEnabled else { return }

        let repeatRate = Settings.shared.soundRepeatRate
        if repeatRate > 0 {
            // Wait for the specified silence duration before playing next track
            print("Waiting \(repeatRate)s before next track...")
            soundRepeatTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(repeatRate), repeats: false) { [weak self] _ in
                self?.playRandomAmbientSound()
            }
        } else {
            // No repeat rate, play immediately (shouldn't happen with numberOfLoops = -1, but just in case)
            playRandomAmbientSound()
        }
    }
}
