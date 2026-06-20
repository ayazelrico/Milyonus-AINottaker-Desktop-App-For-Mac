import Foundation
import AppKit
import AVFoundation
import Combine
import CoreGraphics

@MainActor
final class PermissionsManager: ObservableObject {
  @Published private(set) var screenRecordingGranted = false
  @Published private(set) var microphoneGranted = false

  var hasAllRequiredPermissions: Bool {
    screenRecordingGranted && microphoneGranted
  }

  func refresh() {
    screenRecordingGranted = CGPreflightScreenCaptureAccess()
    microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
  }

  func requestScreenRecording() {
    _ = CGRequestScreenCaptureAccess()
    refresh()
  }

  func requestMicrophone() async {
    let granted = await AVCaptureDevice.requestAccess(for: .audio)
    microphoneGranted = granted
  }

  func openScreenRecordingSettings() {
    openSettings(path: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
  }

  func openMicrophoneSettings() {
    openSettings(path: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
  }

  private func openSettings(path: String) {
    guard let url = URL(string: path) else { return }
    NSWorkspace.shared.open(url)
  }
}
