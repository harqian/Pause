//
//  PreferencesTab.swift
//  Pause
//
//  general settings, shortcuts, feedback, and app visibility

import SwiftUI
import AppKit
import Carbon.HIToolbox

struct PreferencesTab: View {
  @ObservedObject var settings = Settings.shared
  @State private var showingResetAlert = false
  @State private var showCopiedAlert = false

  var body: some View {
    Form {
      // MARK: - General
      Section {
        Toggle("Launch at Login", isOn: $settings.launchAtLogin)
        Toggle("Show in Menu Bar", isOn: $settings.showInMenuBar)
        if settings.showInMenuBar {
          Toggle("Timer Instead of Icon", isOn: $settings.menuBarShowTimer)
        }
        Toggle("Hide from Dock & Cmd+Tab", isOn: $settings.hideFromDock)
      } header: {
        Text("General")
      } footer: {
        if settings.hideFromDock {
          Text("The app won't appear in the Dock or Cmd+Tab switcher. Use the menu bar or hotkey to access it.")
            .font(.caption)
        }
      }

      // MARK: - Shortcuts
      Section {
        HotkeyRecorderView()
      } header: {
        Text("Global Shortcuts")
      } footer: {
        Text("Works even when the app is in the background. Requires at least one modifier key.")
          .font(.caption)
      }

      Section {
        ExitHotkeyRecorderView()
        SnoozeHotkeyRecorderView()
      } header: {
        Text("Session Shortcuts")
      } footer: {
        Text("Only active during a break. Any key works, with or without modifiers.")
          .font(.caption)
      }

      // MARK: - Feedback
      Section {
        feedbackButton(
          icon: "ladybug",
          color: .red,
          title: "GitHub Issues",
          subtitle: "Report bugs or request features",
          action: {
            if let url = URL(string: "https://github.com/Moonflower2022/Pause/issues") {
              NSWorkspace.shared.open(url)
            }
          }
        )

        feedbackButton(
          icon: "envelope",
          color: .green,
          title: "Email Feedback",
          subtitle: "Send feedback via email",
          action: {
            let subject = "Pause App Feedback"
            let body = "\n\n---\nSystem Info:\n\(getSystemInfo())"
            let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "mailto:harrisonq125@gmail.com?subject=\(encodedSubject)&body=\(encodedBody)") {
              NSWorkspace.shared.open(url)
            }
          }
        )

        feedbackButton(
          icon: "doc.text",
          color: .green,
          title: "Google Form",
          subtitle: "Fill out a quick feedback form",
          action: {
            if let url = URL(string: "https://docs.google.com/forms/d/e/1FAIpQLScW_Iycy4GWWOVnxGP5z7qnB-CbKSJ4cFZe5V5G9G6Xf0rmuw/viewform?usp=publish-editor") {
              NSWorkspace.shared.open(url)
            }
          }
        )
      } header: {
        Text("Feedback")
      }

      // MARK: - Debug & Reset
      Section {
        Button(action: {
          let pasteboard = NSPasteboard.general
          pasteboard.clearContents()
          pasteboard.setString(getSystemInfo(), forType: .string)
          showCopiedAlert = true
          DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedAlert = false
          }
        }) {
          HStack {
            Image(systemName: "doc.on.clipboard")
              .foregroundColor(.purple)
              .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
              Text("Copy System Info")
              if showCopiedAlert {
                Text("Copied!")
                  .font(.caption)
                  .foregroundColor(.green)
              } else {
                Text("For bug reports")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
            Spacer()
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)

        Button("Reset All Settings") {
          showingResetAlert = true
        }
        .foregroundColor(.red)
      } header: {
        Text("Advanced")
      } footer: {
        Text("Reset restores defaults but keeps your session statistics.")
          .font(.caption)
      }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
    .onAppear {
      settings.syncLaunchAtLoginStatus()
    }
    .alert("Reset All Settings?", isPresented: $showingResetAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Reset", role: .destructive) {
        settings.resetAllSettings()
      }
    } message: {
      Text("This will reset all settings to defaults. Session statistics will be preserved.")
    }
  }

  @ViewBuilder
  private func feedbackButton(icon: String, color: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack {
        Image(systemName: icon)
          .foregroundColor(color)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
          Text(subtitle)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        Spacer()
        Image(systemName: "arrow.up.right")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .padding(.vertical, 2)
  }

  private func getSystemInfo() -> String {
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    let osVersion = ProcessInfo.processInfo.operatingSystemVersion
    return "App Version: \(appVersion) (Build \(buildNumber))\nmacOS Version: \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
  }
}
