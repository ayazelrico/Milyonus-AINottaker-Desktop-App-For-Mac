import Foundation
import Combine

@MainActor
final class AudioCaptureCoordinator: ObservableObject {
  @Published private(set) var isCapturing = false
  @Published var captureError: String?
  @Published var debugMessages: [String] = []

  var onFatalError: ((String) -> Void)?

  private var systemCapture = SystemAudioCapture()
  private var microphoneCapture = MicrophoneCapture()
  private var systemPipe = AudioChunkStream()
  private var microphonePipe = AudioChunkStream()

  var systemAudioStream: AsyncStream<AudioChunk> {
    systemPipe.stream
  }

  var microphoneAudioStream: AsyncStream<AudioChunk> {
    microphonePipe.stream
  }

  func startCapture() async throws {
    guard !isCapturing else { return }

    captureError = nil
    debugMessages.removeAll(keepingCapacity: true)

    systemPipe = AudioChunkStream()
    microphonePipe = AudioChunkStream()

    let systemPipe = systemPipe
    let microphonePipe = microphonePipe

    systemCapture.onChunk = { chunk in
      systemPipe.yield(chunk)
    }
    microphoneCapture.onChunk = { chunk in
      microphonePipe.yield(chunk)
    }

    systemCapture.onDebugMessage = { [weak self] message in
      Task { @MainActor in self?.appendDebugMessage(message) }
    }
    microphoneCapture.onDebugMessage = { [weak self] message in
      Task { @MainActor in self?.appendDebugMessage(message) }
    }
    systemCapture.onFatalError = { [weak self] message in
      Task { @MainActor in self?.handleFatalError(message) }
    }
    microphoneCapture.onFatalError = { [weak self] message in
      Task { @MainActor in self?.handleFatalError(message) }
    }

    do {
      try await systemCapture.start()
      try microphoneCapture.start()
      isCapturing = true
    } catch {
      await stopCapture()
      captureError = error.localizedDescription
      throw error
    }
  }

  func stopCapture() async {
    await systemCapture.stop()
    microphoneCapture.stop()
    systemPipe.finish()
    microphonePipe.finish()
    isCapturing = false
  }

  private func appendDebugMessage(_ message: String) {
    debugMessages.append(message)

    if debugMessages.count > 80 {
      debugMessages.removeFirst(debugMessages.count - 80)
    }

    print("[AudioCapture] \(message)")
  }

  private func handleFatalError(_ message: String) {
    captureError = message
    appendDebugMessage(message)
    onFatalError?(message)
  }
}
