import SwiftUI

struct LoginView: View {
  let authService: AuthServiceProtocol
  @State private var email = ""
  @State private var message: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Giriş")
        .font(.headline)

      TextField("email@example.com", text: $email)
        .textFieldStyle(.roundedBorder)

      Button("Magic Link Gönder") {
        Task {
          do {
            try await authService.signInWithMagicLink(email: email)
            message = "Magic link stub çalıştı. Gerçek Supabase Auth entegrasyonu sonraki iterasyonda bağlanacak."
          } catch {
            message = error.localizedDescription
          }
        }
      }

      if let message {
        Text(message)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

