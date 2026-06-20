import Foundation
import CoreGraphics
import CoreMedia
import AVFoundation
import ScreenCaptureKit

final class SystemAudioCapture: NSObject, SCStreamOutput {
  var onChunk: ((AudioChunk) -> Void)?
  var onDebugMessage: ((String) -> Void)?

  private var stream: SCStream?
  private let sampleQueue = DispatchQueue(label: "com.milyonus.system-audio")

  func start() async throws {
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

      onDebugMessage?("system chunk \(data.count) bytes")
      onChunk?(
        AudioChunk(
          data: data,
          timestamp: Date().timeIntervalSince1970,
          source: .system
        )
      )
    } catch {
      onDebugMessage?("System audio conversion failed: \(error.localizedDescription)")
    }
  }

  private func pcmData(from sampleBuffer: CMSampleBuffer) throws -> Data {
    var blockBuffer: CMBlockBuffer?
    var bufferList = AudioBufferList()

    let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
      sampleBuffer,
      bufferListSizeNeededOut: nil,
      bufferListOut: &bufferList,
      bufferListSize: MemoryLayout<AudioBufferList>.size,
      blockBufferAllocator: kCFAllocatorDefault,
      blockBufferMemoryAllocator: kCFAllocatorDefault,
      flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
      blockBufferOut: &blockBuffer
    )

    guard status == noErr, let blockBuffer else {
      throw AudioCaptureError.conversionFailed
    }

    var totalLength = 0
    var dataPointer: UnsafeMutablePointer<Int8>?
    let pointerStatus = CMBlockBufferGetDataPointer(
      blockBuffer,
      atOffset: 0,
      lengthAtOffsetOut: nil,
      totalLengthOut: &totalLength,
      dataPointerOut: &dataPointer
    )

    guard pointerStatus == noErr, let dataPointer else {
      throw AudioCaptureError.conversionFailed
    }

    return Data(bytes: dataPointer, count: totalLength)
  }
}

