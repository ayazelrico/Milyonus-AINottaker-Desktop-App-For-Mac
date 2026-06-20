import Foundation
import Combine

@MainActor
final class TranscriptionCoordinator: ObservableObject {
  @Published private(set) var isTranscribing = false
  @Published var statusMessage: String?

  private let audioCaptureCoordinator: AudioCaptureCoordinator
  private let transcriptBuffer: TranscriptBufferManager
  private let syncService: TranscriptSyncService
  private var systemClient: DeepgramStreamingClient?
  private var microphoneClient: DeepgramStreamingClient?
  private var audioTasks: [Task<Void, Never>] = []

  init(
    audioCaptureCoordinator: AudioCaptureCoordinator,
    transcriptBuffer: TranscriptBufferManager,
    syncService: TranscriptSyncService
  ) {
    self.audioCaptureCoordinator = audioCaptureCoordinator
    self.transcriptBuffer = transcriptBuffer
    self.syncService = syncService
    self.syncService.attach(buffer: transcriptBuffer)
  }

  func start(sessionID: UUID, language: LanguagePreference) async throws {
    guard !isTranscribing else { return }

    let systemClient = DeepgramStreamingClient(source: .system, language: language)
    let microphoneClient = DeepgramStreamingClient(source: .microphone, language: language)
    configure(client: systemClient)
    configure(client: microphoneClient)

    do {
      try await audioCaptureCoordinator.startCapture()
      try await systemClient.connect()
      try await microphoneClient.connect()
    } catch {
      await systemClient.close()
      await microphoneClient.close()
      await audioCaptureCoordinator.stopCapture()
      throw error
    }

    self.systemClient = systemClient
    self.microphoneClient = microphoneClient

    audioTasks = [
      Task { [weak self] in
        guard let self else { return }

        for await chunk in self.audioCaptureCoordinator.systemAudioStream {
          await self.systemClient?.send(chunk)
        }
      },
      Task { [weak self] in
        guard let self else { return }

        for await chunk in self.audioCaptureCoordinator.microphoneAudioStream {
          await self.microphoneClient?.send(chunk)
        }
      }
    ]

    syncService.configure(sessionID: sessionID)
    syncService.start()
    isTranscribing = true
  }

  func stop() async {
    guard isTranscribing else { return }

    audioTasks.forEach { $0.cancel() }
    audioTasks.removeAll()

    await systemClient?.close()
    await microphoneClient?.close()
    await audioCaptureCoordinator.stopCapture()
    await syncService.stop()

    systemClient = nil
    microphoneClient = nil
    isTranscribing = false
  }

  private func configure(client: DeepgramStreamingClient) {
    // Two separate sockets keep speaker labels deterministic for MVP and avoid multi-channel
    // framing complexity. We can revisit multi-channel if Deepgram pricing/latency warrants it.
    client.onSegment = { [weak self] segment in
      Task { @MainActor in
        self?.transcriptBuffer.append(segment)
      }
    }

    client.onStatus = { [weak self] message in
      Task { @MainActor in
        self?.statusMessage = message
        print("[Deepgram] \(message)")
      }
    }
  }
}
