import SwiftUI

struct ProjectDetailView: View {
  @ObservedObject var project: ProjectEngine
  @State private var userPrompt: String = ""
  @State private var showingSettings: Bool = false
  @State private var isProcessing: Bool = false
  @State private var statusMessage: String = ""
  
  @AppStorage("githubToken") private var token: String = ""
@AppStorage("githubOwner") private var owner: String = ""
@AppStorage("githubRepo") private var repo: String = ""


  
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
        .border(Color.gray, width: 1)
        .frame(minHeight: 150, maxHeight: 250)
        .padding(.horizontal)
      
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
  Task {
    let gitService = GitHubService(token: token, repoOwner: owner, repoName: repo)
    await gitService.pushProject(at: project.projectFolder) { status in
      statusMessage = status
    }
  }
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
      
      // FileListView flexibel
      FileListView(projectFolder: project.projectFolder)
        .frame(maxHeight: .infinity)
        .padding(.horizontal)
        .onReceive(NotificationCenter.default.publisher(for: .openFileInEditor)) { notification in
          if let url = notification.object as? URL {
            sheetItem = FileSheetItem(url: url)
          }
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity) // volle Höhe
    .navigationTitle(project.projectName)
    .sheet(isPresented: $showingSettings) {
      SettingsView()
    }
    .sheet(item: $sheetItem) { item in
      FileEditorView(fileURL: item.url)
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
}
