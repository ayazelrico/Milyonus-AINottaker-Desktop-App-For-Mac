import Foundation

enum DeepgramStreamingError: LocalizedError {
  case missingDevelopmentKey
  case invalidURL
  case websocketClosed

  var errorDescription: String? {
    switch self {
    case .missingDevelopmentKey:
      return "Deepgram production'a hazır değil: backend kısa ömürlü token endpoint'i henüz yok."
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

  private let source: AudioSource
  private let speaker: SpeakerSource
  private let language: LanguagePreference
  private var task: URLSessionWebSocketTask?
  private var receiveTask: Task<Void, Never>?
  private var sessionStartedAt = Date()
  private var reconnectAttempts = 0

  init(source: AudioSource, language: LanguagePreference) {
    self.source = source
    self.language = language
    self.speaker = source == .microphone ? .user : .other
  }

  func connect() async throws {
    sessionStartedAt = Date()
    reconnectAttempts = 0
    try await openSocket()
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
    receiveTask?.cancel()
    receiveTask = nil
    task?.cancel(with: .goingAway, reason: nil)
    task = nil
  }

  private func openSocket() async throws {
    throw DeepgramStreamingError.missingDevelopmentKey

    // When /api/deepgram-token exists, fetch a short-lived backend token here and open the socket.
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

  private func receiveLoop() async {
    while !Task.isCancelled {
      do {
        guard let message = try await task?.receive() else {
          throw DeepgramStreamingError.websocketClosed
        }

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
        onStatus?("Deepgram receive failed: \(error.localizedDescription)")
        await reconnectIfPossible()
        return
      }
    }
  }

  private func reconnectIfPossible() async {
    guard reconnectAttempts < 4 else { return }
    reconnectAttempts += 1

    let delay = UInt64(pow(2.0, Double(reconnectAttempts)) * 500_000_000)
    onStatus?("Bağlantı kesildi, yeniden bağlanılıyor...")

    try? await Task.sleep(nanoseconds: delay)

    do {
      try await openSocket()
    } catch {
      onStatus?("Deepgram reconnect failed: \(error.localizedDescription)")
    }
  }

  private func handleTranscriptPayload(_ text: String) {
    guard let data = text.data(using: .utf8),
          let response = try? JSONDecoder().decode(DeepgramResponse.self, from: data),
          let transcript = response.channel.alternatives.first?.transcript,
          !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return
    }

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
