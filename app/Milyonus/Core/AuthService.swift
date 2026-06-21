import Foundation
#if canImport(Supabase)
  import Supabase
#endif

struct UserSession: Equatable {
  let userID: String
  let email: String?
  let accessToken: String?
}

protocol AuthServiceProtocol {
  func signInWithMagicLink(email: String) async throws
  func signInWithGoogle() async throws
  func handleAuthCallback(_ url: URL) async throws
  func getCurrentSession() async -> UserSession?
  func ensureAuthenticatedSession() async throws -> UserSession
  func signOut() async throws
}

enum AuthServiceError: LocalizedError {
  case missingSupabaseConfiguration
  case missingSession

  var errorDescription: String? {
    switch self {
    case .missingSupabaseConfiguration:
      return "SUPABASE_URL ve SUPABASE_ANON_KEY Secrets.xcconfig içinde ayarlanmalı."
    case .missingSession:
      return "Aktif Supabase oturumu bulunamadı."
    }
  }
}

enum AuthServiceFactory {
  static func make() -> AuthServiceProtocol {
    #if canImport(Supabase)
      if let service = try? SupabaseAuthService() {
        return service
      }
    #endif

    return MockAuthService()
  }
}

actor MockAuthService: AuthServiceProtocol {
  private var currentSession: UserSession?

  func signInWithMagicLink(email: String) async throws {
    currentSession = UserSession(
      userID: "mock-user",
      email: email,
      accessToken: nil
    )
  }

  func signInWithGoogle() async throws {
    throw AuthServiceError.missingSupabaseConfiguration
  }

  func handleAuthCallback(_ url: URL) async throws {
    _ = url
  }

  func getCurrentSession() async -> UserSession? {
    if let currentSession {
      return currentSession
    }

    return nil
  }

  func ensureAuthenticatedSession() async throws -> UserSession {
    if let currentSession {
      return currentSession
    }

    throw AuthServiceError.missingSupabaseConfiguration
  }

  func signOut() async throws {
    currentSession = nil
  }
}

#if canImport(Supabase)
  actor SupabaseAuthService: AuthServiceProtocol {
    private let client: SupabaseClient

    init() throws {
      guard let supabaseURL = AppConfig.supabaseURL,
            let supabaseAnonKey = AppConfig.supabaseAnonKey else {
        throw AuthServiceError.missingSupabaseConfiguration
      }

      client = SupabaseClient(
        supabaseURL: supabaseURL,
        supabaseKey: supabaseAnonKey,
        options: SupabaseClientOptions(
          auth: .init(
            storage: KeychainLocalStorage(service: "com.milyonus.app.supabase"),
            redirectToURL: AppConfig.authCallbackURL,
            storageKey: "milyonus.auth.session",
            autoRefreshToken: true,
            emitLocalSessionAsInitialSession: true
          )
        )
      )
    }

    func signInWithMagicLink(email: String) async throws {
      try await client.auth.signInWithOTP(
        email: email,
        redirectTo: AppConfig.authCallbackURL
      )
    }

    func signInWithGoogle() async throws {
      try await client.auth.signInWithOAuth(
        provider: .google,
        redirectTo: AppConfig.authCallbackURL
      )
    }

    func handleAuthCallback(_ url: URL) async throws {
      _ = try await client.auth.session(from: url)
    }

    func getCurrentSession() async -> UserSession? {
      do {
        let session = try await client.auth.session
        return userSession(from: session)
      } catch {
        return nil
      }
    }

    func ensureAuthenticatedSession() async throws -> UserSession {
      do {
        let session = try await client.auth.session
        print("[Auth] Existing Supabase session found")
        return userSession(from: session)
      } catch {
        do {
          let session = try await client.auth.signInAnonymously()
          print("[Auth] Anonymous session created")
          return userSession(from: session)
        } catch {
          print("[Auth] Anonymous session failed: \(error.localizedDescription)")
          throw error
        }
      }
    }

    func signOut() async throws {
      try await client.auth.signOut()
    }

    private func userSession(from session: Session) -> UserSession {
      UserSession(
        userID: session.user.id.uuidString,
        email: session.user.email,
        accessToken: session.accessToken
      )
    }
  }
#endif
