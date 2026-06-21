import AppKit
import SwiftUI

struct VisualEffectBlur: NSViewRepresentable {
  var material: NSVisualEffectView.Material
  var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = material
    view.blendingMode = blendingMode
    view.state = .active
    view.isEmphasized = true
    return view
  }

  func updateNSView(_ view: NSVisualEffectView, context: Context) {
    view.material = material
    view.blendingMode = blendingMode
    view.state = .active
  }
}

struct MilyonusLogoView: View {
  var size: CGFloat

  var body: some View {
    Image("MilyonusLogo")
      .resizable()
      .renderingMode(.original)
      .scaledToFit()
      .frame(width: size, height: size)
      .accessibilityLabel("Milyonus")
  }
}

struct GlassCapsuleBackground: View {
  var overlayOpacity: Double

  var body: some View {
    ZStack {
      VisualEffectBlur(material: .hudWindow)
      Color.black.opacity(overlayOpacity)
      LinearGradient(
        colors: [.white.opacity(0.09), .white.opacity(0.02), .clear],
        startPoint: .top,
        endPoint: .bottom
      )
    }
    .clipShape(Capsule())
    .overlay {
      Capsule()
        .stroke(.white.opacity(0.15), lineWidth: 1)
    }
  }
}

struct GlassRoundedBackground: View {
  var cornerRadius: CGFloat
  var overlayOpacity: Double

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

    ZStack {
      VisualEffectBlur(material: .hudWindow)
      Color.black.opacity(overlayOpacity)
      LinearGradient(
        colors: [.white.opacity(0.10), .white.opacity(0.03), .clear],
        startPoint: .top,
        endPoint: .bottom
      )
    }
    .clipShape(shape)
    .overlay {
      shape.stroke(.white.opacity(0.15), lineWidth: 1)
    }
  }
}

struct TopBarView: View {
  @EnvironmentObject private var appModel: AppModel
  @State private var isKeybindsPopoverPresented = false

  var onAsk: () -> Void
  var onToggleChat: () -> Void

  var body: some View {
    TimelineView(.periodic(from: Date(), by: 1)) { context in
      HStack(spacing: 10) {
        MilyonusLogoView(size: 22)

        statusView(now: context.date)

        mainActionsMenu

        Divider()
          .frame(height: 20)
          .overlay(.white.opacity(0.18))

        Button(action: onAsk) {
          Label("Ask AI", systemImage: "sparkles")
            .labelStyle(.titleAndIcon)
            .font(.system(size: 12, weight: .semibold))
        }
        .buttonStyle(TopBarButtonStyle(isPrimary: true))
        .keyboardShortcut(.return, modifiers: .command)
        .help("Ask AI (Cmd+Enter)")

        Button(action: onToggleChat) {
          Image(systemName: appModel.panelController.isCollapsed ? "chevron.down" : "chevron.up")
            .font(.system(size: 12, weight: .bold))
            .frame(width: 24, height: 24)
        }
        .buttonStyle(TopBarButtonStyle())
        .help(appModel.panelController.isCollapsed ? "Chat panelini aç" : "Chat panelini kapat")

        Button {
          appModel.panelController.toggleStealthMode()
        } label: {
          Image(systemName: appModel.panelController.isStealthModeEnabled ? "eye.slash" : "eye")
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 24, height: 24)
        }
        .buttonStyle(TopBarButtonStyle())
        .help(appModel.panelController.isStealthModeEnabled ? "Stealth açık: ekran paylaşımında gizli" : "Stealth kapalı: ekran paylaşımında görünür")

        Button {
          isKeybindsPopoverPresented.toggle()
        } label: {
          HStack(spacing: 2) {
            Image(systemName: "ellipsis")
              .font(.system(size: 13, weight: .bold))
            Image(systemName: "chevron.down")
              .font(.system(size: 8, weight: .bold))
          }
          .frame(width: 38, height: 24)
        }
        .buttonStyle(TopBarButtonStyle())
        .popover(isPresented: $isKeybindsPopoverPresented, arrowEdge: .bottom) {
          KeybindsPopoverView()
        }
        .help("Keybinds")

        Button {
          Task { @MainActor in
            await appModel.toggleSessionFromBar()
          }
        } label: {
          Image(systemName: appModel.isSessionActive ? "pause.fill" : "play.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
        }
        .buttonStyle(TopBarButtonStyle())
        .help(appModel.isSessionActive ? "Pause Session" : "Start Session")
      }
      .padding(.horizontal, 12)
      .frame(width: FloatingPanelController.barContentSize.width - 16, height: 46)
      .background {
        GlassCapsuleBackground(overlayOpacity: 0.35)
      }
      .contentShape(Capsule())
    }
  }

  private func statusView(now: Date) -> some View {
    HStack(spacing: 7) {
      Circle()
        .fill(appModel.isSessionActive ? .red : .secondary)
        .frame(width: 7, height: 7)
        .shadow(color: appModel.isSessionActive ? .red.opacity(0.7) : .clear, radius: 4)

      VStack(alignment: .leading, spacing: 1) {
        Text(appModel.isSessionActive ? "Recording" : "Paused")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.white.opacity(0.92))

        Text(elapsedText(now: now))
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundStyle(.white.opacity(0.58))
      }
      .fixedSize()
    }
    .frame(minWidth: 74, alignment: .leading)
  }

  private var mainActionsMenu: some View {
    Menu {
      if appModel.isSessionActive {
        Button("End Session") {
          Task { @MainActor in
            await appModel.endSession()
          }
        }
      } else {
        Button("Start Session") {
          Task { @MainActor in
            await appModel.startSession()
          }
        }
      }

      Button(appModel.panelController.isVisible ? "Hide Panel" : "Show Panel") {
        appModel.togglePanel()
      }

      Button("Check Meeting App") {
        appModel.checkForMeetingApp()
      }

      Divider()

      Button("Settings...") {
        appModel.openSettings()
      }

      Button("Sign Out") {
        Task { @MainActor in
          await appModel.signOut()
        }
      }

      Button("Quit Milyonus") {
        NSApplication.shared.terminate(nil)
      }
    } label: {
      Image(systemName: "chevron.down")
        .font(.system(size: 10, weight: .bold))
        .frame(width: 24, height: 24)
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
    .help("Ana menü")
  }

  private func elapsedText(now: Date) -> String {
    guard appModel.isSessionActive,
          let sessionStartedAt = appModel.sessionStartedAt else {
      return "00:00"
    }

    let elapsedSeconds = max(Int(now.timeIntervalSince(sessionStartedAt)), 0)
    let minutes = elapsedSeconds / 60
    let seconds = elapsedSeconds % 60
    return String(format: "%02d:%02d", minutes, seconds)
  }
}

private struct KeybindsPopoverView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Keybinds")
        .font(.system(size: 13, weight: .semibold))

      keybindRow(title: "Ask AI", shortcut: "⌘↵")
      keybindRow(title: "Show / Hide Panel", shortcut: "⌘\\")
      keybindRow(title: "Move Panel", shortcut: "Drag bar")
    }
    .padding(14)
    .frame(width: 220, alignment: .leading)
  }

  private func keybindRow(title: String, shortcut: String) -> some View {
    HStack {
      Text(title)
        .foregroundStyle(.secondary)

      Spacer()

      Text(shortcut)
        .font(.system(.caption, design: .monospaced).weight(.semibold))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background {
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.secondary.opacity(0.14))
        }
    }
    .font(.system(size: 12, weight: .medium))
  }
}

private struct TopBarButtonStyle: ButtonStyle {
  var isPrimary = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(.white.opacity(configuration.isPressed ? 0.72 : 0.94))
      .padding(.horizontal, isPrimary ? 10 : 0)
      .frame(height: 28)
      .background {
        Capsule()
          .fill(isPrimary ? Color.cyan.opacity(configuration.isPressed ? 0.28 : 0.18) : Color.white.opacity(configuration.isPressed ? 0.16 : 0.08))
      }
      .overlay {
        Capsule()
          .stroke(isPrimary ? Color.cyan.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
      }
  }
}
