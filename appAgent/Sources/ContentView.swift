import SwiftUI

struct ContentView: View {
  @State private var projects: [ProjectEngine] = []
  @State private var showingNewProjectSheet = false

  var body: some View {
    NavigationView {
      VStack {
        List {
          ForEach(projects) { project in
            NavigationLink(destination: ProjectDetailView(project: project)) {
              Text(project.projectName)
            }
          }
        }
        
        Button("Neues Projekt") {
          showingNewProjectSheet = true
        }
        .padding()
      }
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
