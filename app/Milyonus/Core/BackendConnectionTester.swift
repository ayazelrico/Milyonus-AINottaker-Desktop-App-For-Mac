import Foundation

@MainActor
final class BackendConnectionTester {
  private let authService: AuthServiceProtocol

  init(authService: AuthServiceProtocol) {
    self.authService = authService
  }

  func testUsageEndpoint() async -> String {
    guard let apiBaseURL = AppConfig.apiBaseURL else {
      return "API_BASE_URL okunamadı."
    }

    let url = apiBaseURL.appendingPathComponent("api").appendingPathComponent("usage")
    var request = URLRequest(url: url)

    do {
      let session = try await authService.ensureAuthenticatedSession()
      if let token = session.accessToken {
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      }
    } catch {
      return "Supabase oturumu oluşturulamadı: \(error.localizedDescription)"
    }

    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
        return "Backend yanıtı HTTP değil."
      }

      let body = String(data: data, encoding: .utf8) ?? ""

      if httpResponse.statusCode == 200 {
        return "200 OK: /api/usage erişilebilir."
      }

      if httpResponse.statusCode == 401 {
        return "401 Unauthorized: backend erişilebilir, login/token gerekli."
      }

      return "\(httpResponse.statusCode): \(body.prefix(180))"
    } catch {
      return "Bağlantı hatası: \(error.localizedDescription)"
    }
  }
}
