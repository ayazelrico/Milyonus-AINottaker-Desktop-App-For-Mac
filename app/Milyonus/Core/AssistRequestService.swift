import Foundation

enum AssistRequestError: LocalizedError {
  case missingAPIBaseURL
  case missingSessionToken
  case badResponse(Int)

  var errorDescription: String? {
    switch self {
    case .missingAPIBaseURL:
      return "API_BASE_URL ayarlı değil."
    case .missingSessionToken:
      return "Oturum token'ı yok. Supabase Auth entegrasyonu tamamlanmalı."
    case .badResponse(let status):
      return "Backend isteği başarısız oldu (\(status))."
    }
  }
}

@MainActor
final class AssistRequestService {
  private let authService: AuthServiceProtocol
  private let transcriptBuffer: TranscriptBufferManager

  init(authService: AuthServiceProtocol, transcriptBuffer: TranscriptBufferManager) {
    self.authService = authService
    self.transcriptBuffer = transcriptBuffer
  }

  func streamAssist(
    sessionID: UUID?,
    question: String?,
    language: LanguagePreference,
    onDelta: @MainActor @escaping (String) -> Void
  ) async throws {
    guard let apiBaseURL = AppConfig.apiBaseURL else {
      throw AssistRequestError.missingAPIBaseURL
    }

    let session = try await authService.ensureAuthenticatedSession()
    guard let token = session.accessToken else {
      throw AssistRequestError.missingSessionToken
    }

    let url = apiBaseURL.appendingPathComponent("api").appendingPathComponent("assist")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
    request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let context = sessionID == nil ? "" : transcriptBuffer.recentContext(minutes: 5)
    let payload = AssistPayload(
      session_id: sessionID?.uuidString,
      transcript_context: context,
      user_question: question?.isEmpty == true ? nil : question,
      language: language.assistLanguageCode
    )
    request.httpBody = try JSONEncoder().encode(payload)

    let (bytes, response) = try await URLSession.shared.bytes(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw URLError(.badServerResponse)
    }

    guard (200..<300).contains(httpResponse.statusCode) else {
      throw AssistRequestError.badResponse(httpResponse.statusCode)
    }

    for try await line in bytes.lines {
      guard line.hasPrefix("data: ") else { continue }

      let json = String(line.dropFirst(6))
      guard let data = json.data(using: .utf8),
            let event = try? JSONDecoder().decode(AssistSSEPayload.self, from: data),
            let delta = event.delta else {
        continue
      }

      onDelta(delta)
    }
  }
}

private struct AssistPayload: Encodable {
  let session_id: String?
  let transcript_context: String
  let user_question: String?
  let language: String
}

private struct AssistSSEPayload: Decodable {
  let delta: String?
}
