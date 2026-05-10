//
//  BreathingView.swift
//  Pause
//
//  Extracted from ContentView.swift
//

import SwiftUI

struct BreathingView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var settings = Settings.shared
    @ObservedObject var lockManager = InputLockManager.shared
    @State private var gradientRotation: Double = 0

    var body: some View {
        ZStack {
            // Animated background gradient - green theme
            TimelineView(.animation) { context in
                let rotation = (context.date.timeIntervalSinceReferenceDate / 8.0).truncatingRemainder(dividingBy: 1.0)

                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 151/255, green: 187/255, blue: 101/255),  // Dark green
                        Color(red: 198/255, green: 225/255, blue: 116/255),  // Light green
                        Color(red: 215/255, green: 225/255, blue: 199/255)   // Pale light green
                    ]),
                    startPoint: UnitPoint(
                        x: 0.5 + 0.5 * cos(rotation * 2 * .pi),
                        y: 0.5 + 0.5 * sin(rotation * 2 * .pi)
                    ),
                    endPoint: UnitPoint(
                        x: 0.5 - 0.5 * cos(rotation * 2 * .pi),
                        y: 0.5 - 0.5 * sin(rotation * 2 * .pi)
                    )
                )
            }
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Main message
                Text(appState.currentDisplayText)
                    .font(.system(size: 72, weight: .light, design: .rounded))
                    .foregroundColor(.white)

                // Breathing circle animation
                TimelineView(.animation) { context in
                    let scale = calculateBreathingScale(date: context.date)

                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 200, height: 200)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .scaleEffect(scale)
                }

                // Timer display
                Text(formatTime(appState.timeRemaining))
                    .font(.system(size: 48, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                // Instructions - conditional based on lock state and permissions
                VStack(spacing: 8) {
                    if settings.lockSessionEnabled {
                        if lockManager.hasAllPermissions() {
                            // Lock is enabled AND permissions are granted - truly locked
                            Text("Session locked - wait for completion")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        } else {
                            // Lock is enabled BUT missing permissions - not actually locked
                            VStack(spacing: 8) {
                                Text("⚠️ Session attempted lock but no permissions")
                                    .font(.caption)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(.yellow.opacity(0.9))
                                    )

                                Text("Press \(settings.getExitHotkeyString()) to exit early")
                                    .foregroundColor(.white)
                                Text("Press \(settings.getSnoozeHotkeyString()) to snooze")
                                    .foregroundColor(.white)
                            }
                        }
                    } else {
                        // Lock is disabled - show normal shortcuts
                        Text("Press \(settings.getExitHotkeyString()) to exit early")
                            .foregroundColor(.white)
                        Text("Press \(settings.getSnoozeHotkeyString()) to snooze")
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 40)
            }
            .textSelection(.enabled)
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func calculateBreathingScale(date: Date) -> Double {
        // breathing cycle: 3s inhale + 5s exhale = 8s total (matches real deep breathing)
        let inhaleDuration = 3.0
        let exhaleDuration = 5.0
        let totalCycleDuration = inhaleDuration + exhaleDuration

        // Calculate position in the breathing cycle
        let timeInCycle = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: totalCycleDuration)

        let scale: Double
        if timeInCycle < inhaleDuration {
            // Inhale phase: grow from 0.8 to 1.2
            let progress = timeInCycle / inhaleDuration
            // Use ease-in-out for smooth breathing
            let eased = (1.0 - cos(progress * .pi)) / 2.0
            scale = 0.8 + (eased * 0.4)
        } else {
            // Exhale phase: shrink from 1.2 to 0.8
            let progress = (timeInCycle - inhaleDuration) / exhaleDuration
            // Use ease-in-out for smooth breathing
            let eased = (1.0 - cos(progress * .pi)) / 2.0
            scale = 1.2 - (eased * 0.4)
        }

        return scale
    }
}

#Preview {
    BreathingView()
}
