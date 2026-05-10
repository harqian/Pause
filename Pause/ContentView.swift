//
//  ContentView.swift
//  Pause
//
//  Created by Harrison Qian on 10/22/25.
//

import SwiftUI
import AppKit

struct ContentView: View {
  @ObservedObject var appState = AppState.shared
  @ObservedObject var settings = Settings.shared

  var body: some View {
    ZStack {
      if appState.isPauseMode {
        BreathingView()
      } else {
        SettingsView()
      }
    }
  }
}

struct SettingsView: View {
  @ObservedObject var settings = Settings.shared

  // sage green accent from BreathingView palette
  private let accentGreen = Color(red: 151/255, green: 187/255, blue: 101/255)

  var body: some View {
    VStack(spacing: 0) {
      // header
      HStack(alignment: .center, spacing: 40) {
        // stats
        VStack(alignment: .leading, spacing: 4) {
          Text("Sessions: \(settings.completedSessions)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("Time: \(SliderHelpers.formatSessionTime(settings.completedSessionTime))")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(minWidth: 120)

        // title
        VStack(spacing: 8) {
          Text("Pause")
            .font(.system(size: 32, weight: .light))
          Text("Press \(settings.getActivateHotkeyString()) to start")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        // next activation
        NextActivationCountdown()
          .frame(minWidth: 120)
      }
      .padding(.top, 30)
      .padding(.bottom, 20)

      Divider()

      // 4-tab navigation
      HStack(spacing: 20) {
        TabButton(icon: "lungs", label: "Session", tag: 0, selectedTab: $settings.selectedTab)
        TabButton(icon: "clock", label: "Schedule", tag: 1, selectedTab: $settings.selectedTab)
        TabButton(icon: "shield", label: "Protection", tag: 2, selectedTab: $settings.selectedTab)
        TabButton(icon: "gearshape", label: "Preferences", tag: 3, selectedTab: $settings.selectedTab)
      }
      .padding(.vertical, 16)

      Divider()

      // content
      Group {
        switch settings.selectedTab {
        case 0:
          SessionTab()
        case 1:
          ScheduleTab()
        case 2:
          ProtectionTab()
        case 3:
          PreferencesTab()
        default:
          SessionTab()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(minWidth: 700, maxWidth: 700, minHeight: 550, maxHeight: 550)
    .textSelection(.enabled)
  }
}

#Preview {
  ContentView()
}
