import Foundation
import AVFoundation

enum AudioFormat {
  static let sampleRate: Double = 48_000
  static let channels: AVAudioChannelCount = 1
  static let deepgramEncoding = "linear16"

  static var processingFormat: AVAudioFormat {
    AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: sampleRate,
      channels: channels,
      interleaved: false
    )!
  }

  static func linearPCMData(from buffer: AVAudioPCMBuffer) throws -> Data {
    let outputBuffer: AVAudioPCMBuffer

    if buffer.format.sampleRate == processingFormat.sampleRate &&
      buffer.format.channelCount == processingFormat.channelCount &&
      buffer.format.commonFormat == .pcmFormatFloat32 {
      outputBuffer = buffer
    } else {
      guard let converter = AVAudioConverter(from: buffer.format, to: processingFormat) else {
        throw AudioCaptureError.conversionFailed
      }

      let ratio = processingFormat.sampleRate / buffer.format.sampleRate
      let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
      guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: capacity) else {
        throw AudioCaptureError.conversionFailed
      }

      var didProvideInput = false
      var conversionError: NSError?
      let status = converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
        if didProvideInput {
          outStatus.pointee = .noDataNow
          return nil
        }

        didProvideInput = true
        outStatus.pointee = .haveData
        return buffer
      }

      if status == .error {
        throw conversionError ?? AudioCaptureError.conversionFailed
      }

      outputBuffer = convertedBuffer
    }

    guard let floatChannelData = outputBuffer.floatChannelData else {
      throw AudioCaptureError.conversionFailed
    }

    let frameCount = Int(outputBuffer.frameLength)
    let channelCount = Int(outputBuffer.format.channelCount)
    var data = Data(capacity: frameCount * MemoryLayout<Int16>.size)

    for frame in 0..<frameCount {
      var mixedSample: Float = 0

      for channel in 0..<channelCount {
        mixedSample += floatChannelData[channel][frame]
      }

      mixedSample /= Float(max(channelCount, 1))
      let clamped = min(max(mixedSample, -1), 1)
      var intSample = Int16(clamped * Float(Int16.max)).littleEndian

      withUnsafeBytes(of: &intSample) { bytes in
        data.append(contentsOf: bytes)
      }
    }

    return data
  }
}

