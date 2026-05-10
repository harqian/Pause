//
//  ActivationCustomizeView.swift
//  Pause
//
//  shared customize popover for any activation mode (repeated, scheduled, app launch)

import SwiftUI

struct ActivationCustomizeView: View {
  let title: String
  @Binding var message: String?
  @Binding var isLocked: Bool?
  @Binding var customDuration: Int?
  @ObservedObject var settings = Settings.shared

  // optional extras
  var showRepeatDays: Binding<Set<Int>>? = nil
  var repeatDaysLabel: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(title)
        .font(.headline)

      // message
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Message")
          if message == nil {
            Text("(using default)")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        TextField("Message", text: Binding(
          get: { message ?? settings.sessionDisplayText },
          set: { message = $0.isEmpty ? nil : $0 }
        ))
        .textFieldStyle(.roundedBorder)
        if message != nil {
          Button("Reset to default") { message = nil }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
      }

      Divider()

      // repeat days (optional)
      if let daysBinding = showRepeatDays {
        VStack(alignment: .leading, spacing: 4) {
          Text("Repeat")
          DayPicker(selectedDays: daysBinding)
          if let label = repeatDaysLabel {
            Text(label)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Divider()
      }

      // lock toggle
      VStack(alignment: .leading, spacing: 4) {
        Toggle(
          isOn: Binding(
            get: { isLocked ?? false },
            set: { isLocked = $0 ? true : nil }
          )
        ) {
          HStack {
            Text("Lock Session")
            if isLocked == nil {
              Text("(using default)")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
        .toggleStyle(.switch)

        if isLocked != nil {
          Button("Reset to default") { isLocked = nil }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
      }

      Divider()

      // duration
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Duration")
          if customDuration == nil {
            Text("(using default: \(SliderHelpers.formatDuration(settings.pauseDuration)))")
              .font(.caption)
              .foregroundColor(.secondary)
          } else {
            Text(SliderHelpers.formatDuration(customDuration!))
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Slider(
          value: Binding(
            get: { SliderHelpers.indexForDuration(customDuration ?? settings.pauseDuration) },
            set: { customDuration = SliderHelpers.durationSteps()[Int($0)] }
          ), in: 0...Double(SliderHelpers.durationSteps().count - 1), step: 1)

        if customDuration != nil {
          Button("Reset to default") { customDuration = nil }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
      }
    }
    .padding()
    .frame(width: 280)
  }
}
