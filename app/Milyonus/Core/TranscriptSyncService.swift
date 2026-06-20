import Foundation

@MainActor
final class TranscriptSyncService {
  private let authService: AuthServiceProtocol
  private weak var transcriptBuffer: TranscriptBufferManager?
  private var sessionID: UUID?
  private var lastSyncedSegmentID: UUID?
  private var timerTask: Task<Void, Never>?
  private var retryQueue: [TranscriptSegment] = []
  private let interval: UInt64 = 30_000_000_000

  init(authService: AuthServiceProtocol) {
    self.authService = authService
  }

  func attach(buffer: TranscriptBufferManager) {
    transcriptBuffer = buffer
  }

  func configure(sessionID: UUID) {
    self.sessionID = sessionID
    lastSyncedSegmentID = nil
  }

  func start() {
    timerTask?.cancel()
    timerTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: self?.interval ?? 30_000_000_000)
        await self?.flush()
      }
    }
  }

  func stop() async {
    timerTask?.cancel()
    timerTask = nil
    await flush()
  }

  func flush() async {
    guard let sessionID,
          let transcriptBuffer else {
      return
    }

    let newSegments = transcriptBuffer.unsyncedFinalSegments(after: lastSyncedSegmentID)
    let segments = retryQueue + newSegments

    guard !segments.isEmpty else { return }

    do {
      try await post(segments: segments, sessionID: sessionID)
      retryQueue.removeAll()
      lastSyncedSegmentID = segments.last?.id
    } catch {
      retryQueue = segments
      print("[TranscriptSync] queued \(segments.count) segments after error: \(error.localizedDescription)")
    }
  }

  private func post(segments: [TranscriptSegment], sessionID: UUID) async throws {
    guard let apiBaseURL = AppConfig.apiBaseURL else { return }
    let session = await authService.getCurrentSession()
    guard let token = session?.accessToken else {
      throw AuthServiceError.missingDevelopmentToken
    }

    let url = apiBaseURL
      .appendingPathComponent("api")
      .appendingPathComponent("sessions")
      .appendingPathComponent(sessionID.uuidString)
      .appendingPathComponent("transcript")

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONEncoder().encode(TranscriptBatchPayload(chunks: segments.map(TranscriptChunkPayload.init(segment:))))

    let (_, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
          (200..<300).contains(httpResponse.statusCode) else {
      throw URLError(.badServerResponse)
    }
  }
}

private struct TranscriptBatchPayload: Encodable {
  let chunks: [TranscriptChunkPayload]
}

private struct TranscriptChunkPayload: Encodable {
  let speaker: String
  let text: String
  let start_offset_ms: Int
  let end_offset_ms: Int

  init(segment: TranscriptSegment) {
    speaker = segment.speaker.rawValue
    text = segment.text
    start_offset_ms = segment.startOffsetMs
    end_offset_ms = segment.endOffsetMs
  }
}
