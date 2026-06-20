import AppKit

final class FloatingPanelWindow: NSPanel {
  init(contentRect: NSRect) {
    super.init(
      contentRect: contentRect,
      styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    level = .floating
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    sharingType = .none
    isMovableByWindowBackground = true
    isReleasedWhenClosed = false
    hidesOnDeactivate = false
    hasShadow = true
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    backgroundColor = .clear
    isOpaque = false

    standardWindowButton(.closeButton)?.isHidden = true
    standardWindowButton(.miniaturizeButton)?.isHidden = true
    standardWindowButton(.zoomButton)?.isHidden = true
  }

  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    false
  }
}

