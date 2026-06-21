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
    }
    .clipShape(Capsule())
    .overlay {
      Capsule()
        .stroke(.white.opacity(0.14), lineWidth: 1)
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
    }
    .clipShape(shape)
    .overlay {
      shape.stroke(.white.opacity(0.12), lineWidth: 1)
    }
  }
}

struct TopBarView: View {
  @EnvironmentObject private var appModel: AppModel

  var onAsk: () -> Void
  var onToggleChat: () -> Void

  var body: some View {
    TimelineView(.periodic(from: Date(), by: 1)) { context in
      HStack(spacing: 10) {
        MilyonusLogoView(size: 22)

        statusView(now: context.date)

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
          appModel.togglePanel()
        } label: {
          Image(systemName: "eye.slash")
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 24, height: 24)
        }
        .buttonStyle(TopBarButtonStyle())
        .keyboardShortcut("\\", modifiers: .command)
        .help("Hide Panel (Cmd+\\)")

        Menu {
          Button("Settings...") {
            appModel.openSettings()
          }

          Divider()

          Button("Ask AI: Cmd+Enter") {}
            .disabled(true)
          Button("Hide/Show: Cmd+\\") {}
            .disabled(true)
        } label: {
          Image(systemName: "ellipsis")
            .font(.system(size: 13, weight: .bold))
            .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()

        Button {
          Task { @MainActor in
            if appModel.isSessionActive {
              await appModel.endSession()
            } else {
              await appModel.startSession()
            }
          }
        } label: {
          Image(systemName: appModel.isSessionActive ? "stop.fill" : "play.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(appModel.isSessionActive ? .red : .white)
            .frame(width: 24, height: 24)
        }
        .buttonStyle(TopBarButtonStyle())
        .help(appModel.isSessionActive ? "Stop Session" : "Start Session")
      }
      .padding(.horizontal, 12)
      .frame(minWidth: 300, maxWidth: 420, minHeight: 46)
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
