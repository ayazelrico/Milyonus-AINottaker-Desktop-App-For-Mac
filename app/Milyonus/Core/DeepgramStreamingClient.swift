import Foundation

enum DeepgramStreamingError: LocalizedError {
  case missingAPIBaseURL
  case missingSessionToken
  case tokenRequestFailed(Int)
  case invalidTokenResponse
  case invalidURL
  case websocketClosed

  var errorDescription: String? {
    switch self {
    case .missingAPIBaseURL:
      return "API_BASE_URL ayarlı değil."
    case .missingSessionToken:
      return "Backend bağlantı hatası. Lütfen tekrar giriş yap."
    case .tokenRequestFailed:
      return "Backend bağlantı hatası. Lütfen tekrar giriş yap."
    case .invalidTokenResponse:
      return "Backend bağlantı hatası. Lütfen tekrar giriş yap."
    case .invalidURL:
      return "Deepgram WebSocket URL'i oluşturulamadı."
    case .websocketClosed:
      return "Deepgram bağlantısı kapandı."
    }
  }
}

final class DeepgramStreamingClient {
  var onSegment: ((TranscriptSegment) -> Void)?
  var onStatus: ((String) -> Void)?
  var onFatalError: ((String) -> Void)?

  private let source: AudioSource
  private let speaker: SpeakerSource
  private let language: LanguagePreference
  private let authService: AuthServiceProtocol
  private let tokenEndpointPath = "api/deepgram-token"
  private var task: URLSessionWebSocketTask?
  private var receiveTask: Task<Void, Never>?
  private var tokenRenewalTimer: Timer?
  private var sessionStartedAt = Date()
  private var reconnectAttempts = 0
  private var isClosed = false

  init(source: AudioSource, language: LanguagePreference, authService: AuthServiceProtocol) {
    self.source = source
    self.language = language
    self.authService = authService
    self.speaker = source == .microphone ? .user : .other
  }

  func connect() async throws {
    isClosed = false
    sessionStartedAt = Date()
    reconnectAttempts = 0
    let token = try await fetchShortLivedToken()
    try await replaceSocket(using: token)
  }

  func send(_ chunk: AudioChunk) async {
    guard let task else { return }

    do {
      try await task.send(.data(chunk.data))
    } catch {
      onStatus?("Deepgram send failed: \(error.localizedDescription)")
      await reconnectIfPossible()
    }
  }

  func close() async {
    isClosed = true
    invalidateTokenRenewalTimer()
    receiveTask?.cancel()
    receiveTask = nil
    task?.cancel(with: .goingAway, reason: nil)
    task = nil
  }

  private func fetchShortLivedToken() async throws -> DeepgramTokenGrant {
    guard let apiBaseURL = AppConfig.apiBaseURL else {
      throw DeepgramStreamingError.missingAPIBaseURL
    }

    let session = await authService.getCurrentSession()
    guard let supabaseJWT = session?.accessToken else {
      throw DeepgramStreamingError.missingSessionToken
    }

    print("[Deepgram] Fetching short-lived token from backend...")

    let url = apiBaseURL.appendingPathComponent(tokenEndpointPath)
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("Bearer \(supabaseJWT)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw URLError(.badServerResponse)
    }

    guard (200..<300).contains(httpResponse.statusCode) else {
      throw DeepgramStreamingError.tokenRequestFailed(httpResponse.statusCode)
    }

    let tokenResponse = try JSONDecoder().decode(DeepgramTokenResponse.self, from: data)
    guard let expiresAt = DeepgramDateParser.date(from: tokenResponse.expires_at) else {
      throw DeepgramStreamingError.invalidTokenResponse
    }

    print("[Deepgram] Token received, expires at: \(expiresAt)")
    return DeepgramTokenGrant(token: tokenResponse.token, expiresAt: expiresAt)
  }

  private func replaceSocket(using grant: DeepgramTokenGrant) async throws {
    guard let url = deepgramURL() else {
      throw DeepgramStreamingError.invalidURL
    }

    print("[Deepgram] WebSocket connecting to: wss://api.deepgram.com/v1/listen")

    var request = URLRequest(url: url)
    request.addValue("Bearer \(grant.token)", forHTTPHeaderField: "Authorization")

    let nextTask = URLSession.shared.webSocketTask(with: request)
    let previousTask = task
    let previousReceiveTask = receiveTask

    task = nextTask
    nextTask.resume()
    receiveTask = Task { [weak self, weak nextTask] in
      guard let nextTask else { return }
      await self?.receiveLoop(for: nextTask)
    }

    previousReceiveTask?.cancel()
    previousTask?.cancel(with: .goingAway, reason: nil)
    scheduleTokenRenewal(expiresAt: grant.expiresAt)
    print("[Deepgram] WebSocket connected, streaming audio...")
  }

  private func deepgramURL() -> URL? {
    var components = URLComponents(string: "wss://api.deepgram.com/v1/listen")
    var queryItems = [
      URLQueryItem(name: "model", value: "nova-3"),
      URLQueryItem(name: "encoding", value: AudioFormat.deepgramEncoding),
      URLQueryItem(name: "sample_rate", value: String(Int(AudioFormat.sampleRate))),
      URLQueryItem(name: "channels", value: "1"),
      URLQueryItem(name: "punctuate", value: "true"),
      URLQueryItem(name: "interim_results", value: "true")
    ]

    if let deepgramLanguageCode = language.deepgramLanguageCode {
      queryItems.append(URLQueryItem(name: "language", value: deepgramLanguageCode))
    }

    components?.queryItems = queryItems
    return components?.url
  }

  private func receiveLoop(for webSocketTask: URLSessionWebSocketTask) async {
    while !Task.isCancelled {
      do {
        let message = try await webSocketTask.receive()

        switch message {
        case .string(let text):
          handleTranscriptPayload(text)
        case .data(let data):
          if let text = String(data: data, encoding: .utf8) {
            handleTranscriptPayload(text)
          }
        @unknown default:
          break
        }
      } catch {
        if Task.isCancelled || webSocketTask !== task || isClosed {
          return
        }

        onStatus?("Deepgram receive failed: \(error.localizedDescription)")
        await reconnectIfPossible()
        return
      }
    }
  }

  private func reconnectIfPossible() async {
    guard !isClosed else { return }

    guard reconnectAttempts < 4 else {
      let message = "Backend bağlantı hatası. Lütfen tekrar giriş yap."
      onStatus?(message)
      onFatalError?(message)
      await close()
      return
    }

    reconnectAttempts += 1

    let delay = UInt64(pow(2.0, Double(reconnectAttempts)) * 500_000_000)
    onStatus?("Bağlantı kesildi, yeniden bağlanılıyor...")

    try? await Task.sleep(nanoseconds: delay)

    do {
      let token = try await fetchShortLivedToken()
      try await replaceSocket(using: token)
    } catch {
      onStatus?("Deepgram reconnect failed: \(error.localizedDescription)")
    }
  }

  private func scheduleTokenRenewal(expiresAt: Date) {
    let renewalInterval = max(expiresAt.timeIntervalSinceNow - 60, 0)

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      self.tokenRenewalTimer?.invalidate()
      self.tokenRenewalTimer = Timer.scheduledTimer(withTimeInterval: renewalInterval, repeats: false) { [weak self] _ in
        Task {
          await self?.renewTokenAndReconnect()
        }
      }
    }
  }

  private func invalidateTokenRenewalTimer() {
    DispatchQueue.main.async { [weak self] in
      self?.tokenRenewalTimer?.invalidate()
      self?.tokenRenewalTimer = nil
    }
  }

  private func renewTokenAndReconnect() async {
    guard !isClosed else { return }

    print("[Deepgram] Token renewal triggered (60s before expiry)")

    do {
      let token = try await fetchShortLivedToken()
      try await replaceSocket(using: token)
      reconnectAttempts = 0
    } catch {
      let message = "Backend bağlantı hatası. Lütfen tekrar giriş yap."
      onStatus?(message)
      onFatalError?(message)
      await close()
    }
  }

  private func handleTranscriptPayload(_ text: String) {
    guard let data = text.data(using: .utf8),
          let response = try? JSONDecoder().decode(DeepgramResponse.self, from: data),
          let transcript = response.channel.alternatives.first?.transcript,
          !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return
    }

    print("[Deepgram] Transcript received: \(transcript.prefix(50))...")

    let startMs = Int((response.start ?? Date().timeIntervalSince(sessionStartedAt)) * 1000)
    let durationMs = Int((response.duration ?? 0) * 1000)
    let segment = TranscriptSegment(
      speaker: speaker,
      text: transcript,
      isFinal: response.isFinal ?? false,
      startOffsetMs: startMs,
      endOffsetMs: startMs + durationMs
    )

    onSegment?(segment)
  }
}

private struct DeepgramTokenGrant {
  let token: String
  let expiresAt: Date
}

private struct DeepgramTokenResponse: Decodable {
  let token: String
  let expires_at: String
}

private enum DeepgramDateParser {
  private static let fractionalFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let formatter = ISO8601DateFormatter()

  static func date(from value: String) -> Date? {
    fractionalFormatter.date(from: value) ?? formatter.date(from: value)
  }
}

private struct DeepgramResponse: Decodable {
  let isFinal: Bool?
  let start: Double?
  let duration: Double?
  let channel: DeepgramChannel

  enum CodingKeys: String, CodingKey {
    case isFinal = "is_final"
    case start
    case duration
    case channel
  }
}

private struct DeepgramChannel: Decodable {
  let alternatives: [DeepgramAlternative]
}

private struct DeepgramAlternative: Decodable {
  let transcript: String
}
