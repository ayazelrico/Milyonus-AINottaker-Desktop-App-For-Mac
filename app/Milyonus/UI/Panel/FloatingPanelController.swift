import Foundation
import AppKit
import SwiftUI
import Combine

@MainActor
final class FloatingPanelController: ObservableObject {
  static let barContentSize = NSSize(width: 560, height: 58)
  static let chatContentSize = NSSize(width: 660, height: 500)

  @Published private(set) var isVisible: Bool
  @Published private(set) var isCollapsed: Bool
  @Published private(set) var isStealthModeEnabled: Bool

  private enum DefaultsKey {
    static let frame = "panel.frame.v2"
    static let visible = "panel.visible"
    static let collapsed = "panel.collapsed.v2"
    static let stealth = "panel.stealth.enabled"
  }

  private var window: FloatingPanelWindow?
  private weak var appModel: AppModel?

  init() {
    isVisible = UserDefaults.standard.object(forKey: DefaultsKey.visible) as? Bool ?? true
    isCollapsed = UserDefaults.standard.object(forKey: DefaultsKey.collapsed) as? Bool ?? true
    isStealthModeEnabled = UserDefaults.standard.object(forKey: DefaultsKey.stealth) as? Bool ?? true
  }

  func install(appModel: AppModel) {
    self.appModel = appModel

    if window == nil {
      let frame = restoredFrame()
      let panel = FloatingPanelWindow(contentRect: frame)
      panel.contentView = NSHostingView(
        rootView: PanelContentView()
          .environmentObject(appModel)
      )
      window = panel
    }

    applySharingType()

    if isVisible {
      show()
    }
  }

  func show() {
    guard let window else { return }

    isVisible = true
    persistState()
    appModel?.panelStateDidChange()
    window.orderFrontRegardless()
  }

  func hide() {
    guard let window else { return }

    saveFrame()
    isVisible = false
    persistState()
    appModel?.panelStateDidChange()
    window.orderOut(nil)
  }

  func toggle() {
    isVisible ? hide() : show()
  }

  func toggleFlashReveal() {
    toggle()
  }

  func toggleCollapsed() {
    isCollapsed.toggle()
    persistState()
    appModel?.panelStateDidChange()
    setChatPanelVisible(!isCollapsed)
  }

  func expandChat() {
    guard isCollapsed else { return }

    isCollapsed = false
    persistState()
    appModel?.panelStateDidChange()
  }

  func collapseChat() {
    guard !isCollapsed else { return }

    isCollapsed = true
    persistState()
    appModel?.panelStateDidChange()
    setChatPanelVisible(false)
  }

  func setChatPanelVisible(_ visible: Bool) {
    guard let window else { return }

    let size = visible ? Self.chatContentSize : Self.barContentSize
    let frame = resizedFramePreservingTopCenter(for: size, currentFrame: window.frame)
    window.setFrame(frame, display: true, animate: true)
  }

  func toggleStealthMode() {
    isStealthModeEnabled.toggle()
    UserDefaults.standard.set(isStealthModeEnabled, forKey: DefaultsKey.stealth)
    applySharingType()
    appModel?.panelStateDidChange()
  }

  private func applySharingType() {
    window?.sharingType = isStealthModeEnabled ? .none : .readOnly
  }

  private func restoredFrame() -> NSRect {
    if let string = UserDefaults.standard.string(forKey: DefaultsKey.frame) {
      let frame = NSRectFromString(string)

      if !frame.isEmpty {
        return frame
      }
    }

    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    return topCenteredFrame(in: screenFrame, size: Self.barContentSize)
  }

  private func topCenteredFrame(in screenFrame: NSRect, size: NSSize) -> NSRect {
    return NSRect(
      x: screenFrame.midX - (size.width / 2),
      y: screenFrame.maxY - size.height - 14,
      width: size.width,
      height: size.height
    )
  }

  private func resizedFramePreservingTopCenter(for size: NSSize, currentFrame: NSRect) -> NSRect {
    let screenFrame = window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let centerX = currentFrame.isEmpty ? screenFrame.midX : currentFrame.midX
    let topY = currentFrame.isEmpty ? screenFrame.maxY - 14 : currentFrame.maxY

    return NSRect(
      x: centerX - (size.width / 2),
      y: topY - size.height,
      width: size.width,
      height: size.height
    )
  }

  private func saveFrame() {
    guard let window else { return }
    UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: DefaultsKey.frame)
  }

  private func persistState() {
    UserDefaults.standard.set(isVisible, forKey: DefaultsKey.visible)
    UserDefaults.standard.set(isCollapsed, forKey: DefaultsKey.collapsed)
  }
}
