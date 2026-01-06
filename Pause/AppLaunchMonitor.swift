//
//  AppLaunchMonitor.swift
//  Pause
//
//  Monitors app launches and triggers pause mode for monitored apps
//

import Foundation
import AppKit

class AppLaunchMonitor {
    static let shared = AppLaunchMonitor()

    private init() {
        setupNotifications()
    }

    private func setupNotifications() {
        // Monitor when apps are launched
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )

        print("📱 AppLaunchMonitor: Monitoring app launches")
    }

    @objc private func appDidLaunch(_ notification: Notification) {
        guard Settings.shared.appLaunchEnabled else { return }

        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleIdentifier = app.bundleIdentifier else {
            return
        }

        let monitoredApps = Settings.shared.monitoredApps

        // Check if this app is in the monitored list
        if let monitoredApp = monitoredApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            let appName = app.localizedName ?? monitoredApp.name
            let delay = monitoredApp.activationDelay

            print("📱 AppLaunchMonitor: Monitored app launched: \(appName)")
            print("📱 Will trigger pause mode in \(delay) seconds...")

            // Delay activation to give app time to fully launch
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // Use custom message if provided, otherwise use default
                let message = monitoredApp.customMessage ?? "Focus on \(appName)"
                AppState.shared.triggerPauseMode(displayText: message, isLocked: monitoredApp.isLocked, customDuration: monitoredApp.customDuration)
            }
        }
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
