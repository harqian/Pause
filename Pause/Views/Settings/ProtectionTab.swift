//
//  ProtectionTab.swift
//  Pause
//
//  everything about preventing unwanted interruptions: no-go times, input detection

import SwiftUI

struct ProtectionTab: View {
  @ObservedObject var settings = Settings.shared
  @ObservedObject var detector = InputDetectionManager.shared
  @State private var customizingNoGoTimeId: UUID?

  var body: some View {
    Form {
      // MARK: - Don't Interrupt
      Section {
        Toggle("Don't Interrupt While Working", isOn: $settings.detectionEnabled)
          .toggleStyle(.switch)

        if settings.detectionEnabled {
          HStack {
            Text("Buffer")
              .frame(width: 120, alignment: .leading)
            Slider(value: Binding(
              get: { SliderHelpers.indexForBuffer(settings.inputDelayBuffer) },
              set: { settings.inputDelayBuffer = SliderHelpers.bufferSteps()[Int($0)] }
            ), in: 0...Double(SliderHelpers.bufferSteps().count - 1), step: 1)
            Text(SliderHelpers.formatBuffer(settings.inputDelayBuffer))
              .frame(width: 50, alignment: .trailing)
              .monospacedDigit()
          }

          PermissionRow(
            label: "Input Monitoring",
            granted: detector.hasInputMonitoringPermission,
            settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
          )
        }
      } header: {
        Text("Don't Interrupt")
      } footer: {
        if settings.detectionEnabled {
          Text("Typing or mouse movement will push back upcoming breaks by \(SliderHelpers.formatBuffer(settings.inputDelayBuffer)).")
            .font(.caption)
        } else {
          Text("Delays breaks when you're actively working so they don't interrupt your flow.")
            .font(.caption)
        }
      }

      // MARK: - No-Go Times
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
        Text("Breaks won't trigger during these periods. Use for meetings, deep work blocks, or sleep.")
          .font(.caption)
      }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
  }
}

// keep the NoGoTimeCustomizeView here since it's specific to this tab
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
