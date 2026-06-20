import Foundation

struct UserSession: Equatable {
  let userID: String
  let email: String?
  let accessToken: String?
}

protocol AuthServiceProtocol {
  func signInWithMagicLink(email: String) async throws
  func getCurrentSession() async -> UserSession?
  func signOut() async throws
}

enum AuthServiceError: LocalizedError {
  case missingDevelopmentToken

  var errorDescription: String? {
    switch self {
    case .missingDevelopmentToken:
      return "Geliştirme için MOCK_SUPABASE_JWT ayarlanmalı veya gerçek Supabase Auth bağlanmalı."
    }
  }
}

actor MockAuthService: AuthServiceProtocol {
  private var currentSession: UserSession?

  func signInWithMagicLink(email: String) async throws {
    currentSession = UserSession(
      userID: "mock-user",
      email: email,
      accessToken: AppConfig.mockSupabaseJWT
    )
  }

  func getCurrentSession() async -> UserSession? {
    if let currentSession {
      return currentSession
    }

    guard let token = AppConfig.mockSupabaseJWT else {
      return nil
    }

    return UserSession(userID: "mock-user", email: nil, accessToken: token)
  }

  func signOut() async throws {
    currentSession = nil
  }
}

