import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  static weak var appModel: AppModel?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)

    Task { @MainActor in
      AppDelegate.appModel?.startRuntimeIfNeeded()
    }
  }
}

@main
struct MilyonusApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var appModel: AppModel

  init() {
    let model = AppModel()
    _appModel = StateObject(wrappedValue: model)
    AppDelegate.appModel = model
  }

  var body: some Scene {
    MenuBarExtra("Milyonus", systemImage: appModel.menuBarSystemImage) {
      MenuBarContentView()
        .environmentObject(appModel)
        .onOpenURL { url in
          Task { @MainActor in
            await appModel.handleAuthCallback(url)
          }
        }
    }
    .menuBarExtraStyle(.menu)

    Settings {
      SettingsView()
        .environmentObject(appModel)
        .frame(minWidth: 520, minHeight: 520)
        .onOpenURL { url in
          Task { @MainActor in
            await appModel.handleAuthCallback(url)
          }
        }
    }
  }
}
