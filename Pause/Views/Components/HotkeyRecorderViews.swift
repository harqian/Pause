//
//  HotkeyRecorderViews.swift
//  Pause
//
//  hotkey recording views extracted from ShortcutsSettingsTab

import SwiftUI
import Carbon.HIToolbox

// MARK: - Activate Hotkey

struct HotkeyRecorderView: View {
  @ObservedObject var settings = Settings.shared
  @State private var isRecording = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Activate Session:")
          .frame(width: 140, alignment: .leading)
        Text(settings.getActivateHotkeyString())
          .font(.system(.body, design: .monospaced))
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color.secondary.opacity(0.2))
          .cornerRadius(6)

        Spacer()

        Button(action: { isRecording = true }) {
          HStack {
            Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
              .foregroundColor(isRecording ? .red : .primary)
            Text(isRecording ? "Press your key combination..." : "Record New Hotkey")
          }
        }
        .buttonStyle(.bordered)
      }
    }
    .textSelection(.enabled)
    .background(
      KeyEventHandlingView(isRecording: $isRecording) { keyCode, modifiers in
        if isRecording {
          settings.activateHotkeyKeyCode = keyCode
          settings.activateHotkeyModifiers = modifiers
          isRecording = false
        }
      }
    )
  }
}

struct KeyEventHandlingView: NSViewRepresentable {
  @Binding var isRecording: Bool
  var onKeyPressed: (UInt32, UInt32) -> Void

  func makeNSView(context: Context) -> NSView {
    let view = KeyCaptureView()
    view.onKeyPressed = onKeyPressed
    view.isRecordingBinding = $isRecording
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    if let keyView = nsView as? KeyCaptureView {
      keyView.isRecordingBinding = $isRecording
      if isRecording {
        DispatchQueue.main.async {
          keyView.window?.makeFirstResponder(keyView)
        }
      }
    }
  }
}

class KeyCaptureView: NSView {
  var onKeyPressed: ((UInt32, UInt32) -> Void)?
  var isRecordingBinding: Binding<Bool>?

  override var acceptsFirstResponder: Bool { true }

  override func keyDown(with event: NSEvent) {
    guard isRecordingBinding?.wrappedValue == true else {
      super.keyDown(with: event)
      return
    }

    var carbonModifiers: UInt32 = 0
    if event.modifierFlags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
    if event.modifierFlags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
    if event.modifierFlags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
    if event.modifierFlags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }

    // require at least one modifier for global hotkey
    if carbonModifiers != 0 {
      onKeyPressed?(UInt32(event.keyCode), carbonModifiers)
    }
  }
}

// MARK: - Exit Hotkey

struct ExitHotkeyRecorderView: View {
  @ObservedObject var settings = Settings.shared
  @State private var isRecording = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Exit Session:")
          .frame(width: 140, alignment: .leading)
        Text(settings.getExitHotkeyString())
          .font(.system(.body, design: .monospaced))
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color.secondary.opacity(0.2))
          .cornerRadius(6)

        Spacer()

        Button(action: { isRecording = true }) {
          HStack {
            Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
              .foregroundColor(isRecording ? .red : .primary)
            Text(isRecording ? "Press your key..." : "Record New Hotkey")
          }
        }
        .buttonStyle(.bordered)
      }
    }
    .textSelection(.enabled)
    .background(
      ExitKeyEventHandlingView(isRecording: $isRecording) { keyCode, modifiers in
        if isRecording {
          settings.exitHotkeyKeyCode = keyCode
          settings.exitHotkeyModifiers = modifiers
          isRecording = false
        }
      }
    )
  }
}

struct ExitKeyEventHandlingView: NSViewRepresentable {
  @Binding var isRecording: Bool
  var onKeyPressed: (UInt32, UInt32) -> Void

  func makeNSView(context: Context) -> NSView {
    let view = ExitKeyCaptureView()
    view.onKeyPressed = onKeyPressed
    view.isRecordingBinding = $isRecording
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    if let keyView = nsView as? ExitKeyCaptureView {
      keyView.isRecordingBinding = $isRecording
      if isRecording {
        DispatchQueue.main.async {
          keyView.window?.makeFirstResponder(keyView)
        }
      }
    }
  }
}

class ExitKeyCaptureView: NSView {
  var onKeyPressed: ((UInt32, UInt32) -> Void)?
  var isRecordingBinding: Binding<Bool>?

  override var acceptsFirstResponder: Bool { true }

  override func keyDown(with event: NSEvent) {
    guard isRecordingBinding?.wrappedValue == true else {
      super.keyDown(with: event)
      return
    }

    var carbonModifiers: UInt32 = 0
    if event.modifierFlags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
    if event.modifierFlags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
    if event.modifierFlags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
    if event.modifierFlags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }

    onKeyPressed?(UInt32(event.keyCode), carbonModifiers)
  }
}

// MARK: - Snooze Hotkey

struct SnoozeHotkeyRecorderView: View {
  @ObservedObject var settings = Settings.shared
  @State private var isRecording = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Snooze Session:")
          .frame(width: 140, alignment: .leading)
        Text(settings.getSnoozeHotkeyString())
          .font(.system(.body, design: .monospaced))
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color.secondary.opacity(0.2))
          .cornerRadius(6)

        Spacer()

        Button(action: { isRecording = true }) {
          HStack {
            Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
              .foregroundColor(isRecording ? .red : .primary)
            Text(isRecording ? "Press your key..." : "Record New Hotkey")
          }
        }
        .buttonStyle(.bordered)
      }
    }
    .textSelection(.enabled)
    .background(
      SnoozeKeyEventHandlingView(isRecording: $isRecording) { keyCode, modifiers in
        if isRecording {
          settings.snoozeHotkeyKeyCode = keyCode
          settings.snoozeHotkeyModifiers = modifiers
          isRecording = false
        }
      }
    )
  }
}

struct SnoozeKeyEventHandlingView: NSViewRepresentable {
  @Binding var isRecording: Bool
  var onKeyPressed: (UInt32, UInt32) -> Void

  func makeNSView(context: Context) -> NSView {
    let view = SnoozeKeyCaptureView()
    view.onKeyPressed = onKeyPressed
    view.isRecordingBinding = $isRecording
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    if let keyView = nsView as? SnoozeKeyCaptureView {
      keyView.isRecordingBinding = $isRecording
      if isRecording {
        DispatchQueue.main.async {
          keyView.window?.makeFirstResponder(keyView)
        }
      }
    }
  }
}

class SnoozeKeyCaptureView: NSView {
  var onKeyPressed: ((UInt32, UInt32) -> Void)?
  var isRecordingBinding: Binding<Bool>?

  override var acceptsFirstResponder: Bool { true }

  override func keyDown(with event: NSEvent) {
    guard isRecordingBinding?.wrappedValue == true else {
      super.keyDown(with: event)
      return
    }

    var carbonModifiers: UInt32 = 0
    if event.modifierFlags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
    if event.modifierFlags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
    if event.modifierFlags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
    if event.modifierFlags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }

    onKeyPressed?(UInt32(event.keyCode), carbonModifiers)
  }
}
