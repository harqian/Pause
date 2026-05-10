//
//  SessionTab.swift
//  Pause
//
//  everything about what happens during a break: timing, display, locking, audio

import SwiftUI
import AVFoundation
import AppKit

struct SessionTab: View {
  @ObservedObject var settings = Settings.shared
  @ObservedObject var appState = AppState.shared
  @ObservedObject var lockManager = InputLockManager.shared
  @State private var previewPlayer: AVAudioPlayer?

  var body: some View {
    Form {
      // MARK: - Timing
      Section {
        HStack {
          Text("Duration")
            .frame(width: 120, alignment: .leading)
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
          Text("Variance")
            .frame(width: 120, alignment: .leading)
          Slider(value: Binding(
            get: { SliderHelpers.indexForVariance(settings.pauseVariance) },
            set: { settings.pauseVariance = SliderHelpers.varianceSteps()[Int($0)] }
          ), in: 0...Double(SliderHelpers.varianceSteps().count - 1), step: 1)
          Text(settings.pauseVariance == 0 ? "None" : "±\(SliderHelpers.formatDuration(settings.pauseVariance))")
            .frame(width: 50, alignment: .trailing)
            .monospacedDigit()
        }

        HStack {
          Text("Snooze")
            .frame(width: 120, alignment: .leading)
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
        Text("How long each break lasts. Variance adds randomness. Snooze sets the delay when you postpone.")
          .font(.caption)
      }

      // MARK: - Display
      Section {
        HStack {
          Text("Message")
            .frame(width: 120, alignment: .leading)
          TextField("", text: $settings.sessionDisplayText)
            .textFieldStyle(.roundedBorder)
        }
      } header: {
        Text("Display")
      } footer: {
        Text("Shown during the break. Scheduled activations use their own labels instead.")
          .font(.caption)
      }

      // MARK: - Input Blocking
      Section {
        Toggle("Lock Input During Session", isOn: $settings.lockSessionEnabled)

        if settings.lockSessionEnabled {
          PermissionRow(
            label: "Accessibility",
            granted: lockManager.hasAccessibilityPermission,
            settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
          )
          PermissionRow(
            label: "Input Monitoring",
            granted: lockManager.hasInputMonitoringPermission,
            settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
          )
        }
      } header: {
        Text("Input Blocking")
      } footer: {
        if settings.lockSessionEnabled && !lockManager.hasAllPermissions() {
          Text("Both permissions required. Grant them in System Settings, then restart the app.")
            .font(.caption)
            .foregroundColor(.red)
        } else {
          Text("When locked, all keyboard and mouse input is blocked until the break ends.")
            .font(.caption)
        }
      }

      // MARK: - Ambient Audio
      Section {
        Toggle("Ambient Sound", isOn: $settings.soundEnabled)

        if settings.soundEnabled {
          HStack {
            Text("Volume")
              .frame(width: 120, alignment: .leading)
            Slider(value: $settings.soundVolume, in: 0...1, step: 0.1)
            Text("\(Int(settings.soundVolume * 100))%")
              .frame(width: 40, alignment: .trailing)
              .monospacedDigit()
          }

          HStack {
            Text("Gap Between")
              .frame(width: 120, alignment: .leading)
            Slider(value: Binding(
              get: { Double(settings.soundRepeatRate) },
              set: { settings.soundRepeatRate = Int($0) }
            ), in: 0...30, step: 1)
            Text(settings.soundRepeatRate == 0 ? "Loop" : "\(settings.soundRepeatRate)s")
              .frame(width: 40, alignment: .trailing)
              .monospacedDigit()
          }
        }
      } header: {
        Text("Ambient Audio")
      } footer: {
        if settings.soundEnabled {
          Text("Plays during the break. Set gap to 0 for continuous looping.")
            .font(.caption)
        }
      }

      // MARK: - Sound Selection
      if settings.soundEnabled {
        Section {
          ForEach(["random"] + appState.ambientSounds, id: \.self) { soundName in
            HStack {
              Image(systemName: settings.selectedAmbientSound == soundName ? "checkmark.circle.fill" : "circle")
                .foregroundColor(settings.selectedAmbientSound == soundName ? .accentColor : .secondary)
                .onTapGesture {
                  settings.selectedAmbientSound = soundName
                  stopPreview()
                }

              Text(soundName.capitalized)
                .onTapGesture {
                  settings.selectedAmbientSound = soundName
                  stopPreview()
                }

              Spacer()

              if soundName != "random" {
                Button(action: {
                  if previewPlayer?.url?.lastPathComponent.replacingOccurrences(of: ".mp3", with: "") == soundName {
                    stopPreview()
                  } else {
                    playPreview(soundName: soundName)
                  }
                }) {
                  Image(systemName: previewPlayer?.url?.lastPathComponent.replacingOccurrences(of: ".mp3", with: "") == soundName ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                }
                .buttonStyle(.plain)
              }
            }
          }
        } header: {
          Text("Sound Selection")
        }
      }

      // MARK: - Start/End Sounds
      Section {
        Toggle("Start Sound", isOn: $settings.startSoundEnabled)
        if settings.startSoundEnabled {
          HStack {
            Text("Volume")
              .frame(width: 120, alignment: .leading)
            Slider(value: $settings.startSoundVolume, in: 0...1, step: 0.1)
            Text("\(Int(settings.startSoundVolume * 100))%")
              .frame(width: 40, alignment: .trailing)
              .monospacedDigit()
          }
        }

        Toggle("End Sound", isOn: $settings.endSoundEnabled)
        if settings.endSoundEnabled {
          HStack {
            Text("Volume")
              .frame(width: 120, alignment: .leading)
            Slider(value: $settings.endSoundVolume, in: 0...1, step: 0.1)
            Text("\(Int(settings.endSoundVolume * 100))%")
              .frame(width: 40, alignment: .trailing)
              .monospacedDigit()
          }
        }
      } header: {
        Text("Cues")
      } footer: {
        Text("Short chimes that mark the beginning and end of each break.")
          .font(.caption)
      }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
  }

  private func playPreview(soundName: String) {
    stopPreview()
    guard let soundURL = Bundle.main.url(forResource: soundName, withExtension: "mp3") else { return }
    do {
      previewPlayer = try AVAudioPlayer(contentsOf: soundURL)
      previewPlayer?.volume = Float(settings.soundVolume)
      previewPlayer?.numberOfLoops = -1
      previewPlayer?.prepareToPlay()
      previewPlayer?.play()
    } catch {
      print("Error playing preview: \(error.localizedDescription)")
    }
  }

  private func stopPreview() {
    previewPlayer?.stop()
    previewPlayer = nil
  }
}

// reusable permission status row
struct PermissionRow: View {
  let label: String
  let granted: Bool
  let settingsURL: String

  var body: some View {
    HStack {
      Text(label)
        .frame(width: 160, alignment: .leading)
      Text(granted ? "Granted" : "Not Granted")
        .foregroundColor(granted ? .green : .red)
      Spacer()
      if !granted {
        Button("Open Settings") {
          if let url = URL(string: settingsURL) {
            NSWorkspace.shared.open(url)
          }
        }
      }
    }
  }
}
