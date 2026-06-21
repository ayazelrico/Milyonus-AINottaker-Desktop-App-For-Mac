import AppKit
import SwiftUI

struct PanelContentView: View {
  @EnvironmentObject private var appModel: AppModel

  private let bottomAnchorID = "chat-bottom-anchor"

  private var showsChatPanel: Bool {
    !appModel.panelController.isCollapsed
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
      messageList

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

  private var messageList: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 12) {
          if appModel.messages.isEmpty {
            emptyChatView
          }

          ForEach(appModel.messages) { message in
            messageBubble(for: message)
              .id(message.id)
          }

          if let error = appModel.panelErrorMessage {
            Text(error)
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(.red.opacity(0.92))
              .frame(maxWidth: .infinity, alignment: .leading)
              .id("chat-error")
          }

          Color.clear
            .frame(height: 1)
            .id(bottomAnchorID)
        }
        .padding(.trailing, 2)
      }
      .frame(height: 310)
      .onAppear {
        scrollToBottom(proxy)
      }
      .onChange(of: appModel.messages) { _ in
        scrollToBottom(proxy)
      }
      .onChange(of: appModel.panelErrorMessage) { _ in
        scrollToBottom(proxy)
      }
    }
  }

  private var emptyChatView: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        MilyonusLogoView(size: 18)

        Text("Milyonus hazır.")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.white.opacity(0.86))
      }
    }
    .padding(.vertical, 8)
  }

  private func messageBubble(for message: ChatMessage) -> some View {
    HStack(alignment: .bottom, spacing: 8) {
      if message.role == .user {
        Spacer(minLength: 72)
      }

      VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
        if message.role == .assistant {
          HStack(spacing: 8) {
            MilyonusLogoView(size: 16)

            Text("Milyonus")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(.white.opacity(0.68))

            if appModel.isAssistStreaming && message.id == appModel.messages.last?.id {
              ProgressView()
                .controlSize(.small)
                .scaleEffect(0.55)
            }
          }
        }

        Text(displayText(for: message))
          .font(.system(size: 13, weight: .regular))
          .lineSpacing(4)
          .foregroundStyle(.white.opacity(0.94))
          .textSelection(.enabled)
          .padding(.horizontal, 12)
          .padding(.vertical, 9)
          .background {
            messageBubbleBackground(for: message.role)
          }
      }

      if message.role == .assistant {
        Spacer(minLength: 72)
      }
    }
    .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
  }

  private func displayText(for message: ChatMessage) -> String {
    if message.role == .assistant && message.content.isEmpty {
      return "Yanıt hazırlanıyor..."
    }

    return message.content
  }

  private func messageBubbleBackground(for role: ChatMessage.Role) -> some View {
    RoundedRectangle(cornerRadius: 14, style: .continuous)
      .fill(
        role == .user
          ? AnyShapeStyle(
            LinearGradient(
              colors: [.cyan.opacity(0.44), .blue.opacity(0.62)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          : AnyShapeStyle(Color.white.opacity(0.08))
      )
      .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(.white.opacity(role == .user ? 0.18 : 0.10), lineWidth: 1)
      }
  }

  private var actionChips: some View {
    HStack(spacing: 8) {
      // TODO: /api/assist currently accepts the latest question only; dedicated backend
      // prompt templates can replace these UI prompts once message history is supported.
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
    HStack(alignment: .bottom, spacing: 8) {
      ZStack(alignment: .topLeading) {
        ChatComposerTextView(
          text: $appModel.pendingQuestion,
          isEnabled: !appModel.isAssistStreaming,
          onSubmit: submitPendingQuestion
        )
        .frame(minHeight: 38, maxHeight: 76)

        if appModel.pendingQuestion.isEmpty {
          Text("örn: rakibimiz ne dedi?")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.42))
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .allowsHitTesting(false)
        }
      }
      .padding(.horizontal, 1)
      .frame(minHeight: 38, maxHeight: 76)
      .background {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(.black.opacity(0.28))
          .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .stroke(.white.opacity(0.10), lineWidth: 1)
          }
      }

      Button(action: submitPendingQuestion) {
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
    appModel.openChatPanel()

    guard !trimmedQuestion.isEmpty else { return }

    send(question: trimmedQuestion)
  }

  private func toggleChat() {
    if appModel.panelController.isCollapsed {
      appModel.panelController.expandChat()
    } else {
      appModel.panelController.collapseChat()
    }

    updateWindowLayout()
  }

  private func submitPendingQuestion() {
    send(question: appModel.pendingQuestion)
  }

  private func send(question: String) {
    guard !appModel.isAssistStreaming else { return }

    let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
    appModel.openChatPanel()

    Task { @MainActor in
      await appModel.requestAssist(question: trimmedQuestion)
    }
  }

  private func updateWindowLayout() {
    appModel.panelController.setChatPanelVisible(showsChatPanel)
  }

  private func scrollToBottom(_ proxy: ScrollViewProxy) {
    DispatchQueue.main.async {
      withAnimation(.easeOut(duration: 0.18)) {
        proxy.scrollTo(bottomAnchorID, anchor: .bottom)
      }
    }
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

private struct ChatComposerTextView: NSViewRepresentable {
  @Binding var text: String
  var isEnabled: Bool
  var onSubmit: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text, onSubmit: onSubmit)
  }

  func makeNSView(context: Context) -> NSScrollView {
    let textView = SubmitTextView()
    textView.delegate = context.coordinator
    textView.onSubmit = context.coordinator.submit
    textView.isRichText = false
    textView.importsGraphics = false
    textView.drawsBackground = false
    textView.backgroundColor = .clear
    textView.textColor = NSColor.white.withAlphaComponent(0.92)
    textView.insertionPointColor = .white
    textView.font = NSFont.systemFont(ofSize: 13, weight: .medium)
    textView.textContainerInset = NSSize(width: 11, height: 8)
    textView.textContainer?.widthTracksTextView = true
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = [.width]
    textView.string = text

    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.documentView = textView
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    context.coordinator.text = $text
    context.coordinator.onSubmit = onSubmit

    guard let textView = scrollView.documentView as? SubmitTextView else { return }

    textView.onSubmit = context.coordinator.submit
    textView.isEditable = isEnabled
    textView.textColor = NSColor.white.withAlphaComponent(isEnabled ? 0.92 : 0.45)

    if textView.string != text {
      textView.string = text
    }
  }

  final class Coordinator: NSObject, NSTextViewDelegate {
    var text: Binding<String>
    var onSubmit: () -> Void

    init(text: Binding<String>, onSubmit: @escaping () -> Void) {
      self.text = text
      self.onSubmit = onSubmit
    }

    func submit() {
      onSubmit()
    }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      text.wrappedValue = textView.string
    }
  }
}

private final class SubmitTextView: NSTextView {
  var onSubmit: (() -> Void)?

  override func keyDown(with event: NSEvent) {
    let isReturn = event.keyCode == 36 || event.keyCode == 76
    let isShiftPressed = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift)

    if isReturn && !isShiftPressed {
      onSubmit?()
      return
    }

    super.keyDown(with: event)
  }
}
