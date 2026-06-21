import Foundation
import AppKit
import Combine

@MainActor
final class AppModel: ObservableObject {
  @Published var isSessionActive = false
  @Published var currentSessionID: UUID?
  @Published var statusMessage = "Hazır"
  @Published var assistResponse = ""
  @Published var isAssistStreaming = false
  @Published var assistError: String?
  @Published var pendingQuestion = ""
  @Published var messages: [ChatMessage] = []
  @Published var languagePreference: LanguagePreference = .auto
  @Published var backendConnectionStatus: String?
  @Published var sessionStartedAt: Date?

  let authService: AuthServiceProtocol
  let permissionsManager = PermissionsManager()
  let audioCapture = AudioCaptureCoordinator()
  let transcriptBuffer = TranscriptBufferManager()
  let panelController = FloatingPanelController()
  let meetingDetector = MeetingAppDetector()

  private let hotkeyManager = HotkeyManager()
  private lazy var transcriptSyncService = TranscriptSyncService(authService: authService)
  private lazy var transcriptionCoordinator = TranscriptionCoordinator(
    audioCaptureCoordinator: audioCapture,
    authService: authService,
    transcriptBuffer: transcriptBuffer,
    syncService: transcriptSyncService
  )
  private lazy var assistService = AssistRequestService(
    authService: authService,
    transcriptBuffer: transcriptBuffer
  )
  private var runtimeStarted = false

  var panelErrorMessage: String? {
    audioCapture.captureError ?? assistError
  }

  private lazy var backendConnectionTester = BackendConnectionTester(authService: authService)

  init(authService: AuthServiceProtocol = AuthServiceFactory.make()) {
    self.authService = authService
    transcriptionCoordinator.onFatalError = { [weak self] message in
      Task { @MainActor in
        self?.handleTranscriptionFatalError(message)
      }
    }
  }

  func startRuntimeIfNeeded() {
    guard !runtimeStarted else { return }
    runtimeStarted = true

    panelController.install(appModel: self)

    hotkeyManager.start(
      onAssist: { [weak self] in
        Task { @MainActor in
          await self?.triggerAssistFromHotkey()
        }
      },
      onTogglePanel: { [weak self] in
        Task { @MainActor in
          self?.panelController.toggleFlashReveal()
        }
      }
    )

    permissionsManager.refreshMicrophoneStatus()
    checkForMeetingApp()
  }

  func startSession() async {
    guard !isSessionActive else { return }

    #if DEBUG
      // Dev mode: login kontrolü atlanıyor.
    #else
      let isAuthenticated = await authService.getCurrentSession() != nil

      guard isAuthenticated else {
        print("[Session] Not authenticated, skipping in release")
        return
      }
    #endif

    guard await requestMissingPermissionsForSessionStart() else {
      return
    }

    let sessionID = UUID()
    currentSessionID = sessionID
    transcriptSyncService.configure(sessionID: sessionID)

    do {
      try await transcriptionCoordinator.start(sessionID: sessionID, language: languagePreference)
      isSessionActive = true
      sessionStartedAt = Date()
      statusMessage = "Dinleniyor..."
      panelController.show()
    } catch {
      currentSessionID = nil
      sessionStartedAt = nil
      statusMessage = "Başlatılamadı"
      assistError = runtimeErrorMessage(for: error)
      panelController.show()
    }
  }

  private func requestMissingPermissionsForSessionStart() async -> Bool {
    permissionsManager.refreshMicrophoneStatus()

    let hasScreenRecordingPermission = await permissionsManager.checkScreenRecordingStatus()
    if !hasScreenRecordingPermission {
      statusMessage = "Ekran kaydı izni isteniyor..."
      await permissionsManager.requestScreenRecordingViaScreenCaptureKit()

      let retryCheck = await permissionsManager.checkScreenRecordingStatus()
      guard retryCheck else {
        print("[Permissions] Screen Recording still missing after request")
        statusMessage = "Ekran kaydı izni gerekli"
        return false
      }
    }

    if !permissionsManager.microphoneGranted {
      statusMessage = "Mikrofon izni isteniyor..."
      await permissionsManager.requestMicrophone()
    }

    permissionsManager.refreshMicrophoneStatus()

    if !permissionsManager.microphoneGranted {
      statusMessage = "Mikrofon izni gerekli"
      permissionsManager.openMicrophoneSettings()
      return false
    }

    return true
  }

  func endSession() async {
    guard isSessionActive else { return }

    await transcriptionCoordinator.stop()
    await transcriptSyncService.flush()

    isSessionActive = false
    statusMessage = "Duraklatıldı"
    currentSessionID = nil
    sessionStartedAt = nil
  }

  func signOut() async {
    do {
      try await authService.signOut()
      await endSession()
      statusMessage = "Çıkış yapıldı"
    } catch {
      assistError = error.localizedDescription
    }
  }

  func signInWithGoogle() async {
    do {
      try await authService.signInWithGoogle()
      statusMessage = "Google OAuth tamamlandı"
    } catch {
      assistError = error.localizedDescription
    }
  }

  func handleAuthCallback(_ url: URL) async {
    do {
      try await authService.handleAuthCallback(url)
      statusMessage = "Giriş tamamlandı"
    } catch {
      assistError = error.localizedDescription
    }
  }

  func testBackendConnection() async {
    backendConnectionStatus = "Test ediliyor..."
    backendConnectionStatus = await backendConnectionTester.testUsageEndpoint()
  }

  func triggerAssistFromHotkey() async {
    panelController.show()
    await requestAssist(question: pendingQuestion)
  }

  func toggleSessionFromBar() async {
    if isSessionActive {
      await endSession()
    } else {
      await startSession()
    }
  }

  func openChatPanel() {
    panelController.show()
    panelController.expandChat()
  }

  func requestAssist(question: String?) async {
    panelController.show()
    panelController.expandChat()

    guard !isAssistStreaming else { return }

    let trimmedQuestion = question?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let userDisplayText = trimmedQuestion.isEmpty ? "Assist" : trimmedQuestion
    messages.append(ChatMessage(role: .user, content: userDisplayText))
    pendingQuestion = ""

    guard let sessionID = currentSessionID else {
      assistError = "Önce bir oturum başlat."
      return
    }

    assistResponse = ""
    assistError = nil
    isAssistStreaming = true
    let assistantMessageID = UUID()
    messages.append(ChatMessage(id: assistantMessageID, role: .assistant, content: ""))

    do {
      // TODO: /api/assist currently accepts only the latest user_question. Keep the
      // full local chat thread here until the backend accepts conversation history.
      try await assistService.streamAssist(
        sessionID: sessionID,
        question: trimmedQuestion,
        language: languagePreference
      ) { [weak self] delta in
        self?.appendAssistantDelta(delta, to: assistantMessageID)
      }
      pendingQuestion = ""
    } catch {
      assistError = error.localizedDescription
      replaceAssistantMessage(
        id: assistantMessageID,
        content: "Yanıt alınamadı: \(error.localizedDescription)"
      )
    }

    isAssistStreaming = false
  }

  private func appendAssistantDelta(_ delta: String, to messageID: UUID) {
    assistResponse += delta

    guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }

    var updatedMessages = messages
    updatedMessages[index].content += delta
    messages = updatedMessages
  }

  private func replaceAssistantMessage(id messageID: UUID, content: String) {
    guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }

    var updatedMessages = messages
    updatedMessages[index].content = content
    messages = updatedMessages
  }

  func panelStateDidChange() {
    objectWillChange.send()
  }

  func togglePanel() {
    panelController.toggle()
  }

  func collapsePanel() {
    panelController.toggleCollapsed()
  }

  func openSettings() {
    // The app still targets macOS 13, so use the AppKit settings action instead of
    // SwiftUI's newer openSettings environment action.
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func checkForMeetingApp() {
    if let app = meetingDetector.frontmostMeetingApp() {
      statusMessage = "\(app.displayName) algılandı. Başlatmak ister misin?"
    }
  }

  private func handleTranscriptionFatalError(_ message: String) {
    assistError = message
    statusMessage = "Duraklatıldı"
    isSessionActive = false
    currentSessionID = nil
    sessionStartedAt = nil
    panelController.show()
  }

  private func runtimeErrorMessage(for error: Error) -> String {
    if error is DeepgramStreamingError {
      return "Backend bağlantı hatası. Lütfen tekrar giriş yap."
    }

    if error is AudioCaptureError {
      return "Ses yakalama hatası. Sistem ses ayarlarını kontrol et."
    }

    return error.localizedDescription
  }
}
