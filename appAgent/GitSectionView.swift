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
  case pushing(progress: String)
  //Abschluss
  case success
  case error(String)
}

struct GitSectionView: View {
  
  @ObservedObject var project: ProjectEngine
  @State private var engine: GitEngine
  init(project: ProjectEngine) {
    self.project = project
    self.engine = GitEngine(project: project)
  }
  
  @State private var showingAppSettings: Bool = false
  @State private var showingGitSettings: Bool = false
  
  var body: some View {
    VStack(alignment: .center, spacing: 12) {
      Text("GitHub-Integration")
        .font(.headline)
      Button("Push auf GitHub") {
        Task {
          await engine.performPush()
        }
      }
      .buttonStyle(.borderedProminent)
      .disabled(isBusy)
      statusSection
      actionSection
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(18)
    .sheet(isPresented: $showingAppSettings) {
      SettingsView()
    }
    .sheet(isPresented: $showingGitSettings) {
      GitSettingsSheet(projectFolder: project.projectFolder)
    }
  }
  
  private var isBusy: Bool {
    switch engine.status {
      case .checkingRepo, .creatingRepo, .pushing: return true
      default: return false
    }
  }
  
  private var statusColor: Color {
    switch engine.status {
      case .unauthorized, .forbidden, .error: return .red
      case .repoExists: return .orange
      case .success: return .green
      default: return .blue
    }
  }
  
  private var statusSection: some View {
    VStack(alignment: .center, spacing: 12) {
      switch engine.status {
        case .idle:
          EmptyView()
        case .missingCredentials:
          VStack {
            Text("⚙️ GitHub-Konfiguration erforderlich")
            Text("Bitte Token und Owner in den App-Einstellungen angeben.")
              .font(.caption)
          }
        case .unauthorized:
          VStack {
            Text("❌ Ungültiger GitHub-Token")
            Text("Der gespeicherte Token ist ungültig oder abgelaufen. Bitte in den App-Einstellungen überprüfen.")
              .font(.caption)
          }
          //.foregroundColor(.red)
        case .forbidden:
          VStack {
            Text("⛔ Keine Berechtigung")
            Text("Der Token hat keine (ausreichenden) Rechte für dieses Repository. Bitte Token und Owner in den App-Einstellungen prüfen.")
              .font(.caption)
          }
          //.foregroundColor(.red)
        case .repoExists:
          VStack {
            Text("⚠️ Repository existiert bereits")
            Text("Für dieses Projekt ist bereits ein GitHub-Repository vorhanden. Möchtest du es überschreiben?")
              .font(.caption)
          }
          //.foregroundColor(.orange)
        case .needsGitSettings:
          VStack {
            Text("⚙️ Repository-Konfiguration erforderlich")
            Text("Public/Private und Ziel-Branch müssen noch festgelegt werden, bevor ein Push möglich ist.")
              .font(.caption)
          }
        case .checkingRepo:
          HStack {
            ProgressView()
            Text("Prüfe Repository…")
          }
        default:
          Text("⚠️ Unbehandelter Status: \(String(describing: engine.status))")
            .foregroundColor(.purple)
      }
    }
    //.foregroundColor(.blue)
    .foregroundColor(statusColor)
    .multilineTextAlignment(.center)
    .padding(.horizontal)
  }
  
  private var actionSection: some View {
    VStack(alignment: .center, spacing: 12) {
      switch engine.status {
        case .missingCredentials, .unauthorized, .forbidden:
          Button("App-Settings öffnen") {
            showingAppSettings = true
          }
        case .needsGitSettings:
          Button("Repo-Settings öffnen") {
            showingGitSettings = true
          }
        case .repoExists:
          Button("Repository überschreiben") {
            engine.setOverwriteConfirmed(true)
            Task {
              await engine.performPush()
            }
          }
        default: EmptyView()
      }
    }
    .buttonStyle(.bordered)
  }
  
}
