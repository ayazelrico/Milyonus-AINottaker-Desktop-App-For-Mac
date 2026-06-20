import Foundation
import Combine

@MainActor
final class TranscriptBufferManager: ObservableObject {
  @Published private(set) var segments: [TranscriptSegment] = []

  private let retentionInterval: TimeInterval = 60 * 60

  func append(_ segment: TranscriptSegment) {
    guard !segment.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return
    }

    segments.append(segment)
    pruneOldSegments()
  }

  func recentContext(minutes: Int) -> String {
    let cutoff = Date().addingTimeInterval(TimeInterval(-minutes * 60))

    return segments
      .filter { $0.isFinal && $0.timestamp >= cutoff }
      .map { "\($0.speaker.label): \($0.text)" }
      .joined(separator: "\n")
  }

  func fullTranscript() -> String {
    segments
      .filter(\.isFinal)
      .map { "\($0.speaker.label): \($0.text)" }
      .joined(separator: "\n")
  }

  func unsyncedFinalSegments(after lastID: UUID?) -> [TranscriptSegment] {
    let finalSegments = segments.filter(\.isFinal)

    guard let lastID,
          let index = finalSegments.firstIndex(where: { $0.id == lastID }) else {
      return finalSegments
    }

    return Array(finalSegments.dropFirst(index + 1))
  }

  func clear() {
    segments.removeAll()
  }

  private func pruneOldSegments() {
    let cutoff = Date().addingTimeInterval(-retentionInterval)
    segments.removeAll { $0.timestamp < cutoff }
  }
}
