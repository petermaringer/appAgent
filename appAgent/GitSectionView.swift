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
  @State private var statusMessage: String = ""
  @State private var showingAppSettings: Bool = false
  @State private var showingGitSettings: Bool = false
  
  @AppStorage("githubToken") private var token: String = ""
  @AppStorage("githubOwner") private var owner: String = ""
  
  var body: some View {
    VStack(alignment: .center, spacing: 12) {
      Text("GitHub-Integration")
        .font(.headline)
      Button("Push auf GitHub") {
        startPush()
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
    switch status {
      case .checkingRepo, .creatingRepo, .pushing:
        return true
      default:
        return false
    }
  }
  
  //@ViewBuilder
  private var statusSection: some View {
    VStack {
    switch status {
      case .idle:
        EmptyView()
      case .missingCredentials:
        VStack {
          Text("⚠️ Fehlende GitHub-Credentials")
          Text("Bitte Token und Owner in den App-Einstellungen angeben")
            .font(.caption)
        }
        .foregroundColor(.red)
      case .checkingRepo:
        HStack {
          ProgressView()
          Text("Prüfe Repository…")
            //.foregroundColor(.blue)
        }
      default:
        Text("⚠️ Unbehandelter Status: \(status)")
          .foregroundColor(.orange)
    }
    }
    .foregroundColor(.blue)
  }
  
  private var actionSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      switch status {
        case .missingCredentials, .unauthorized, .forbidden:
          Button("App-Settings öffnen") {
            showingAppSettings = true
          }
          //.buttonStyle(.bordered)
        case .needsGitSettings:
          Button("Git-Settings öffnen") {
            showingGitSettings = true
          }
          //.buttonStyle(.bordered)
        default:
          EmptyView()
      }
    }
    .buttonStyle(.bordered)
  }
  
  private func startPush() {
    guard !token.isEmpty, !owner.isEmpty else {
      status = .missingCredentials
      return
    }
    status = .checkingRepo
  }
  
}
