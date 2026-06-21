import Foundation
import AVFoundation

final class MicrophoneCapture {
  var onChunk: ((AudioChunk) -> Void)?
  var onDebugMessage: ((String) -> Void)?
  var onFatalError: ((String) -> Void)?

  private let engine = AVAudioEngine()
  private let tapBus = 0
  private let conversionFailureLimit = 10
  private var consecutiveConversionFailures = 0

  func start() throws {
    consecutiveConversionFailures = 0

    guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
      throw AudioCaptureError.microphonePermissionMissing
    }

    let inputNode = engine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: tapBus)

    inputNode.removeTap(onBus: tapBus)
    inputNode.installTap(onBus: tapBus, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
      guard let self else { return }

      do {
        let data = try AudioFormat.linearPCMData(from: buffer)
        guard !data.isEmpty else { return }

        self.consecutiveConversionFailures = 0
        self.onDebugMessage?("microphone chunk \(data.count) bytes")
        self.onChunk?(
          AudioChunk(
            data: data,
            timestamp: Date().timeIntervalSince1970,
            source: .microphone
          )
        )
      } catch {
        self.handleConversionFailure(error)
      }
    }

    engine.prepare()
    try engine.start()
    onDebugMessage?("Microphone capture started")
  }

  func stop() {
    engine.inputNode.removeTap(onBus: tapBus)
    engine.stop()
    onDebugMessage?("Microphone capture stopped")
  }

  private func handleConversionFailure(_ error: Error) {
    consecutiveConversionFailures += 1
    onDebugMessage?("Microphone conversion failed: \(error.localizedDescription)")

    if consecutiveConversionFailures >= conversionFailureLimit {
      onFatalError?("Ses yakalama hatası. Sistem ses ayarlarını kontrol et.")
    }
  }
}
