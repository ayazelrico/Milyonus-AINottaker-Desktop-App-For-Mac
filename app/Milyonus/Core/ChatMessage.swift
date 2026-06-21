import Foundation

struct ChatMessage: Identifiable, Equatable {
  enum Role: String {
    case user
    case assistant
  }

  let id: UUID
  let role: Role
  var content: String
  let timestamp: Date
  var isError: Bool

  init(
    id: UUID = UUID(),
    role: Role,
    content: String,
    timestamp: Date = Date(),
    isError: Bool = false
  ) {
    self.id = id
    self.role = role
    self.content = content
    self.timestamp = timestamp
    self.isError = isError
  }
}
