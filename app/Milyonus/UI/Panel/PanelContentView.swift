import SwiftUI

struct PanelContentView: View {
  @EnvironmentObject private var appModel: AppModel
  @State private var draftQuestion = ""

  var body: some View {
    Group {
      if appModel.panelController.isCollapsed {
        collapsedView
      } else {
        expandedView
      }
    }
    .background(.regularMaterial)
  }

  private var collapsedView: some View {
    Button {
      appModel.collapsePanel()
    } label: {
      Image(systemName: appModel.isSessionActive ? "waveform.circle.fill" : "waveform.circle")
        .font(.system(size: 28, weight: .semibold))
        .frame(width: 72, height: 72)
    }
    .buttonStyle(.plain)
    .help("Paneli genişlet")
  }

  private var expandedView: some View {
    VStack(spacing: 0) {
      header

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          if appModel.assistResponse.isEmpty && !appModel.isAssistStreaming {
            Text("Cmd+Enter ile son konuşmadan öneri al.")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
          } else {
            Text(appModel.assistResponse)
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
          }

          if appModel.isAssistStreaming {
            Text("Düşünüyor...")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          if let error = appModel.assistError {
            Text(error)
              .font(.caption)
              .foregroundStyle(.red)
          }
        }
        .padding(14)
      }

      Divider()

      HStack(spacing: 8) {
        TextField("örn: rakibimiz ne dedi?", text: $draftQuestion)
          .textFieldStyle(.roundedBorder)
          .onSubmit(send)

        Button {
          send()
        } label: {
          Image(systemName: "arrow.up.circle.fill")
        }
        .buttonStyle(.plain)
        .disabled(appModel.isAssistStreaming)
        .help("Soruyu gönder")
      }
      .padding(12)
    }
    .frame(width: 360, height: 480)
  }

  private var header: some View {
    HStack(spacing: 10) {
      RoundedRectangle(cornerRadius: 2)
        .fill(.secondary.opacity(0.5))
        .frame(width: 34, height: 4)

      Text(appModel.isSessionActive ? "Dinleniyor..." : "Duraklatıldı")
        .font(.caption)
        .foregroundStyle(.secondary)

      Spacer()

      Button {
        appModel.collapsePanel()
      } label: {
        Image(systemName: "circle.grid.cross")
      }
      .buttonStyle(.plain)
      .help("Bubble'a küçült")
    }
    .padding(12)
  }

  private func send() {
    let question = draftQuestion
    Task {
      await appModel.requestAssist(question: question)
      await MainActor.run {
        draftQuestion = ""
      }
    }
  }
}

