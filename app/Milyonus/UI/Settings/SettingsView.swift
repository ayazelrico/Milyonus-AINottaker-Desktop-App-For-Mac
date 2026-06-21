import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var appModel: AppModel

  var body: some View {
    TabView {
      VStack(alignment: .leading, spacing: 18) {
        HStack(spacing: 14) {
          MilyonusLogoView(size: 64)

          VStack(alignment: .leading, spacing: 4) {
            Text("Milyonus")
              .font(.title2.bold())

            Text("Canlı toplantı asistanı")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }

        Divider()

        LoginView(authService: appModel.authService) {
          Task { await appModel.signInWithGoogle() }
        }

        Divider()

        Picker("Transkripsiyon dili", selection: $appModel.languagePreference) {
          ForEach(LanguagePreference.allCases) { language in
            Text(language.title).tag(language)
          }
        }
        .pickerStyle(.segmented)

        Divider()

        Text("Gizlilik & Görünürlük")
          .font(.headline)

        Text(visibilityDisclosure)
          .font(.callout)
          .foregroundStyle(.secondary)

        Spacer()
      }
      .padding(24)
      .tabItem {
        Label("Genel", systemImage: "gearshape")
      }

      PermissionsOnboardingView(permissionsManager: appModel.permissionsManager)
        .tabItem {
          Label("İzinler", systemImage: "hand.raised")
        }

      VStack(alignment: .leading, spacing: 12) {
        Text("Audio Debug")
          .font(.headline)

        if let error = appModel.audioCapture.captureError {
          Text(error)
            .foregroundStyle(.red)
        }

        Button("Test Backend Connection") {
          Task { await appModel.testBackendConnection() }
        }

        if let backendConnectionStatus = appModel.backendConnectionStatus {
          Text(backendConnectionStatus)
            .font(.caption)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }

        List(appModel.audioCapture.debugMessages, id: \.self) { message in
          Text(message)
            .font(.system(.caption, design: .monospaced))
        }
      }
      .padding(24)
      .tabItem {
        Label("Debug", systemImage: "waveform")
      }
    }
  }
}
