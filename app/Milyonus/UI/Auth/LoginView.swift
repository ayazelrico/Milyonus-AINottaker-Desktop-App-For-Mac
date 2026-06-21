import SwiftUI

struct LoginView: View {
  let authService: AuthServiceProtocol
  var onGoogleSignIn: (() -> Void)?
  @State private var email = ""
  @State private var message: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      MilyonusLogoView(size: 64)

      Text("Giriş")
        .font(.headline)

      TextField("email@example.com", text: $email)
        .textFieldStyle(.roundedBorder)

      Button("Magic Link Gönder") {
        Task {
          do {
            try await authService.signInWithMagicLink(email: email)
            message = "Magic link gönderildi. E-postadaki bağlantı milyonus://auth-callback ile uygulamaya dönecek."
          } catch {
            message = error.localizedDescription
          }
        }
      }

      Button("Google ile Giriş") {
        onGoogleSignIn?()
      }

      if let message {
        Text(message)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}
