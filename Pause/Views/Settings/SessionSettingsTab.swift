//
//  SessionSettingsTab.swift
//  Pause
//
//  Session duration and display settings
//

import SwiftUI
import AppKit

struct SessionSettingsTab: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var lockManager = InputLockManager.shared

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Pause Duration")
                        .frame(width: 140, alignment: .leading)
                    Slider(value: Binding(
                        get: { SliderHelpers.indexForDuration(settings.pauseDuration) },
                        set: { settings.pauseDuration = SliderHelpers.durationSteps()[Int($0)] }
                    ), in: 0...Double(SliderHelpers.durationSteps().count - 1), step: 1)
                    EditableTimeField(
                        seconds: $settings.pauseDuration,
                        formatter: SliderHelpers.formatDuration,
                        parser: SliderHelpers.parseTimeString,
                        width: 60
                    )
                }

                HStack {
                    Text("Time Variance")
                        .frame(width: 140, alignment: .leading)
                    Slider(value: Binding(
                        get: { SliderHelpers.indexForVariance(settings.pauseVariance) },
                        set: { settings.pauseVariance = SliderHelpers.varianceSteps()[Int($0)] }
                    ), in: 0...Double(SliderHelpers.varianceSteps().count - 1), step: 1)
                    Text(settings.pauseVariance == 0 ? "None" : "±\(SliderHelpers.formatDuration(settings.pauseVariance))")
                        .frame(width: 50, alignment: .trailing)
                        .monospacedDigit()
                }

                HStack {
                    Text("Snooze Duration")
                        .frame(width: 140, alignment: .leading)
                    Slider(value: Binding(
                        get: { SliderHelpers.indexForActivation(settings.snoozeDuration) },
                        set: { settings.snoozeDuration = SliderHelpers.activationSteps()[Int($0)] }
                    ), in: 0...Double(SliderHelpers.activationSteps().count - 1), step: 1)
                    Text(SliderHelpers.formatActivation(settings.snoozeDuration))
                        .frame(width: 50, alignment: .trailing)
                        .monospacedDigit()
                }
            } header: {
                Text("Timing")
            } footer: {
                Text("Snooze duration determines how long to delay when pressing the snooze key during a session.")
                    .font(.caption)
            }

            Section {
                HStack {
                    Text("Display Text")
                        .frame(width: 140, alignment: .leading)
                    TextField("", text: $settings.sessionDisplayText)
                        .textFieldStyle(.roundedBorder)
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text("Text displayed during meditation sessions. Scheduled activations and snoozes will show their custom labels instead.")
                    .font(.caption)
            }

            Section {
                Toggle("Lock Input During Session", isOn: $settings.lockSessionEnabled)

                if settings.lockSessionEnabled {
                    HStack {
                        Text("Accessibility Permission")
                            .frame(width: 180, alignment: .leading)
                        if lockManager.hasAccessibilityPermission {
                            Text("✅ Granted")
                                .foregroundColor(.green)
                        } else {
                            Text("❌ Not Granted")
                                .foregroundColor(.red)
                        }

                        Spacer()

                        if !lockManager.hasAccessibilityPermission {
                            Button("Open System Settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                    }

                    HStack {
                        Text("Input Monitoring Permission")
                            .frame(width: 180, alignment: .leading)
                        if lockManager.hasInputMonitoringPermission {
                            Text("✅ Granted")
                                .foregroundColor(.green)
                        } else {
                            Text("❌ Not Granted")
                                .foregroundColor(.red)
                        }

                        Spacer()

                        if !lockManager.hasInputMonitoringPermission {
                            Button("Open System Settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                    }

                }
            } header: {
                Text("Input Blocking")
            } footer: {
                if settings.lockSessionEnabled {
                    if lockManager.hasAllPermissions() {
                        Text("Input blocking is ready. All keyboard, mouse, and trackpad input will be blocked during meditation sessions.")
                            .font(.caption)
                    } else {
                        Text("Both permissions are required. Click the buttons above to open System Settings, grant the permissions, then restart the app.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } else {
                    Text("When enabled, blocks all keyboard and mouse/trackpad input during meditation sessions.")
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
