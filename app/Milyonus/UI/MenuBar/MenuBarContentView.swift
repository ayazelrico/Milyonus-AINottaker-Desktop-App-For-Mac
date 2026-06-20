import SwiftUI
import AppKit

struct MenuBarContentView: View {
  @EnvironmentObject private var appModel: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Milyonus")
        .font(.headline)

      Text(appModel.statusMessage)
        .font(.caption)
        .foregroundStyle(.secondary)

      Divider()

      if appModel.isSessionActive {
        Button("End Session") {
          Task { await appModel.endSession() }
        }
      } else {
        Button("Start Session") {
          Task { await appModel.startSession() }
        }
      }

      Button(appModel.panelController.isVisible ? "Hide Panel" : "Show Panel") {
        appModel.togglePanel()
      }

      Button("Check Meeting App") {
        appModel.checkForMeetingApp()
      }

      Divider()

      Button("Settings...") {
        appModel.openSettings()
      }

      Button("Sign Out") {
        Task { await appModel.signOut() }
      }

      Button("Quit Milyonus") {
        NSApp.terminate(nil)
      }
    }
    .padding(.vertical, 6)
  }
}

