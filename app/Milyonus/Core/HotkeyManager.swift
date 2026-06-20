import Foundation
import AppKit

final class HotkeyManager {
  private var globalMonitor: Any?
  private var localMonitor: Any?
  private var onAssist: (() -> Void)?
  private var onTogglePanel: (() -> Void)?

  func start(onAssist: @escaping () -> Void, onTogglePanel: @escaping () -> Void) {
    stop()
    self.onAssist = onAssist
    self.onTogglePanel = onTogglePanel

    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
      self?.handle(event)
    }

    localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      self?.handle(event)
      return event
    }
  }

  func stop() {
    if let globalMonitor {
      NSEvent.removeMonitor(globalMonitor)
    }

    if let localMonitor {
      NSEvent.removeMonitor(localMonitor)
    }

    globalMonitor = nil
    localMonitor = nil
  }

  private func handle(_ event: NSEvent) {
    guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command) else {
      return
    }

    if event.keyCode == 36 || event.keyCode == 76 {
      onAssist?()
      return
    }

    if event.charactersIgnoringModifiers == "\\" {
      onTogglePanel?()
    }
  }
}

