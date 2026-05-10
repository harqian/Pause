//
//  AppPickerView.swift
//  Pause
//
//  app picker sheet for selecting monitored apps

import SwiftUI
import AppKit

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
