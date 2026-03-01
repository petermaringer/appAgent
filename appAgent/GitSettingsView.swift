import SwiftUI

struct GitSettingsSheet: View {
  @ObservedObject var project: ProjectEngine
  let projectFolder: URL
  var onFinished: ((Bool) -> Void)?   // true = gespeichert
  
  @AppStorage("githubToken") private var token: String = ""
  @AppStorage("githubOwner") private var owner: String = ""
  
  @State private var isPublic: Bool = true
  @State private var branch: String = "main"
  @State private var repoExists: Bool? = nil
  @State private var isChecking: Bool = true
  
  @Environment(\.dismiss) private var dismiss
  
  var repoName: String { projectFolder.lastPathComponent }
  
  var body: some View {
    VStack(spacing: 20) {
      
      if isChecking {
        ProgressView("Prüfe Repository...")
      }
      
      else if repoExists == true {
        VStack(spacing: 12) {
          Text("⚠️ Repository existiert bereits.")
            .font(.headline)
          Text("Möchtest du es überschreiben?")
          
          HStack {
            Button("Abbrechen") {
              onFinished?(false)
              dismiss()
            }
            
            Button("Überschreiben") {
              saveSettings()
            }
            .bold()
          }
        }
      }
      
      else {
        VStack(spacing: 12) {
          Toggle("Public Repository", isOn: $isPublic)
          
          TextField("Branch", text: $branch)
            .textFieldStyle(.roundedBorder)
          
          HStack {
            Button("Abbrechen") {
              onFinished?(false)
              dismiss()
            }
            
            Button("Repository erstellen & Push") {
              saveSettings()
            }
            .bold()
          }
        }
      }
      
      Spacer()
    }
    .padding()
    .task {
      await checkIfRepoExists()
    }
  }
  
  private func checkIfRepoExists() async {
    let gitService = GitHubService(
      token: token,
      repoOwner: owner,
      repoName: repoName
    )
    repoExists = await gitService.repositoryExists()
    isChecking = false
  }
  
  private func saveSettings() {
    let settings = ProjectSettings(isPublic: isPublic, branch: branch)
    //let settingsURL = projectFolder.appendingPathComponent(".project.json")
    let settingsURL = project.projectFile
    
    if let data = try? JSONEncoder().encode(settings) {
      try? data.write(to: settingsURL, options: [.atomic])
    }
    
    onFinished?(true)
    dismiss()
  }
}

struct ProjectSettings: Codable {
  var isPublic: Bool
  var branch: String
}
