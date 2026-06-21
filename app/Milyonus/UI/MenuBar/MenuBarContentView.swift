import SwiftUI
import AppKit

struct MenuBarContentView: View {
  @EnvironmentObject private var appModel: AppModel

  var body: some View {
    Text("Milyonus")
      .font(.headline)

    Text(appModel.statusMessage)
      .font(.caption)
      .foregroundStyle(.secondary)

    Divider()

    if appModel.isSessionActive {
      Button("End Session") {
        logTap("End Session")
        Task { @MainActor in
          await appModel.endSession()
        }
      }
    } else {
      Button("Start Session") {
        logTap("Start Session")
        Task { @MainActor in
          await appModel.startSession()
        }
      }
    }

    Button(appModel.panelController.isVisible ? "Hide Panel" : "Show Panel") {
      logTap(appModel.panelController.isVisible ? "Hide Panel" : "Show Panel")
      appModel.togglePanel()
    }

    Button("Check Meeting App") {
      logTap("Check Meeting App")
      appModel.checkForMeetingApp()
    }

    Divider()

    if #available(macOS 14.0, *) {
      SettingsLink {
        Text("Settings...")
      }
    } else {
      Button("Settings...") {
        logTap("Settings")
        appModel.openSettings()
      }
    }

    Button("Sign Out") {
      logTap("Sign Out")
      Task { @MainActor in
        await appModel.signOut()
      }
    }

    Button("Quit Milyonus") {
      logTap("Quit Milyonus")
      NSApplication.shared.terminate(nil)
    }
  }

  private func logTap(_ item: String) {
    #if DEBUG
      print("[MenuBar] \(item) tapped")
    #endif
  }
}
