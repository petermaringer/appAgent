import SwiftUI

struct ProjectDetailView: View {
  @ObservedObject var project: ProjectEngine
  @State private var userPrompt: String = ""
  @State private var showingSettings: Bool = false
  @State private var isProcessing: Bool = false
  @State private var statusMessage: String = ""
  
  @AppStorage("githubToken") private var token: String = ""
  @AppStorage("githubOwner") private var owner: String = ""
  
  @State private var showingGitSheet: Bool = false
  
  @FocusState private var editorFocused: Bool
  
  // Neuer Wrapper für SwiftUI Sheet
  struct FileSheetItem: Identifiable {
    let id = UUID()
    let url: URL
  }
  @State private var sheetItem: FileSheetItem? = nil

  let kiService = KIService()
  
  var body: some View {
    VStack(spacing: 10) {
      // Prompt-History horizontal scroll
      if !project.promptHistory.isEmpty {
        ScrollView(.horizontal, showsIndicators: true) {
          HStack(spacing: 8) {
            ForEach(project.promptHistory, id: \.self) { prompt in
              Button {
                userPrompt = prompt
              } label: {
                Text(prompt)
                  .padding(6)
                  .background(Color.gray.opacity(0.2))
                  .cornerRadius(6)
              }
            }
          }
          .padding(.horizontal)
        }
      }
      
      // TextEditor nimmt flexiblen Platz
      TextEditor(text: $userPrompt)
        .padding(12)
        .background(
          RoundedRectangle(cornerRadius: 18)
            .stroke(Color.gray.opacity(0.1), lineWidth: 3)
        )
        .frame(height: 150)
        .padding(.horizontal)
        .focused($editorFocused)
      /*TextEditor(text: $userPrompt)
        .border(Color.gray.opacity(0.1), width: 3)
        //.frame(minHeight: 150, maxHeight: 250)
        .frame(height: 150)
        .padding(.horizontal)
        .cornerRadius(18)
        .focused($editorFocused)*/
      
      // Buttons
      HStack {
        Button {
          showingSettings.toggle()
        } label: {
          Image(systemName: "gearshape")
        }
        .padding(.leading)
        
        Spacer()
        
        Button {
          Task { await generateProject() }
        } label: {
          if isProcessing {
            ProgressView()
          } else {
            Text("KI-Code generieren")
              .bold()
          }
        }
        .padding(.trailing)
        
        Button {
          gitPush()
          /*Task {
            let settingsURL = project.projectFolder.appendingPathComponent(".project.json")
            if FileManager.default.fileExists(atPath: settingsURL.path) {
              let gitService = GitHubService(token: token, repoOwner: owner, repoName: project.projectName)
              await gitService.pushProject(at: project.projectFolder) { status in
                statusMessage = status
              }
            } else {
              showingGitSheet = true
            }
          }*/
          /*Task {
            let gitService = GitHubService(token: token, repoOwner: owner, repoName: project.projectName)
            await gitService.pushProject(at: project.projectFolder) { status in
              statusMessage = status
            }
          }*/
        } label: {
          Text("GitHub Push").bold()
        }
        .padding(.trailing)
      }
      .padding(.horizontal)
      
      // Statusmeldung
      if !statusMessage.isEmpty {
        Text(statusMessage)
          .foregroundColor(.blue)
          .padding(.horizontal)
      }
      
      GitSectionView(project: project)
        .padding()
        /*.padding(.top)
    .padding(.horizontal)
     
      LinearGradient(
    gradient: Gradient(colors: [
      Color(.systemBackground),
      Color(.systemBackground).opacity(0)
    ]),
    startPoint: .top,
    endPoint: .bottom
  )
  .frame(height: 16)
  .allowsHitTesting(false)*/
      
      // FileListView flexibel
      ZStack(alignment: .top) {
      Color.yellow
      GradientOverlayView(gradientHeight: 16) {
      FileListView(projectFolder: project.projectFolder)
        //.frame(maxHeight: .infinity)
        .background(Color.clear)
        .padding(.horizontal)
        
        .padding(.top, 16) // Abstand für den Inhalt, damit Gradient nichts überdeckt
        
        /*LinearGradient(
    gradient: Gradient(colors: [
      Color(.red),
      Color(.systemBackground).opacity(0)
    ]),
    startPoint: .top,
    endPoint: .bottom
  )
  .frame(height: 16)
  .allowsHitTesting(false)*/
  }
        
  /*.overlay(
    LinearGradient(
      gradient: Gradient(colors: [Color(.red), Color(.systemBackground).opacity(0)]),
      startPoint: .top,
      endPoint: .bottom
    )
    .frame(height: 16) // exakt gleiche Höhe wie Top-Padding
    .allowsHitTesting(false),
    alignment: .top
  )*/
        
        .onReceive(NotificationCenter.default.publisher(for: .openFileInEditor)) { notification in
          if let url = notification.object as? URL {
            sheetItem = FileSheetItem(url: url)
          }
        }
        }
    }
    //.frame(maxWidth: .infinity, maxHeight: .infinity) // volle Höhe
    .navigationTitle(project.projectName)
    .background(
      Group {
        if editorFocused {
          Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
              editorFocused = false // Keyboard weg beim ersten Tap
            }
            //.allowsHitTesting(true)
        }
      }
    )
    .sheet(isPresented: $showingSettings) {
      SettingsView()
    }
    .sheet(item: $sheetItem) { item in
      FileEditorView(fileURL: item.url)
    }
    .sheet(isPresented: $showingGitSheet) {
      GitSettingsSheet(project: project) { saved in
        if saved {
          gitPush()
        }
      }
    }
  }
  
  func generateProject() async {
    guard !userPrompt.isEmpty else {
      statusMessage = "Bitte Prompt eingeben."
      return
    }
    isProcessing = true
    statusMessage = ""
    do {
      try await project.generateOrUpdateProject(userPrompt: userPrompt, kiService: kiService)
      statusMessage = "✅ Projekt aktualisiert."
    } catch {
      statusMessage = "❌ Fehler: \(error.localizedDescription)"
    }
    isProcessing = false
  }
  
func gitPush() {
  let settingsURL = project.projectFolder.appendingPathComponent(".project.json")
  
  if FileManager.default.fileExists(atPath: settingsURL.path) {
    // Settings existieren → Push starten
    if let data = try? Data(contentsOf: settingsURL),
       let settings = try? JSONDecoder().decode(ProjectSettings.self, from: data) {
      Task {
        /*let gitService = GitHubService(
          token: token,
          repoOwner: owner,
          repoName: project.projectName,
          isPublic: settings.isPublic,
          branch: settings.branch
        )*/
        let gitService = GitHubService(token: token, repoOwner: owner, repoName: project.projectName)
        //await gitService.pushProject(at: project.projectFolder) { _ in }
        await gitService.pushProject(at: project.projectFolder) { status in
          statusMessage = status
        }
      }
    } else {
      // Datei beschädigt → Sheet erneut öffnen
      showingGitSheet = true
    }
  } else {
    // Settings existieren noch nicht → Sheet öffnen
    showingGitSheet = true
  }
}
  
}

/*#if canImport(UIKit)
extension View {
  func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
  }
}
#endif*/
