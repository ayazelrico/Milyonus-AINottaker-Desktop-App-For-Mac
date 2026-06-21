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
    logStatus()
  }

  @discardableResult
  func requestScreenRecording() -> Bool {
    log("Requesting Screen Recording access")
    screenRecordingGranted = CGRequestScreenCaptureAccess() || CGPreflightScreenCaptureAccess()
    refresh()
    return screenRecordingGranted
  }

  @discardableResult
  func requestMicrophone() async -> Bool {
    let status = AVCaptureDevice.authorizationStatus(for: .audio)
    log("Microphone status before request: \(describeMicrophoneStatus(status))")

    switch status {
    case .authorized:
      microphoneGranted = true
    case .notDetermined:
      microphoneGranted = await AVCaptureDevice.requestAccess(for: .audio)
    case .denied, .restricted:
      microphoneGranted = false
    @unknown default:
      microphoneGranted = false
    }

    logStatus()
    return microphoneGranted
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

  private func logStatus() {
    log("Screen Recording status: \(screenRecordingGranted ? "granted" : "missing")")
    log("Microphone status: \(describeMicrophoneStatus(AVCaptureDevice.authorizationStatus(for: .audio)))")
  }

  private func describeMicrophoneStatus(_ status: AVAuthorizationStatus) -> String {
    switch status {
    case .notDetermined:
      return "notDetermined"
    case .restricted:
      return "restricted"
    case .denied:
      return "denied"
    case .authorized:
      return "authorized"
    @unknown default:
      return "unknown"
    }
  }

  private func log(_ message: String) {
    #if DEBUG
      print("[Permissions] \(message)")
    #endif
  }
}
