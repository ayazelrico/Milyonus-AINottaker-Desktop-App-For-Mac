import Foundation
import AVFoundation

enum AudioFormat {
  static let sampleRate: Double = 16_000
  static let channels: AVAudioChannelCount = 1
  static let deepgramEncoding = "linear16"

  static var deepgramPCMFormat: AVAudioFormat {
    AVAudioFormat(
      commonFormat: .pcmFormatInt16,
      sampleRate: sampleRate,
      channels: channels,
      interleaved: true
    )!
  }

  static func linearPCMData(from buffer: AVAudioPCMBuffer) throws -> Data {
    print("[Audio] Input format: \(buffer.format)")
    print("[Audio] Converting to 16kHz mono PCM Int16...")

    let outputBuffer: AVAudioPCMBuffer

    if buffer.format.sampleRate == deepgramPCMFormat.sampleRate &&
      buffer.format.channelCount == deepgramPCMFormat.channelCount &&
      buffer.format.commonFormat == deepgramPCMFormat.commonFormat &&
      buffer.format.isInterleaved == deepgramPCMFormat.isInterleaved {
      outputBuffer = buffer
    } else {
      outputBuffer = try convert(buffer, to: deepgramPCMFormat)
    }

    let data = try rawPCMData(from: outputBuffer)
    print("[Audio] Conversion successful, sending \(data.count) bytes to Deepgram")
    return data
  }

  private static func convert(_ buffer: AVAudioPCMBuffer, to outputFormat: AVAudioFormat) throws -> AVAudioPCMBuffer {
    guard let converter = AVAudioConverter(from: buffer.format, to: outputFormat) else {
      throw AudioCaptureError.conversionFailed
    }

    let ratio = outputFormat.sampleRate / buffer.format.sampleRate
    let capacity = max(AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio)) + 1, 1)
    guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
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

    return convertedBuffer
  }

  private static func rawPCMData(from buffer: AVAudioPCMBuffer) throws -> Data {
    let audioBuffer = buffer.audioBufferList.pointee.mBuffers
    guard let bytes = audioBuffer.mData else {
      throw AudioCaptureError.conversionFailed
    }

    let bytesPerFrame = Int(buffer.format.streamDescription.pointee.mBytesPerFrame)
    let expectedByteCount = Int(buffer.frameLength) * bytesPerFrame
    let availableByteCount = Int(audioBuffer.mDataByteSize)

    return Data(bytes: bytes, count: min(expectedByteCount, availableByteCount))
  }
}
