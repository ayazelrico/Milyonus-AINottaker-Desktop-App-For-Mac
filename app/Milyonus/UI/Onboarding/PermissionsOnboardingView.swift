import SwiftUI

struct PermissionsOnboardingView: View {
  @ObservedObject var permissionsManager: PermissionsManager

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("İzinler")
        .font(.title2.bold())

      Text("Milyonus toplantı sesini anlamak için ekran kaydı iznine, senin sesini ayırabilmek için mikrofon iznine ihtiyaç duyar.")
        .foregroundStyle(.secondary)

      permissionRow(
        title: "Screen Recording",
        detail: "Milyonus, toplantı sesini anlayabilmek için ekran kaydı iznine ihtiyaç duyar. Görüntü kaydedilmez, sadece ses işlenir.",
        granted: permissionsManager.screenRecordingGranted,
        requestTitle: "İzin Ver",
        settingsTitle: "Ayarları Aç",
        request: permissionsManager.requestScreenRecording,
        openSettings: permissionsManager.openScreenRecordingSettings
      )

      permissionRow(
        title: "Microphone",
        detail: "Milyonus, senin sesini karşı taraftan ayırabilmek için mikrofon iznine ihtiyaç duyar.",
        granted: permissionsManager.microphoneGranted,
        requestTitle: "İzin Ver",
        settingsTitle: "Ayarları Aç",
        request: {
          Task { await permissionsManager.requestMicrophone() }
        },
        openSettings: permissionsManager.openMicrophoneSettings
      )

      Text(visibilityDisclosure)
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.top, 8)

      Button("Durumu Yenile") {
        permissionsManager.refresh()
      }
    }
    .padding(24)
    .onAppear {
      permissionsManager.refresh()
    }
  }

  private func permissionRow(
    title: String,
    detail: String,
    granted: Bool,
    requestTitle: String,
    settingsTitle: String,
    request: @escaping () -> Void,
    openSettings: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
          .foregroundStyle(granted ? .green : .orange)

        Text(title)
          .font(.headline)
      }

      Text(detail)
        .font(.callout)
        .foregroundStyle(.secondary)

      HStack {
        Button(requestTitle, action: request)
        Button(settingsTitle, action: openSettings)
      }
    }
  }
}

let visibilityDisclosure = """
Milyonus paneli varsayılan olarak sadece sende görünür şekilde tasarlandı.

Ancak şunu bilmen önemli: macOS'un yeni sürümlerinde (15 ve üzeri), bazı ekran paylaşımı araçları tüm ekranı olduğu gibi yakalayabiliyor — bu durumda panel paylaşım yapan kişiye de yansıyabilir.

Bunu tamamen senin kontrolünde tutmak için:
• Cmd+\\ kısayoluyla paneli istediğin an anında gizleyebilir, tekrar gösterebilirsin.
• Ekran paylaşımı başlatmadan önce bu kısayolu kullanmanı öneririz.

Katılımcı listesinde Milyonus hiçbir zaman görünmez — çünkü toplantıya bot olarak katılmıyor, sadece senin cihazında çalışıyor.
"""

