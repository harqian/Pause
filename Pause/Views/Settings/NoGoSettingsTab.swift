//
//  NoGoSettingsTab.swift
//  Pause
//
//  Settings for preventing interruptions
//

import SwiftUI

struct NoGoSettingsTab: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var detector = InputDetectionManager.shared
    @State private var customizingNoGoTimeId: UUID?

    var body: some View {
        Form {
            // SECTION 1: Don't Interrupt (Input Detection)
            Section {
                Toggle("Don't Interrupt While Working", isOn: $settings.detectionEnabled)
                    .toggleStyle(.switch)

                if settings.detectionEnabled {
                    HStack {
                        Text("Minimum Buffer")
                            .frame(width: 140, alignment: .leading)
                        Slider(value: Binding(
                            get: { SliderHelpers.indexForBuffer(settings.inputDelayBuffer) },
                            set: { settings.inputDelayBuffer = SliderHelpers.bufferSteps()[Int($0)] }
                        ), in: 0...Double(SliderHelpers.bufferSteps().count - 1), step: 1)
                        Text(SliderHelpers.formatBuffer(settings.inputDelayBuffer))
                            .frame(width: 60, alignment: .trailing)
                            .monospacedDigit()
                    }
                }

                if settings.detectionEnabled {
                    HStack {
                        Text("Input Monitoring Permission")
                            .frame(width: 180, alignment: .leading)
                        if detector.hasInputMonitoringPermission {
                            Text("Granted")
                                .foregroundColor(.green)
                        } else {
                            Text("Not Granted")
                                .foregroundColor(.red)
                        }

                        Spacer()

                        if !detector.hasInputMonitoringPermission {
                            Button("Open System Settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Don't Interrupt")
            } footer: {
                if settings.detectionEnabled {
                    Text("Keyboard/mouse input will delay upcoming activations by \(SliderHelpers.formatBuffer(settings.inputDelayBuffer)).")
                        .font(.caption)
                } else {
                    Text("Enable to delay activations while you're actively working.")
                        .font(.caption)
                }
            }

            // SECTION 2: No-Go Times (unified)
            Section {
                Toggle("No-Go Times", isOn: $settings.noGoEnabled)
                    .toggleStyle(.switch)

                ForEach($settings.noGoTimes) { $noGoTime in
                    HStack(alignment: .center, spacing: 8) {
                        Toggle("", isOn: $noGoTime.isEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                DatePicker("", selection: $noGoTime.startTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .disabled(!noGoTime.isEnabled)

                                Text("-")
                                    .foregroundColor(.secondary)

                                DatePicker("", selection: $noGoTime.endTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .disabled(!noGoTime.isEnabled)

                                Text(noGoTime.name)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Text(formatRepeatDays(noGoTime.repeatDays))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            customizingNoGoTimeId = noGoTime.id
                        }) {
                            Image(systemName: "gearshape")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(
                            isPresented: Binding(
                                get: { customizingNoGoTimeId == noGoTime.id },
                                set: { if !$0 { customizingNoGoTimeId = nil } }
                            )
                        ) {
                            NoGoTimeCustomizeView(noGoTime: $noGoTime)
                        }

                        Button(action: {
                            settings.deleteNoGoTime(id: noGoTime.id)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .opacity(noGoTime.isEnabled ? 1.0 : 0.6)
                }

                HStack {
                    Button("Add No-Go Time") {
                        let calendar = Calendar.current
                        let now = Date()
                        var startComponents = calendar.dateComponents([.year, .month, .day], from: now)
                        startComponents.hour = 9
                        startComponents.minute = 0
                        var endComponents = calendar.dateComponents([.year, .month, .day], from: now)
                        endComponents.hour = 17
                        endComponents.minute = 0

                        if let startTime = calendar.date(from: startComponents),
                           let endTime = calendar.date(from: endComponents) {
                            settings.noGoTimes.append(NoGoTime(
                                startTime: startTime,
                                endTime: endTime,
                                name: "Work Hours"
                            ))
                        }
                    }
                    .disabled(!settings.noGoEnabled)

                    Spacer()

                    Button("Clear All") {
                        settings.noGoTimes.removeAll()
                    }
                    .disabled(!settings.noGoEnabled || settings.noGoTimes.isEmpty)
                }
            } header: {
                Text("No-Go Times")
            } footer: {
                Text("Activations will not trigger during these time periods on selected days.")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

}

struct NoGoTimeCustomizeView: View {
    @Binding var noGoTime: NoGoTime

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Customize No-Go Time")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                TextField("Name", text: $noGoTime.name)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Repeat")
                DayPicker(selectedDays: $noGoTime.repeatDays)
                Text(formatRepeatDays(noGoTime.repeatDays))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 280)
    }
}

