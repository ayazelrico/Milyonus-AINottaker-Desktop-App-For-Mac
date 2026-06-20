import Foundation
import AppKit

struct MeetingApp: Identifiable, Equatable {
  let id: String
  let displayName: String
}

final class MeetingAppDetector {
  private let knownApps: [String: MeetingApp] = [
    "us.zoom.xos": MeetingApp(id: "zoom", displayName: "Zoom"),
    "com.microsoft.teams2": MeetingApp(id: "teams", displayName: "Microsoft Teams"),
    "com.microsoft.teams": MeetingApp(id: "teams", displayName: "Microsoft Teams")
  ]

  func frontmostMeetingApp() -> MeetingApp? {
    guard let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
      return nil
    }

    // Google Meet usually runs inside a browser tab, so native detection is deferred.
    return knownApps[bundleIdentifier]
  }

  func runningMeetingApps() -> [MeetingApp] {
    NSWorkspace.shared.runningApplications.compactMap { application in
      guard let bundleIdentifier = application.bundleIdentifier else {
        return nil
      }

      return knownApps[bundleIdentifier]
    }
  }
}

