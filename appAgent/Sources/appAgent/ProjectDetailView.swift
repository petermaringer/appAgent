import SwiftUI

struct ProjectDetailView: View {
  @ObservedObject var project: ProjectEngine
  @State private var userPrompt: String = ""
  @State private var showingSettings: Bool = false
  @State private var isProcessing: Bool = false
  @State private var statusMessage: String = ""
  
  let kiService = KIService()
  
  var body: some View {
    VStack(spacing: 20) {
      if !project.promptHistory.isEmpty {
        ScrollView(.horizontal, showsIndicators: true) {
          HStack {
            ForEach(project.promptHistory, id: \.self) { prompt in
              Button(action: { userPrompt = prompt }) {
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
      
      TextEditor(text: $userPrompt)
        .border(Color.gray, width: 1)
        .frame(height: 150)
        .padding()
      
      HStack {
        Button(action: { showingSettings.toggle() }) {
          Image(systemName: "gearshape")
        }
        .padding(.leading)
        
        Spacer()
        
        Button(action: { Task { await generateProject() } }) {
          if isProcessing {
            ProgressView()
          } else {
            Text("KI-Code generieren")
              .bold()
          }
        }
        .padding(.trailing)
      }
      
      if !statusMessage.isEmpty {
        Text(statusMessage)
          .foregroundColor(.blue)
          .padding()
      }
      
      FileListView(projectFolder: project.projectFolder)
      
      Spacer()
    }
    .navigationTitle(project.projectName)
    .sheet(isPresented: $showingSettings) {
      SettingsView(projectEngine: project)
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
