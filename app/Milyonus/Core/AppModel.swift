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
  @Published var languagePreference: LanguagePreference = .auto

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
    transcriptBuffer: transcriptBuffer,
    syncService: transcriptSyncService
  )
  private lazy var assistService = AssistRequestService(
    authService: authService,
    transcriptBuffer: transcriptBuffer
  )
  private var runtimeStarted = false

  var menuBarSystemImage: String {
    if isSessionActive {
      return "waveform.circle.fill"
    }

    return "waveform.circle"
  }

  init(authService: AuthServiceProtocol = MockAuthService()) {
    self.authService = authService
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

    permissionsManager.refresh()
    checkForMeetingApp()
  }

  func startSession() async {
    guard !isSessionActive else { return }

    permissionsManager.refresh()

    guard permissionsManager.screenRecordingGranted else {
      statusMessage = "Ekran kaydı izni gerekli"
      return
    }

    guard permissionsManager.microphoneGranted else {
      statusMessage = "Mikrofon izni gerekli"
      return
    }

    let sessionID = UUID()
    currentSessionID = sessionID
    transcriptSyncService.configure(sessionID: sessionID)

    do {
      try await transcriptionCoordinator.start(sessionID: sessionID, language: languagePreference)
      isSessionActive = true
      statusMessage = "Dinleniyor..."
      panelController.show()
    } catch {
      currentSessionID = nil
      statusMessage = "Başlatılamadı"
      assistError = error.localizedDescription
    }
  }

  func endSession() async {
    guard isSessionActive else { return }

    await transcriptionCoordinator.stop()
    await transcriptSyncService.flush()

    isSessionActive = false
    statusMessage = "Duraklatıldı"
    currentSessionID = nil
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

  func triggerAssistFromHotkey() async {
    panelController.show()
    await requestAssist(question: pendingQuestion)
  }

  func requestAssist(question: String?) async {
    guard let sessionID = currentSessionID else {
      assistError = "Önce bir oturum başlat."
      return
    }

    assistResponse = ""
    assistError = nil
    isAssistStreaming = true

    do {
      try await assistService.streamAssist(
        sessionID: sessionID,
        question: question?.trimmingCharacters(in: .whitespacesAndNewlines),
        language: languagePreference
      ) { [weak self] delta in
        self?.assistResponse += delta
      }
      pendingQuestion = ""
    } catch {
      assistError = error.localizedDescription
    }

    isAssistStreaming = false
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
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func checkForMeetingApp() {
    if let app = meetingDetector.frontmostMeetingApp() {
      statusMessage = "\(app.displayName) algılandı. Başlatmak ister misin?"
    }
  }
}
