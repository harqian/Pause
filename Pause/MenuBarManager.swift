//
//  MenuBarManager.swift
//  Pause
//
//  Created by Harrison Qian on 10/22/25.
//

import SwiftUI
import AppKit

class MenuBarManager: ObservableObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var isShowing = false
    private var updateTimer: Timer?

    private init() {
        // Initialize based on current setting
        updateMenuBarVisibility()
    }

    func updateMenuBarVisibility() {
        let shouldShow = Settings.shared.showInMenuBar

        if shouldShow && !isShowing {
            showMenuBar()
        } else if !shouldShow && isShowing {
            hideMenuBar()
        }
    }

    private func showMenuBar() {
        guard statusItem == nil else { return }

        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.action = #selector(menuBarIconClicked)
            button.target = self
        }

        // Start updating the countdown
        updateCountdown()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCountdown()
        }

        // Create menu
        let menu = NSMenu()

        // Start Session menu item
        let startItem = NSMenuItem(
            title: "Start Session",
            action: #selector(startSession),
            keyEquivalent: ""
        )
        startItem.target = self
        menu.addItem(startItem)

        menu.addItem(NSMenuItem.separator())

        // Quick No-Go menu items
        let noGo15Item = NSMenuItem(
            title: "No-Go for 15 minutes",
            action: #selector(addNoGo15),
            keyEquivalent: ""
        )
        noGo15Item.target = self
        menu.addItem(noGo15Item)

        let noGo30Item = NSMenuItem(
            title: "No-Go for 30 minutes",
            action: #selector(addNoGo30),
            keyEquivalent: ""
        )
        noGo30Item.target = self
        menu.addItem(noGo30Item)

        let noGo1hItem = NSMenuItem(
            title: "No-Go for 1 hour",
            action: #selector(addNoGo1h),
            keyEquivalent: ""
        )
        noGo1hItem.target = self
        menu.addItem(noGo1hItem)

        menu.addItem(NSMenuItem.separator())

        // New Window menu item
        let newWindowItem = NSMenuItem(
            title: "New Window",
            action: #selector(newWindow),
            keyEquivalent: "n"
        )
        newWindowItem.target = self
        menu.addItem(newWindowItem)

        menu.addItem(NSMenuItem.separator())

        // Quit menu item
        let quitItem = NSMenuItem(
            title: "Quit Pause",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        isShowing = true
    }

    private func hideMenuBar() {
        updateTimer?.invalidate()
        updateTimer = nil

        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
            isShowing = false
        }
    }

    func updateCountdown() {
        guard let button = statusItem?.button else { return }

        let showTimer = Settings.shared.menuBarShowTimer

        if showTimer, let nextActivation = ActivationScheduler.shared.getNextActivation() {
            // Show countdown timer
            let timeRemaining = max(0, nextActivation.date.timeIntervalSinceNow)

            // If timer hits 0:00, recalculate all timers
            if timeRemaining <= 0 {
                print("Timer reached 0:00 - recalculating all timers")
                ActivationScheduler.shared.recalculateTimers()
            }

            let countdownText = formatCountdown(timeRemaining)
            button.title = countdownText
            button.image = nil
        } else {
            // Show icon
            button.title = ""
            let image = NSImage(systemSymbolName: "pause.circle", accessibilityDescription: "Pause")
            image?.isTemplate = true
            button.image = image
        }
    }

    private func formatCountdown(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else if minutes > 0 {
            return String(format: "%d:%02d", minutes, secs)
        } else {
            return String(format: "0:%02d", secs)
        }
    }

    @objc private func menuBarIconClicked() {
        // This is called when the icon is clicked
        // The menu will show automatically
    }

    @objc private func startSession() {
        AppState.shared.triggerPauseMode()
    }

    @objc private func addNoGo15() {
        addQuickNoGo(minutes: 15)
    }

    @objc private func addNoGo30() {
        addQuickNoGo(minutes: 30)
    }

    @objc private func addNoGo1h() {
        addQuickNoGo(minutes: 60)
    }

    private func addQuickNoGo(minutes: Int) {
        let now = Date()
        let endTime = now.addingTimeInterval(TimeInterval(minutes * 60))
        let noGoTime = NoGoTime(
            startTime: now,
            endTime: endTime,
            name: "Quick \(minutes)m",
            repeatDays: [],  // One-shot
            isEnabled: true
        )
        Settings.shared.noGoTimes.append(noGoTime)
        Settings.shared.noGoEnabled = true
    }

    @objc private func newWindow() {
        // Activate the app
        NSApp.activate(ignoringOtherApps: true)

        // Always create a new window - it's a feature!
        let contentView = ContentView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 550),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.isReleasedWhenClosed = false  // Keep window alive when closed
        window.contentView = NSHostingView(rootView: contentView)
        window.title = "Pause"
        window.makeKeyAndOrderFront(nil)

        // Keep a strong reference to prevent deallocation
        AppState.shared.createdWindows.append(window)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
