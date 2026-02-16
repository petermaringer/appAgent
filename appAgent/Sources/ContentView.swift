import SwiftUI

struct ContentView: View {
  @State private var projects: [ProjectEngine] = []
  @State private var showingNewProjectSheet = false

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        List {
          ForEach(projects) { project in
            NavigationLink(destination: ProjectDetailView(project: project)) {
              Text(project.projectName)
            }
          }
        }
        .listStyle(PlainListStyle())
        .frame(maxHeight: .infinity) // List füllt den verfügbaren Raum
        
        Button("Neues Projekt") {
          showingNewProjectSheet = true
        }
        .padding()
        .frame(maxWidth: .infinity) // Button horizontal strecken
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity) // VStack füllt Bildschirm
      .navigationTitle("App-Generator")
      .sheet(isPresented: $showingNewProjectSheet) {
        NewProjectView(projects: $projects)
      }
    }
    .onAppear(perform: loadProjects)
  }
  
  func loadProjects() {
    let fm = FileManager.default
    let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
    if let folders = try? fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) {
      projects = folders.filter { $0.hasDirectoryPath }.map { ProjectEngine(projectFolder: $0) }
    }
  }
}
