//
//  ActivationSettingsTab.swift
//  Pause
//
//  Activation settings for timing-based, app-based, and scrolling-based triggers
//

import SwiftUI

struct ActivationSettingsTab: View {
  @ObservedObject var settings = Settings.shared
  @ObservedObject var detector = InputDetectionManager.shared
  @ObservedObject var scrollDetector = DoomScrollDetector.shared
  @State private var showingAppPicker = false
  @State private var customizingScheduledTimeId: UUID?
  @State private var showingRepeatedCustomize = false
  @State private var showingRandomCustomize = false
  @State private var showingDoomScrollCustomize = false
  @State private var customizingAppId: UUID?

  var body: some View {
    Form {
      // ========== SECTION 1: TIMING-BASED ==========

      // Repeated activation
      Section {
        HStack {
          Toggle("Repeated", isOn: $settings.repeatedEnabled)
            .toggleStyle(.switch)
          Spacer()
          if settings.repeatedEnabled {
            Button(action: { showingRepeatedCustomize = true }) {
              Image(systemName: settings.repeatedIsLocked != nil || settings.repeatedCustomDuration != nil || settings.repeatedMessage != nil ? "gearshape.fill" : "gearshape")
                .foregroundColor(settings.repeatedIsLocked != nil || settings.repeatedCustomDuration != nil || settings.repeatedMessage != nil ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingRepeatedCustomize) {
              ModeCustomizeView(
                title: "Repeated",
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
        Text("Repeated Activation")
      } footer: {
        if settings.repeatedEnabled {
          Text("Pause will trigger every \(settings.repeatedInterval) minutes")
            .font(.caption)
        }
      }

      // Random activation
      Section {
        HStack {
          Toggle("Random", isOn: $settings.randomEnabled)
            .toggleStyle(.switch)
          Spacer()
          if settings.randomEnabled {
            Button(action: { showingRandomCustomize = true }) {
              Image(systemName: settings.randomIsLocked != nil || settings.randomCustomDuration != nil || settings.randomMessage != nil ? "gearshape.fill" : "gearshape")
                .foregroundColor(settings.randomIsLocked != nil || settings.randomCustomDuration != nil || settings.randomMessage != nil ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingRandomCustomize) {
              ModeCustomizeView(
                title: "Random",
                message: $settings.randomMessage,
                isLocked: $settings.randomIsLocked,
                customDuration: $settings.randomCustomDuration
              )
            }
          }
        }

        if settings.randomEnabled {
          HStack {
            Text("Minimum")
              .frame(width: 80, alignment: .leading)
            Slider(
              value: Binding(
                get: { SliderHelpers.indexForActivation(settings.randomMinInterval) },
                set: {
                  let newValue = SliderHelpers.activationSteps()[Int($0)]
                  settings.randomMinInterval = newValue
                  // Ensure max is always >= min
                  if settings.randomMaxInterval < newValue {
                    settings.randomMaxInterval = newValue
                  }
                }
              ), in: 0...Double(SliderHelpers.activationSteps().count - 1), step: 1)
            Text(SliderHelpers.formatActivation(settings.randomMinInterval))
              .frame(width: 70, alignment: .trailing)
              .monospacedDigit()
          }

          HStack {
            Text("Maximum")
              .frame(width: 80, alignment: .leading)
            Slider(
              value: Binding(
                get: { SliderHelpers.indexForActivation(settings.randomMaxInterval) },
                set: {
                  let newValue = SliderHelpers.activationSteps()[Int($0)]
                  settings.randomMaxInterval = newValue
                  // Ensure min is always <= max
                  if settings.randomMinInterval > newValue {
                    settings.randomMinInterval = newValue
                  }
                }
              ), in: 0...Double(SliderHelpers.activationSteps().count - 1), step: 1)
            Text(SliderHelpers.formatActivation(settings.randomMaxInterval))
              .frame(width: 70, alignment: .trailing)
              .monospacedDigit()
          }
        }
      } header: {
        Text("Random Activation")
      } footer: {
        if settings.randomEnabled {
          Text(
            "Pause will trigger at random intervals between \(settings.randomMinInterval)-\(settings.randomMaxInterval) minutes"
          )
          .font(.caption)
        }
      }

      // Scheduled activation
      Section {
        Toggle("Scheduled", isOn: $settings.scheduledEnabled)
          .toggleStyle(.switch)

        ForEach($settings.scheduledTimes) { $scheduledTime in
          HStack(alignment: .center, spacing: 8) {
            // Enabled toggle (only for recurring, not snoozes)
            if scheduledTime.isRecurring {
              Toggle("", isOn: $scheduledTime.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 2) {
              HStack(spacing: 4) {
                DatePicker("", selection: $scheduledTime.date, displayedComponents: .hourAndMinute)
                  .labelsHidden()
                  .disabled(!scheduledTime.isEnabled)

                Text(scheduledTime.name)
                  .foregroundColor(.secondary)
                  .lineLimit(1)
              }

              // Show repeat days for recurring scheduled times
              if scheduledTime.isRecurring {
                Text(formatRepeatDays(scheduledTime.repeatDays))
                  .font(.caption2)
                  .foregroundColor(.secondary)
              }
            }

            Spacer()

            // Customize button with popover
            Button(action: {
              customizingScheduledTimeId = scheduledTime.id
            }) {
              Image(
                systemName: scheduledTime.isLocked != nil || scheduledTime.customDuration != nil
                  ? "gearshape.fill" : "gearshape"
              )
              .foregroundColor(
                scheduledTime.isLocked != nil || scheduledTime.customDuration != nil
                  ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .popover(
              isPresented: Binding(
                get: { customizingScheduledTimeId == scheduledTime.id },
                set: { if !$0 { customizingScheduledTimeId = nil } }
              )
            ) {
              ScheduledTimeCustomizeView(scheduledTime: $scheduledTime)
            }

            Button(action: {
              settings.deleteScheduledTime(id: scheduledTime.id)
            }) {
              Image(systemName: "trash")
                .foregroundColor(.red)
            }
            .buttonStyle(.plain)
          }
          .opacity(scheduledTime.isEnabled ? 1.0 : 0.6)
        }
        .onDelete { indices in
          settings.deleteScheduledTime(at: indices)
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

          Button(action: {
            settings.undo()
          }) {
            Image(systemName: "arrow.uturn.backward")
          }
          .disabled(!settings.canUndo)
          .buttonStyle(.plain)
          .help("Undo (⌘Z)")
          .keyboardShortcut("z", modifiers: .command)

          Button(action: {
            settings.redo()
          }) {
            Image(systemName: "arrow.uturn.forward")
          }
          .disabled(!settings.canRedo)
          .buttonStyle(.plain)
          .help("Redo (⌘⇧Z)")
          .keyboardShortcut("z", modifiers: [.command, .shift])
        }
      } header: {
        Text("Scheduled Activation")
      } footer: {
        if settings.scheduledEnabled {
          Text("Pause will trigger at the specified times on selected days")
            .font(.caption)
        } else {
          Text("Scheduled activation is disabled. Times below will not trigger.")
            .font(.caption)
        }
      }

      // Recalculation setting
      Section {
        Toggle("Recalculate on Activation", isOn: $settings.recalculateOnActivation)
          .toggleStyle(.switch)
      } header: {
        Text("Timer Behavior")
      } footer: {
        Text(
          "When enabled, any activation (manual, repeated, random, or scheduled) will reset and recalculate all pending timers. When disabled, timers continue on their original schedules."
        )
        .font(.caption)
      }

      // ========== SECTION 2: APP-BASED ==========

      // App Launch Activation
      Section {
        Toggle("Activate on App Launch", isOn: $settings.appLaunchEnabled)
          .toggleStyle(.switch)

        if settings.appLaunchEnabled {
          ForEach($settings.monitoredApps) { $app in
            VStack(alignment: .leading, spacing: 8) {
              // App name, customize, and remove button
              HStack {
                Text(app.name)
                  .font(.headline)

                Text(app.customMessage ?? "Focus on \(app.name)")
                  .foregroundColor(.secondary)
                  .lineLimit(1)

                Spacer()

                Button(action: { customizingAppId = app.id }) {
                  Image(systemName: app.isLocked != nil || app.customDuration != nil || app.customMessage != nil ? "gearshape.fill" : "gearshape")
                    .foregroundColor(app.isLocked != nil || app.customDuration != nil || app.customMessage != nil ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: Binding(
                  get: { customizingAppId == app.id },
                  set: { if !$0 { customizingAppId = nil } }
                )) {
                  AppCustomizeView(app: $app)
                }
                Button("Remove") {
                  settings.monitoredApps.removeAll { $0.id == app.id }
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
              }

              // Delay slider
              HStack {
                Text("Delay:")
                  .frame(width: 80, alignment: .leading)
                  .font(.caption)
                Slider(value: $app.activationDelay, in: 0...30, step: 1)
                Text("\(Int(app.activationDelay))s")
                  .frame(width: 40, alignment: .trailing)
                  .monospacedDigit()
                  .font(.caption)
              }
            }
            .padding(.vertical, 4)
          }

          Button("Add App...") {
            showingAppPicker = true
          }
        }
      } header: {
        Text("App Launch Activation")
      } footer: {
        if settings.appLaunchEnabled {
          Text(
            "Pause will activate automatically when any of the listed apps are launched. Perfect for games or distracting apps."
          )
          .font(.caption)
        } else {
          Text(
            "When enabled, you can specify apps that will trigger a pause session when launched."
          )
          .font(.caption)
        }
      }

      // ========== SECTION 3: SCROLLING-BASED ==========

      // Doom Scroll Detection
      Section {
        HStack {
          Toggle("Detect Doom Scrolling", isOn: $settings.doomScrollEnabled)
            .toggleStyle(.switch)
          Spacer()
          if settings.doomScrollEnabled {
            Button(action: { showingDoomScrollCustomize = true }) {
              Image(systemName: settings.doomScrollMessage != nil || settings.doomScrollIsLocked != nil || settings.doomScrollCustomDuration != nil ? "gearshape.fill" : "gearshape")
                .foregroundColor(settings.doomScrollMessage != nil || settings.doomScrollIsLocked != nil || settings.doomScrollCustomDuration != nil ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingDoomScrollCustomize) {
              DoomScrollCustomizeView()
            }
          }
        }

        if settings.doomScrollEnabled {
          HStack {
            Text("Input Monitoring Permission")
              .frame(width: 180, alignment: .leading)
            if detector.hasInputMonitoringPermission {
              Text("✅ Granted")
                .foregroundColor(.green)
            } else {
              Text("❌ Not Granted")
                .foregroundColor(.red)
            }

            Spacer()

            if !detector.hasInputMonitoringPermission {
              Button("Open System Settings") {
                if let url = URL(
                  string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
                {
                  NSWorkspace.shared.open(url)
                }
              }
            }
          }

        }
      } header: {
        Text("Doom Scroll Detection")
      } footer: {
        if settings.doomScrollEnabled {
          if detector.hasInputMonitoringPermission {
            Text("Doom scroll detection is active and monitoring scroll events.")
              .font(.caption)
          } else {
            Text(
              "Input Monitoring permission is required. Click the button above to open System Settings, grant permission, then restart the app."
            )
            .font(.caption)
            .foregroundColor(.red)
          }
        } else {
          Text(
            "Automatically triggers a pause session when mindless scrolling patterns are detected (e.g., Reddit, Twitter, Instagram, memes, etc.)."
          )
          .font(.caption)
        }
      }

      if settings.doomScrollEnabled {

        // Velocity threshold
        Section {
          HStack {
            Text("Velocity Threshold")
              .frame(width: 140, alignment: .leading)
            Slider(
              value: Binding(
                get: { Double(settings.doomScrollVelocityThreshold) },
                set: { settings.doomScrollVelocityThreshold = Int($0) }
              ), in: 500...7500, step: 250)
            Text("\(settings.doomScrollVelocityThreshold)/min")
              .frame(width: 70, alignment: .trailing)
              .monospacedDigit()
          }
        } footer: {
          Text(
            "Minimum number of forward scroll events per minute. One scroll action generates ~50-100 events. Current: \(settings.doomScrollVelocityThreshold) events/min."
          )
          .font(.caption)
        }

        // Directionality threshold
        Section {
          HStack {
            Text("Directionality Threshold")
              .frame(width: 140, alignment: .leading)
            Slider(value: $settings.doomScrollDirectionalityThreshold, in: 0.5...0.99, step: 0.05)
            Text("\(Int(settings.doomScrollDirectionalityThreshold * 100))%")
              .frame(width: 70, alignment: .trailing)
              .monospacedDigit()
          }
        } footer: {
          Text(
            "Minimum percentage of forward vs. backward actions. Current: \(Int(settings.doomScrollDirectionalityThreshold * 100))% forward."
          )
          .font(.caption)
        }

        // Pause threshold
        Section {
          HStack {
            Text("Pause Threshold")
              .frame(width: 140, alignment: .leading)
            Slider(value: $settings.doomScrollPauseThreshold, in: 0.5...5.0, step: 0.1)
            Text("\(String(format: "%.1f", settings.doomScrollPauseThreshold))s")
              .frame(width: 70, alignment: .trailing)
              .monospacedDigit()
          }
        } footer: {
          Text(
            "Maximum median gap between actions (in seconds). Current: \(String(format: "%.1f", settings.doomScrollPauseThreshold))s median gap."
          )
          .font(.caption)
        }

        // Window duration
        Section {
          HStack {
            Text("Detection Window")
              .frame(width: 140, alignment: .leading)
            Slider(
              value: Binding(
                get: { Double(settings.doomScrollWindowDuration) },
                set: { settings.doomScrollWindowDuration = Int($0) }
              ), in: 1...10, step: 1)
            Text("\(settings.doomScrollWindowDuration) min")
              .frame(width: 70, alignment: .trailing)
              .monospacedDigit()
          }
        } footer: {
          Text(
            "Time window to analyze scrolling behavior. Longer windows are less sensitive to brief scrolling bursts. Current: \(settings.doomScrollWindowDuration) minutes."
          )
          .font(.caption)
        }

        // Current Metrics (Live)
        Section {
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Text("Events in Window:")
                .font(.caption)
                .foregroundColor(.secondary)
              Spacer()
              Text("\(scrollDetector.eventCount)")
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
            }

            HStack {
              Text("Current Velocity:")
                .font(.caption)
                .foregroundColor(.secondary)
              Spacer()
              Text("\(String(format: "%.1f", scrollDetector.currentVelocity))/min")
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundColor(
                  scrollDetector.currentVelocity >= Double(settings.doomScrollVelocityThreshold)
                    ? .green : .primary)
              Text("(need ≥\(settings.doomScrollVelocityThreshold))")
                .font(.caption)
                .foregroundColor(.secondary)
            }

            HStack {
              Text("Current Directionality:")
                .font(.caption)
                .foregroundColor(.secondary)
              Spacer()
              Text("\(String(format: "%.0f", scrollDetector.currentDirectionality * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundColor(
                  scrollDetector.currentDirectionality >= settings.doomScrollDirectionalityThreshold
                    ? .green : .primary)
              Text("(need ≥\(Int(settings.doomScrollDirectionalityThreshold * 100))%)")
                .font(.caption)
                .foregroundColor(.secondary)
            }

            HStack {
              Text("Current Median Pause:")
                .font(.caption)
                .foregroundColor(.secondary)
              Spacer()
              Text(
                "\(scrollDetector.currentMedianPause == Double.infinity ? "∞" : String(format: "%.2f", scrollDetector.currentMedianPause))s"
              )
              .font(.caption)
              .fontWeight(.semibold)
              .monospacedDigit()
              .foregroundColor(
                scrollDetector.currentMedianPause <= settings.doomScrollPauseThreshold
                  && scrollDetector.currentMedianPause != Double.infinity ? .green : .primary)
              Text("(need ≤\(String(format: "%.1f", settings.doomScrollPauseThreshold))s)")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          .padding(.vertical, 4)
        } footer: {
          Text(
            "Values update every 1 second. Green indicates threshold met. Check Console.app for detailed logs."
          )
          .font(.caption)
        }

        // Summary
        Section {
          VStack(alignment: .leading, spacing: 8) {
            Text("Detection triggers when ALL conditions are met:")
              .font(.caption)
              .fontWeight(.semibold)
            Text("• Velocity ≥ \(settings.doomScrollVelocityThreshold) events/min")
              .font(.caption)
            Text(
              "• Directionality ≥ \(Int(settings.doomScrollDirectionalityThreshold * 100))% forward"
            )
            .font(.caption)
            Text("• Median pause ≤ \(String(format: "%.1f", settings.doomScrollPauseThreshold))s")
              .font(.caption)
          }
          .padding(.vertical, 4)
        }
      }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
    .sheet(isPresented: $showingAppPicker) {
      AppPickerView { app in
        // Check if app is already in the list
        if !settings.monitoredApps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier })
        {
          settings.monitoredApps.append(app)
        }
        showingAppPicker = false
      }
    }
  }
}

// Scheduled Time Customize Popover
struct ScheduledTimeCustomizeView: View {
  @Binding var scheduledTime: ScheduledTime
  @ObservedObject var settings = Settings.shared

  var repeatDaysLabel: String {
    formatRepeatDays(scheduledTime.repeatDays)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Customize Scheduled Time")
        .font(.headline)

      // Name/Message
      VStack(alignment: .leading, spacing: 4) {
        Text("Message")
        TextField("Message", text: $scheduledTime.name)
          .textFieldStyle(.roundedBorder)
      }

      Divider()

      // Repeat days (only for recurring scheduled times, not snoozes)
      if scheduledTime.isRecurring {
        VStack(alignment: .leading, spacing: 4) {
          Text("Repeat")
          DayPicker(selectedDays: $scheduledTime.repeatDays)
          Text(repeatDaysLabel)
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Divider()
      }

      // Lock toggle
      VStack(alignment: .leading, spacing: 4) {
        Toggle(
          isOn: Binding(
            get: { scheduledTime.isLocked ?? false },
            set: { scheduledTime.isLocked = $0 ? true : nil }
          )
        ) {
          HStack {
            Text("Lock Session")
            if scheduledTime.isLocked == nil {
              Text("(using global)")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
        .toggleStyle(.switch)

        if scheduledTime.isLocked != nil {
          Button("Reset to global") {
            scheduledTime.isLocked = nil
          }
          .font(.caption)
          .buttonStyle(.plain)
          .foregroundColor(.accentColor)
        }
      }

      Divider()

      // Duration
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Duration")
          if scheduledTime.customDuration == nil {
            Text("(using global: \(settings.pauseDuration)s)")
              .font(.caption)
              .foregroundColor(.secondary)
          } else {
            Text("\(scheduledTime.customDuration!)s")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Slider(
          value: Binding(
            get: { Double(scheduledTime.customDuration ?? settings.pauseDuration) },
            set: { scheduledTime.customDuration = Int($0) }
          ), in: 10...300, step: 5)

        if scheduledTime.customDuration != nil {
          Button("Reset to global") {
            scheduledTime.customDuration = nil
          }
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

// Mode Customize Popover (for Repeated/Random)
struct ModeCustomizeView: View {
  let title: String
  @Binding var message: String?
  @Binding var isLocked: Bool?
  @Binding var customDuration: Int?
  @ObservedObject var settings = Settings.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Customize \(title) Mode")
        .font(.headline)

      // Message
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Message")
          if message == nil {
            Text("(using global)")
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
          Button("Reset to global") { message = nil }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
      }

      Divider()

      // Lock toggle
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
              Text("(using global)")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
        .toggleStyle(.switch)

        if isLocked != nil {
          Button("Reset to global") { isLocked = nil }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
      }

      Divider()

      // Duration
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Duration")
          if customDuration == nil {
            Text("(using global: \(settings.pauseDuration)s)")
              .font(.caption)
              .foregroundColor(.secondary)
          } else {
            Text("\(customDuration!)s")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Slider(
          value: Binding(
            get: { Double(customDuration ?? settings.pauseDuration) },
            set: { customDuration = Int($0) }
          ), in: 10...300, step: 5)

        if customDuration != nil {
          Button("Reset to global") { customDuration = nil }
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

// Doom Scroll Customize Popover
struct DoomScrollCustomizeView: View {
  @ObservedObject var settings = Settings.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Customize Doom Scroll")
        .font(.headline)

      // Message
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Message")
          if settings.doomScrollMessage == nil {
            Text("(using global)")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        TextField("Message", text: Binding(
          get: { settings.doomScrollMessage ?? settings.sessionDisplayText },
          set: { settings.doomScrollMessage = $0.isEmpty ? nil : $0 }
        ))
        .textFieldStyle(.roundedBorder)
        if settings.doomScrollMessage != nil {
          Button("Reset to global") { settings.doomScrollMessage = nil }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
      }

      Divider()

      // Lock toggle
      VStack(alignment: .leading, spacing: 4) {
        Toggle(
          isOn: Binding(
            get: { settings.doomScrollIsLocked ?? false },
            set: { settings.doomScrollIsLocked = $0 ? true : nil }
          )
        ) {
          HStack {
            Text("Lock Session")
            if settings.doomScrollIsLocked == nil {
              Text("(using global)")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
        .toggleStyle(.switch)

        if settings.doomScrollIsLocked != nil {
          Button("Reset to global") { settings.doomScrollIsLocked = nil }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
      }

      Divider()

      // Duration
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Duration")
          if settings.doomScrollCustomDuration == nil {
            Text("(using global: \(settings.pauseDuration)s)")
              .font(.caption)
              .foregroundColor(.secondary)
          } else {
            Text("\(settings.doomScrollCustomDuration!)s")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Slider(
          value: Binding(
            get: { Double(settings.doomScrollCustomDuration ?? settings.pauseDuration) },
            set: { settings.doomScrollCustomDuration = Int($0) }
          ), in: 10...300, step: 5)

        if settings.doomScrollCustomDuration != nil {
          Button("Reset to global") { settings.doomScrollCustomDuration = nil }
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

// App Customize Popover
struct AppCustomizeView: View {
  @Binding var app: MonitoredApp
  @ObservedObject var settings = Settings.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Customize: \(app.name)")
        .font(.headline)

      // Message
      VStack(alignment: .leading, spacing: 4) {
        Text("Message")
        TextField("Message", text: Binding(
          get: { app.customMessage ?? "Focus on \(app.name)" },
          set: { app.customMessage = $0.isEmpty ? nil : $0 }
        ))
        .textFieldStyle(.roundedBorder)
        if app.customMessage != nil {
          Button("Reset to default") { app.customMessage = nil }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
      }

      Divider()

      // Lock toggle
      VStack(alignment: .leading, spacing: 4) {
        Toggle(
          isOn: Binding(
            get: { app.isLocked ?? false },
            set: { app.isLocked = $0 ? true : nil }
          )
        ) {
          HStack {
            Text("Lock Session")
            if app.isLocked == nil {
              Text("(using global)")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
        .toggleStyle(.switch)

        if app.isLocked != nil {
          Button("Reset to global") { app.isLocked = nil }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
      }

      Divider()

      // Duration
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Duration")
          if app.customDuration == nil {
            Text("(using global: \(settings.pauseDuration)s)")
              .font(.caption)
              .foregroundColor(.secondary)
          } else {
            Text("\(app.customDuration!)s")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Slider(
          value: Binding(
            get: { Double(app.customDuration ?? settings.pauseDuration) },
            set: { app.customDuration = Int($0) }
          ), in: 10...300, step: 5)

        if app.customDuration != nil {
          Button("Reset to global") { app.customDuration = nil }
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

// App Picker Sheet
struct AppPickerView: View {
  let onSelect: (MonitoredApp) -> Void
  @Environment(\.dismiss) var dismiss

  var body: some View {
    VStack(spacing: 16) {
      Text("Select an Application")
        .font(.headline)

      Text("Choose an app from your Applications folder")
        .font(.caption)
        .foregroundColor(.secondary)

      Button("Choose from /Applications...") {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]

        if panel.runModal() == .OK, let url = panel.url {
          if let bundle = Bundle(url: url),
            let bundleIdentifier = bundle.bundleIdentifier,
            let appName = bundle.infoDictionary?["CFBundleName"] as? String
          {
            let app = MonitoredApp(
              bundleIdentifier: bundleIdentifier,
              name: appName,
              iconPath: url.path
            )
            onSelect(app)
          }
        }
      }
      .buttonStyle(.borderedProminent)

      Button("Cancel") {
        dismiss()
      }
      .buttonStyle(.bordered)
    }
    .padding(40)
    .frame(width: 400, height: 200)
  }
}

