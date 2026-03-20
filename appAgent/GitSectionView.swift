import SwiftUI

enum GitStatus: Equatable {
  case idle
  //Setup-Probleme
  case missingCredentials
  case unauthorized
  case forbidden
  case repoExists
  case needsGitSettings
  //Laufend
  case checkingRepo
  case creatingRepo
  case pushing(progress: Double)
  //Abschluss
  case success
  case error(String)
}

struct GitSectionView: View {
  
  @ObservedObject var project: ProjectEngine
  @State private var git: GitEngine
  init(project: ProjectEngine) {
    self.project = project
    self.git = GitEngine(project: project)
  }
  
  @State private var showingAppSettings: Bool = false
  @State private var showingGitSettings: Bool = false
  
  var body: some View {
    VStack(alignment: .center, spacing: 12) {
      Text("GitHub-Integration")
        .font(.headline)
      Button("Push auf GitHub") {
        Task {
          await git.performPush()
        }
      }
      .buttonStyle(.borderedProminent)
      .disabled(isBusy)
      statusSection
      actionSection
    }
    //.frame(maxWidth: .infinity)
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(18)
    .frame(maxWidth: .infinity, alignment: .center)
    .sheet(isPresented: $showingAppSettings) {
      SettingsView()
    }
    .sheet(isPresented: $showingGitSettings) {
      GitSettingsSheet(project: project)
    }
  }
  
  private var isBusy: Bool {
    switch git.status {
      case .checkingRepo, .creatingRepo, .pushing: return true
      default: return false
    }
  }
  
  private var statusColor: Color {
    switch git.status {
      case .unauthorized, .forbidden, .error: return .red
      case .repoExists: return .orange
      case .success: return .green
      default: return .blue
    }
  }
  
  private func statusTextBlock(title: String, subtitle: String) -> some View {
    VStack(alignment: .center, spacing: 6) {
      Text(title)
      Text(subtitle)
        .font(.caption)
    }
  }
  
  private var statusSection: some View {
    VStack(alignment: .center, spacing: 12) {
      switch git.status {
        case .idle:
          EmptyView()
        case .missingCredentials:
          statusTextBlock(title: "⚙️ GitHub-Konfiguration erforderlich",
                          subtitle: "Bitte Token und Owner in den App-Einstellungen angeben.")
        case .unauthorized:
          statusTextBlock(title: "❌ Ungültiger GitHub-Token",
                          subtitle: "Der gespeicherte Token ist ungültig oder abgelaufen. Bitte in den App-Einstellungen überprüfen.")
        case .forbidden:
          statusTextBlock(title: "⛔ Keine Berechtigung",
                          //subtitle: "Der Token hat keine (ausreichenden) Rechte für dieses Repository. Bitte Token und Owner prüfen.")
                          subtitle: "Der Token hat keine (ausreichenden) Rechte für dieses Repository. Bitte Token und Owner in den App-Einstellungen prüfen.")
        case .repoExists:
          statusTextBlock(title: "⚠️ Repository existiert bereits",
                          subtitle: "Für dieses Projekt ist bereits ein GitHub-Repository vorhanden. Möchtest du es überschreiben?")
        case .needsGitSettings:
          statusTextBlock(title: "⚙️ Repository-Konfiguration erforderlich",
                          subtitle: "Public/Private und Ziel-Branch müssen noch festgelegt werden, bevor ein Push möglich ist.")
        case .error(let message):
          statusTextBlock(title: "❌ Fehler",
                          subtitle: message)
        case .success:
          statusTextBlock(title: "✅ Push erfolgreich",
                          subtitle: "Das Projekt wurde erfolgreich auf GitHub hochgeladen.")
        case .checkingRepo:
          HStack {
            ProgressView()
              .tint(statusColor)
            Text("Prüfe Repository…")
          }
        case .pushing(let progress):
          HStack {
            ProgressView(value: progress)
              .tint(statusColor)
            Text("\(Int(progress * 100)) %")
          }
        default:
          Text("⚠️ Unbehandelter Status: \(String(describing: git.status))")
            .foregroundColor(.purple)
      }
    }
    .foregroundColor(statusColor)
    .multilineTextAlignment(.center)
    .padding(.horizontal)
  }
  
  private var actionSection: some View {
    VStack(alignment: .center, spacing: 12) {
      switch git.status {
        case .missingCredentials, .unauthorized, .forbidden:
          Button("App-Settings öffnen") {
            showingAppSettings = true
          }
        case .needsGitSettings:
          Button("Repo-Settings öffnen") {
            showingGitSettings = true
            //Task {
              //try? await UIApplication.shared.setAlternateIconName(nil)
            //}
          }
        case .repoExists:
          Button("Repository überschreiben") {
            git.setOverwriteConfirmed(true)
            Task {
              await git.performPush()
              //try? await UIApplication.shared.setAlternateIconName("Alt1")
            }
          }
        default: EmptyView()
      }
    }
    .buttonStyle(.bordered)
  }
  
}
