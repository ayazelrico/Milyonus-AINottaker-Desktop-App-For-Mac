import Foundation

enum SpeakerSource: String, Codable, CaseIterable {
  case user
  case other

  var label: String {
    switch self {
    case .user:
      return "Sen"
    case .other:
      return "Karşı taraf"
    }
  }
}

struct TranscriptSegment: Identifiable, Codable, Equatable {
  let id: UUID
  let speaker: SpeakerSource
  let text: String
  let isFinal: Bool
  let startOffsetMs: Int
  let endOffsetMs: Int
  let timestamp: Date

  init(
    id: UUID = UUID(),
    speaker: SpeakerSource,
    text: String,
    isFinal: Bool,
    startOffsetMs: Int,
    endOffsetMs: Int,
    timestamp: Date = Date()
  ) {
    self.id = id
    self.speaker = speaker
    self.text = text
    self.isFinal = isFinal
    self.startOffsetMs = startOffsetMs
    self.endOffsetMs = endOffsetMs
    self.timestamp = timestamp
  }
}

