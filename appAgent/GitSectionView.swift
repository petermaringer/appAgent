import SwiftUI

enum GitStatus {
  case idle
  // Setup-Probleme
  case missingCredentials
  case unauthorized
  case forbidden
  case repoExists
  case needsGitSettings
  // Laufend
  case checkingRepo
  case creatingRepo
  case pushing(progress: String)
  // Abschluss
  case success
  case error(String)
}

struct GitSectionView: View {
  @ObservedObject var project: ProjectEngine
  @State private var status: GitStatus = .idle
  //@State private var statusMessage: String = ""
  @State private var showingAppSettings: Bool = false
  @State private var showingGitSettings: Bool = false
  
  /*final class GitShared { var overwriteConfirmed: Bool = false }
  @State private var gitShared = GitShared()*/
  //private let engine = GitEngine()
  //private let engine = GitEngine(project: project)
  //private lazy var engine = GitEngine(project: project)
  private let engine: GitEngine

init(project: ProjectEngine) {
  self.project = project
  self.engine = GitEngine(project: project)
  /*self.engine.onStatusChange = { newStatus in
    status = newStatus
  }*/
}
  
  /*@AppStorage("githubToken") private var token: String = ""
  @AppStorage("githubOwner") private var owner: String = ""*/
  
  var body: some View {
    VStack(alignment: .center, spacing: 12) {
      Text("GitHub-Integration")
        .font(.headline)
      Button("Push auf GitHub") {
        //startPush()
        Task {
          //status = await engine.performPush()
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
    .onAppear {
      Task { @MainActor in
        await engine.setOnStatusChange { newStatus in
          status = newStatus
        }
      }
      /*engine.onStatusChange = { newStatus in
        status = newStatus
      }*/
    }
  }
  
  private var isBusy: Bool {
    switch status {
      case .checkingRepo, .creatingRepo, .pushing:
        return true
      default:
        return false
    }
  }
  
  private var statusSection: some View {
    VStack {
      switch status {
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
          .foregroundColor(.red)
        case .forbidden:
          VStack {
            Text("⛔ Keine Berechtigung")
            Text("Der Token hat keine (ausreichenden) Rechte für dieses Repository. Bitte Token und Owner in den App-Einstellungen prüfen.")
              .font(.caption)
          }
          .foregroundColor(.red)
        case .repoExists:
          VStack {
            Text("⚠️ Repository existiert bereits")
            Text("Für dieses Projekt ist bereits ein GitHub-Repository vorhanden. Möchtest du es überschreiben?")
              .font(.caption)
          }
          .foregroundColor(.orange)
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
          Text("⚠️ Unbehandelter Status: \(String(describing: status))")
            .foregroundColor(.orange)
      }
    }
    .foregroundColor(.blue)
    .multilineTextAlignment(.center)
    .padding(.horizontal)
  }
  
  private var actionSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      switch status {
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
            //gitShared.overwriteConfirmed = true
            //startPush()
            Task {
              //await engine.overwriteConfirmed = true
              await engine.setOverwriteConfirmed(true)
              //status = await engine.performPush()
              await engine.performPush()
            }
          }
        default:
          EmptyView()
      }
    }
    .buttonStyle(.bordered)
  }
  
  /*private func randomStatus() -> GitStatus {
    let allCases: [GitStatus] = [.idle, .unauthorized, .forbidden, .repoExists, .needsGitSettings, .checkingRepo, .creatingRepo, .pushing(progress: "42%"), .success, .error("Testfehler")]
    return allCases.randomElement()!
  }
  
  private func startPush() {
    guard !token.isEmpty, !owner.isEmpty else {
      status = .missingCredentials
      return
    }
    //status = .checkingRepo
    status = randomStatus()
  }*/
  
}
