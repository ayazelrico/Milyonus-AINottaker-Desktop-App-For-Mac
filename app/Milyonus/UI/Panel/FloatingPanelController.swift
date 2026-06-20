import Foundation
import AppKit
import SwiftUI
import Combine

@MainActor
final class FloatingPanelController: ObservableObject {
  @Published private(set) var isVisible: Bool
  @Published private(set) var isCollapsed: Bool

  private enum DefaultsKey {
    static let frame = "panel.frame"
    static let visible = "panel.visible"
    static let collapsed = "panel.collapsed"
  }

  private var window: FloatingPanelWindow?
  private weak var appModel: AppModel?

  init() {
    isVisible = UserDefaults.standard.object(forKey: DefaultsKey.visible) as? Bool ?? true
    isCollapsed = UserDefaults.standard.bool(forKey: DefaultsKey.collapsed)
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

    guard let window else { return }

    if isCollapsed {
      saveFrame()
      window.setContentSize(NSSize(width: 72, height: 72))
    } else {
      window.setContentSize(NSSize(width: 360, height: 480))
    }
  }

  private func restoredFrame() -> NSRect {
    if let string = UserDefaults.standard.string(forKey: DefaultsKey.frame) {
      let frame = NSRectFromString(string)

      if !frame.isEmpty {
        return frame
      }
    }

    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    return NSRect(
      x: screenFrame.maxX - 400,
      y: screenFrame.maxY - 520,
      width: isCollapsed ? 72 : 360,
      height: isCollapsed ? 72 : 480
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
