import Foundation
import CoreGraphics
import CoreMedia
import AVFoundation
import ScreenCaptureKit

final class SystemAudioCapture: NSObject, SCStreamOutput {
  var onChunk: ((AudioChunk) -> Void)?
  var onDebugMessage: ((String) -> Void)?
  var onFatalError: ((String) -> Void)?

  private var stream: SCStream?
  private let sampleQueue = DispatchQueue(label: "com.milyonus.system-audio")
  private let conversionFailureLimit = 10
  private var consecutiveConversionFailures = 0

  func start() async throws {
    consecutiveConversionFailures = 0

    guard CGPreflightScreenCaptureAccess() else {
      throw AudioCaptureError.screenRecordingPermissionMissing
    }

    let content = try await SCShareableContent.current
    guard let display = content.displays.first else {
      throw AudioCaptureError.noDisplayAvailable
    }

    let excludedApplications = content.applications.filter { application in
      application.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    let filter = SCContentFilter(
      display: display,
      excludingApplications: excludedApplications,
      exceptingWindows: []
    )

    let configuration = SCStreamConfiguration()
    configuration.capturesAudio = true
    configuration.excludesCurrentProcessAudio = true
    configuration.width = 2
    configuration.height = 2
    configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
    configuration.queueDepth = 3

    let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
    try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
    try await stream.startCapture()

    self.stream = stream
    onDebugMessage?("System audio capture started")
  }

  func stop() async {
    guard let stream else { return }

    do {
      try await stream.stopCapture()
    } catch {
      onDebugMessage?("System audio stop failed: \(error.localizedDescription)")
    }

    self.stream = nil
    onDebugMessage?("System audio capture stopped")
  }

  func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
    guard outputType == .audio, sampleBuffer.isValid else { return }

    do {
      let data = try pcmData(from: sampleBuffer)

      guard !data.isEmpty else { return }

      consecutiveConversionFailures = 0
      onDebugMessage?("system chunk \(data.count) bytes")
      onChunk?(
        AudioChunk(
          data: data,
          timestamp: Date().timeIntervalSince1970,
          source: .system
        )
      )
    } catch {
      handleConversionFailure(prefix: "System audio", error: error)
    }
  }

  private func pcmData(from sampleBuffer: CMSampleBuffer) throws -> Data {
    guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
      throw AudioCaptureError.conversionFailed
    }

    let inputFormat = AVAudioFormat(cmAudioFormatDescription: formatDescription)

    var bufferListSizeNeeded = 0
    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
      sampleBuffer,
      bufferListSizeNeededOut: &bufferListSizeNeeded,
      bufferListOut: nil,
      bufferListSize: 0,
      blockBufferAllocator: kCFAllocatorDefault,
      blockBufferMemoryAllocator: kCFAllocatorDefault,
      flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
      blockBufferOut: nil
    )

    let bufferListSize = max(bufferListSizeNeeded, MemoryLayout<AudioBufferList>.size)
    let rawBufferList = UnsafeMutableRawPointer.allocate(
      byteCount: bufferListSize,
      alignment: MemoryLayout<AudioBufferList>.alignment
    )
    defer {
      rawBufferList.deallocate()
    }

    let audioBufferList = rawBufferList.bindMemory(to: AudioBufferList.self, capacity: 1)
    var blockBuffer: CMBlockBuffer?

    let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
      sampleBuffer,
      bufferListSizeNeededOut: nil,
      bufferListOut: audioBufferList,
      bufferListSize: bufferListSize,
      blockBufferAllocator: kCFAllocatorDefault,
      blockBufferMemoryAllocator: kCFAllocatorDefault,
      flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
      blockBufferOut: &blockBuffer
    )

    guard status == noErr, let blockBuffer else {
      throw AudioCaptureError.conversionFailed
    }

    guard let pcmBuffer = AVAudioPCMBuffer(
      pcmFormat: inputFormat,
      bufferListNoCopy: UnsafePointer(audioBufferList),
      deallocator: nil
    ) else {
      throw AudioCaptureError.conversionFailed
    }

    _ = blockBuffer
    return try AudioFormat.linearPCMData(from: pcmBuffer)
  }

  private func handleConversionFailure(prefix: String, error: Error) {
    consecutiveConversionFailures += 1
    onDebugMessage?("\(prefix) conversion failed: \(error.localizedDescription)")

    if consecutiveConversionFailures >= conversionFailureLimit {
      onFatalError?("Ses yakalama hatası. Sistem ses ayarlarını kontrol et.")
    }
  }
}
