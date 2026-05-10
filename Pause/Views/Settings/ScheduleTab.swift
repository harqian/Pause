//
//  ScheduleTab.swift
//  Pause
//
//  everything about when breaks happen: repeated, scheduled, app launch

import SwiftUI

struct ScheduleTab: View {
  @ObservedObject var settings = Settings.shared
  @State private var showingRepeatedCustomize = false
  @State private var customizingScheduledTimeId: UUID?
  @State private var customizingAppId: UUID?
  @State private var showingAppPicker = false

  var body: some View {
    Form {
      // MARK: - Repeated
      Section {
        HStack {
          Toggle("Repeated", isOn: $settings.repeatedEnabled)
            .toggleStyle(.switch)
          Spacer()
          if settings.repeatedEnabled {
            customizeButton(
              hasOverrides: settings.repeatedIsLocked != nil || settings.repeatedCustomDuration != nil || settings.repeatedMessage != nil,
              action: { showingRepeatedCustomize = true }
            )
            .popover(isPresented: $showingRepeatedCustomize) {
              ActivationCustomizeView(
                title: "Repeated Activation",
                message: $settings.repeatedMessage,
                isLocked: $settings.repeatedIsLocked,
                customDuration: $settings.repeatedCustomDuration
              )
            }
          }
        }

        if settings.repeatedEnabled {
          HStack {
            Text("Every")
              .frame(width: 80, alignment: .leading)
            Slider(
              value: Binding(
                get: { SliderHelpers.indexForActivation(settings.repeatedInterval) },
                set: { settings.repeatedInterval = SliderHelpers.activationSteps()[Int($0)] }
              ), in: 0...Double(SliderHelpers.activationSteps().count - 1), step: 1)
            EditableTimeField(
              seconds: $settings.repeatedInterval,
              formatter: SliderHelpers.formatActivation,
              parser: SliderHelpers.parseActivationInterval,
              width: 70
            )
          }
        }
      } header: {
        Text("Repeated")
      } footer: {
        if settings.repeatedEnabled {
          Text("Triggers every \(SliderHelpers.formatActivation(settings.repeatedInterval)). All timers reset after each break.")
            .font(.caption)
        } else {
          Text("Trigger breaks at a fixed interval.")
            .font(.caption)
        }
      }

      // MARK: - Scheduled
      Section {
        Toggle("Scheduled", isOn: $settings.scheduledEnabled)
          .toggleStyle(.switch)

        // recurring scheduled times
        let recurringTimes = settings.scheduledTimes.filter { $0.isRecurring }
        if !recurringTimes.isEmpty {
          ForEach($settings.scheduledTimes) { $scheduledTime in
            if scheduledTime.isRecurring {
              scheduledTimeRow(scheduledTime: $scheduledTime)
            }
          }
        }

        // snooze-created one-time activations (separated)
        let snoozeTimes = settings.scheduledTimes.filter { !$0.isRecurring }
        if !snoozeTimes.isEmpty {
          HStack {
            Text("Snoozed")
              .font(.caption)
              .foregroundColor(.secondary)
              .textCase(.uppercase)
            Spacer()
          }
          .listRowSeparator(.hidden)

          ForEach($settings.scheduledTimes) { $scheduledTime in
            if !scheduledTime.isRecurring {
              scheduledTimeRow(scheduledTime: $scheduledTime)
            }
          }
        }

        HStack {
          Button("Add Time") {
            settings.scheduledTimes.append(ScheduledTime(date: Date()))
          }

          Spacer()

          Button("Clear All") {
            settings.clearAllScheduledTimes()
          }
          .disabled(settings.scheduledTimes.isEmpty)

          Button(action: { settings.undo() }) {
            Image(systemName: "arrow.uturn.backward")
          }
          .disabled(!settings.canUndo)
          .buttonStyle(.plain)
          .help("Undo")
          .keyboardShortcut("z", modifiers: .command)

          Button(action: { settings.redo() }) {
            Image(systemName: "arrow.uturn.forward")
          }
          .disabled(!settings.canRedo)
          .buttonStyle(.plain)
          .help("Redo")
          .keyboardShortcut("z", modifiers: [.command, .shift])
        }
      } header: {
        Text("Scheduled")
      } footer: {
        Text("Set specific times for breaks. One-shot times disable after firing. Select days for repeating.")
          .font(.caption)
      }

      // MARK: - App Launch
      Section {
        Toggle("On App Launch", isOn: $settings.appLaunchEnabled)
          .toggleStyle(.switch)

        if settings.appLaunchEnabled {
          ForEach($settings.monitoredApps) { $app in
            VStack(alignment: .leading, spacing: 6) {
              HStack {
                Text(app.name)
                  .font(.headline)

                Text(app.customMessage ?? "")
                  .foregroundColor(.secondary)
                  .lineLimit(1)

                Spacer()

                customizeButton(
                  hasOverrides: app.isLocked != nil || app.customDuration != nil || app.customMessage != nil,
                  action: { customizingAppId = app.id }
                )
                .popover(isPresented: Binding(
                  get: { customizingAppId == app.id },
                  set: { if !$0 { customizingAppId = nil } }
                )) {
                  ActivationCustomizeView(
                    title: app.name,
                    message: $app.customMessage,
                    isLocked: $app.isLocked,
                    customDuration: $app.customDuration
                  )
                }

                Button(action: {
                  settings.monitoredApps.removeAll { $0.id == app.id }
                }) {
                  Image(systemName: "trash")
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)
              }

              HStack {
                Text("Delay")
                  .frame(width: 60, alignment: .leading)
                  .font(.caption)
                Slider(value: $app.activationDelay, in: 0...30, step: 1)
                Text("\(Int(app.activationDelay))s")
                  .frame(width: 30, alignment: .trailing)
                  .monospacedDigit()
                  .font(.caption)
              }
            }
            .padding(.vertical, 2)
          }

          Button("Add App...") {
            showingAppPicker = true
          }
        }
      } header: {
        Text("App Launch")
      } footer: {
        Text("Trigger a break when specific apps are opened. Great for games or social media.")
          .font(.caption)
      }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
    .sheet(isPresented: $showingAppPicker) {
      AppPickerView { app in
        if !settings.monitoredApps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
          settings.monitoredApps.append(app)
        }
        showingAppPicker = false
      }
    }
  }

  // MARK: - Subviews

  @ViewBuilder
  private func scheduledTimeRow(scheduledTime: Binding<ScheduledTime>) -> some View {
    HStack(alignment: .center, spacing: 8) {
      if scheduledTime.wrappedValue.isRecurring {
        Toggle("", isOn: scheduledTime.isEnabled)
          .labelsHidden()
          .toggleStyle(.switch)
          .controlSize(.small)
      }

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 4) {
          DatePicker("", selection: scheduledTime.date, displayedComponents: .hourAndMinute)
            .labelsHidden()
            .disabled(!scheduledTime.wrappedValue.isEnabled)

          Text(scheduledTime.wrappedValue.name)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }

        if scheduledTime.wrappedValue.isRecurring {
          Text(formatRepeatDays(scheduledTime.wrappedValue.repeatDays))
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }

      Spacer()

      customizeButton(
        hasOverrides: scheduledTime.wrappedValue.isLocked != nil || scheduledTime.wrappedValue.customDuration != nil,
        action: { customizingScheduledTimeId = scheduledTime.wrappedValue.id }
      )
      .popover(
        isPresented: Binding(
          get: { customizingScheduledTimeId == scheduledTime.wrappedValue.id },
          set: { if !$0 { customizingScheduledTimeId = nil } }
        )
      ) {
        ActivationCustomizeView(
          title: scheduledTime.wrappedValue.isRecurring ? "Scheduled Time" : "Snoozed Activation",
          message: Binding(
            get: { scheduledTime.wrappedValue.name == "Just Breathe" ? nil : scheduledTime.wrappedValue.name },
            set: { scheduledTime.wrappedValue.name = $0 ?? "Just Breathe" }
          ),
          isLocked: scheduledTime.isLocked,
          customDuration: scheduledTime.customDuration,
          showRepeatDays: scheduledTime.wrappedValue.isRecurring ? scheduledTime.repeatDays : nil,
          repeatDaysLabel: scheduledTime.wrappedValue.isRecurring ? formatRepeatDays(scheduledTime.wrappedValue.repeatDays) : nil
        )
      }

      Button(action: {
        settings.deleteScheduledTime(id: scheduledTime.wrappedValue.id)
      }) {
        Image(systemName: "trash")
          .foregroundColor(.red)
      }
      .buttonStyle(.plain)
    }
    .opacity(scheduledTime.wrappedValue.isEnabled ? 1.0 : 0.6)
  }
}

// reusable gear button that shows filled when overrides are set
private func customizeButton(hasOverrides: Bool, action: @escaping () -> Void) -> some View {
  Button(action: action) {
    Image(systemName: hasOverrides ? "gearshape.fill" : "gearshape")
      .foregroundColor(hasOverrides ? .accentColor : .secondary)
  }
  .buttonStyle(.plain)
}
