import SwiftUI

struct PanelContentView: View {
  @EnvironmentObject private var appModel: AppModel
  @State private var lastSubmittedQuestion: String?

  private var hasChatContent: Bool {
    appModel.isAssistStreaming ||
      !appModel.assistResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
      lastSubmittedQuestion != nil ||
      appModel.panelErrorMessage != nil
  }

  private var showsChatPanel: Bool {
    hasChatContent && !appModel.panelController.isCollapsed
  }

  var body: some View {
    VStack(spacing: 10) {
      TopBarView(
        onAsk: askAI,
        onToggleChat: toggleChat
      )
      .environmentObject(appModel)
      .frame(maxWidth: .infinity)

      if showsChatPanel {
        chatPanel
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .padding(.top, 2)
    .padding(.horizontal, 8)
    .padding(.bottom, showsChatPanel ? 8 : 2)
    .frame(
      width: showsChatPanel ? FloatingPanelController.chatContentSize.width : FloatingPanelController.barContentSize.width,
      height: showsChatPanel ? FloatingPanelController.chatContentSize.height : FloatingPanelController.barContentSize.height,
      alignment: .top
    )
    .background(Color.clear)
    .animation(.easeOut(duration: 0.25), value: showsChatPanel)
    .onAppear(perform: updateWindowLayout)
    .onChange(of: showsChatPanel) { _ in
      updateWindowLayout()
    }
  }

  private var chatPanel: some View {
    VStack(alignment: .leading, spacing: 14) {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          if let lastSubmittedQuestion {
            HStack {
              Spacer(minLength: 48)

              Text(lastSubmittedQuestion)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background {
                  RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                      LinearGradient(
                        colors: [.cyan.opacity(0.45), .blue.opacity(0.62)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      )
                    )
                }
                .textSelection(.enabled)
            }
          }

          aiResponseView

          if let error = appModel.panelErrorMessage {
            Text(error)
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(.red.opacity(0.92))
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .padding(.trailing, 2)
      }
      .frame(maxHeight: 230)

      actionChips

      composer
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      GlassRoundedBackground(cornerRadius: 18, overlayOpacity: 0.55)
    }
    .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
  }

  private var aiResponseView: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        MilyonusLogoView(size: 18)

        Text("Milyonus")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.white.opacity(0.8))

        if appModel.isAssistStreaming {
          ProgressView()
            .controlSize(.small)
            .scaleEffect(0.62)
        }
      }

      if appModel.assistResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Text(appModel.isAssistStreaming ? "Yanıt hazırlanıyor..." : "Cmd+Enter ile son konuşmadan öneri al.")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.white.opacity(0.58))
      } else {
        Text(appModel.assistResponse)
          .font(.system(size: 13, weight: .regular))
          .lineSpacing(4)
          .foregroundStyle(.white.opacity(0.94))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  private var actionChips: some View {
    HStack(spacing: 8) {
      // TODO: Dedicated backend prompt templates can replace these UI-only modes later.
      ForEach(assistChips, id: \.self) { chip in
        Button {
          send(question: chip.prompt)
        } label: {
          Text(chip.title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.84))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background {
              Capsule()
                .fill(.white.opacity(0.08))
            }
        }
        .buttonStyle(.plain)
        .disabled(appModel.isAssistStreaming)
      }
    }
  }

  private var composer: some View {
    HStack(spacing: 8) {
      TextField("örn: rakibimiz ne dedi?", text: $appModel.pendingQuestion)
        .textFieldStyle(.plain)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background {
          Capsule()
            .fill(.black.opacity(0.28))
            .overlay {
              Capsule()
                .stroke(.white.opacity(0.10), lineWidth: 1)
            }
        }
        .onSubmit {
          send(question: appModel.pendingQuestion)
        }

      Button {
        send(question: appModel.pendingQuestion)
      } label: {
        Image(systemName: "arrow.up")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: 34, height: 34)
          .background {
            Circle()
              .fill(Color.cyan.opacity(appModel.isAssistStreaming ? 0.22 : 0.42))
          }
      }
      .buttonStyle(.plain)
      .disabled(appModel.isAssistStreaming)
      .help("Soruyu gönder")
    }
  }

  private func askAI() {
    let trimmedQuestion = appModel.pendingQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
    lastSubmittedQuestion = trimmedQuestion.isEmpty ? nil : trimmedQuestion
    appModel.panelController.expandChat()

    Task { @MainActor in
      await appModel.triggerAssistFromHotkey()
    }
  }

  private func toggleChat() {
    if appModel.panelController.isCollapsed {
      appModel.panelController.expandChat()
    } else {
      appModel.panelController.collapseChat()
    }

    updateWindowLayout()
  }

  private func send(question: String) {
    let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
    lastSubmittedQuestion = trimmedQuestion.isEmpty ? nil : trimmedQuestion
    appModel.panelController.expandChat()

    Task { @MainActor in
      await appModel.requestAssist(question: trimmedQuestion)
    }
  }

  private func updateWindowLayout() {
    appModel.panelController.setChatPanelVisible(showsChatPanel)
  }

  private var assistChips: [AssistChip] {
    [
      AssistChip(title: "Assist", prompt: ""),
      AssistChip(title: "What should I say?", prompt: "What should I say next?"),
      AssistChip(title: "Follow-up questions", prompt: "Suggest follow-up questions."),
      AssistChip(title: "Recap", prompt: "Recap the meeting so far.")
    ]
  }
}

private struct AssistChip: Hashable {
  let title: String
  let prompt: String
}
