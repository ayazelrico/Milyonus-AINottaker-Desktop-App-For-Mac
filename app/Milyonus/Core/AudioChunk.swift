import Foundation

enum AudioSource: String, Codable {
  case system
  case microphone
}

struct AudioChunk: Identifiable {
  let id = UUID()
  let data: Data
  let timestamp: TimeInterval
  let source: AudioSource
}

enum AudioCaptureError: LocalizedError {
  case screenRecordingPermissionMissing
  case microphonePermissionMissing
  case noDisplayAvailable
  case streamStartFailed
  case conversionFailed

  var errorDescription: String? {
    switch self {
    case .screenRecordingPermissionMissing:
      return "Ekran kaydı izni verilmediği için sistem sesi yakalanamıyor."
    case .microphonePermissionMissing:
      return "Mikrofon izni verilmediği için kullanıcı sesi yakalanamıyor."
    case .noDisplayAvailable:
      return "Yakalanacak ekran bulunamadı."
    case .streamStartFailed:
      return "Ses yakalama akışı başlatılamadı."
    case .conversionFailed:
      return "Ses verisi Deepgram formatına dönüştürülemedi."
    }
  }
}

final class AudioChunkStream {
  private let lock = NSLock()
  private var continuation: AsyncStream<AudioChunk>.Continuation?

  var stream: AsyncStream<AudioChunk> {
    AsyncStream { continuation in
      lock.lock()
      self.continuation = continuation
      lock.unlock()
    }
  }

  func yield(_ chunk: AudioChunk) {
    lock.lock()
    let continuation = continuation
    lock.unlock()
    continuation?.yield(chunk)
  }

  func finish() {
    lock.lock()
    let continuation = continuation
    self.continuation = nil
    lock.unlock()
    continuation?.finish()
  }
}

