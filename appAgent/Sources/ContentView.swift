import SwiftUI

struct ContentView: View {
  @State private var projects: [ProjectEngine] = []
  @State private var showingNewProjectSheet = false

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        List {
          ForEach(projects) { project in
            NavigationLink(destination: ProjectDetailView(project: project)) {
              Text(project.projectName)
                .font(.body)
                .frame(height: 44, alignment: .leading)
            }
          }
        }
        .listStyle(.plain)
        .layoutPriority(1)

        Button("Neues Projekt") {
          showingNewProjectSheet = true
        }
        .font(.body)
        .frame(height: 44)
        .padding(.horizontal)
        .padding(.vertical, 6)
      }
      .navigationTitle("App-Generator")
      .sheet(isPresented: $showingNewProjectSheet) {
        NewProjectView(projects: $projects)
      }
      .onAppear(perform: loadProjects)
    }
  }

  func loadProjects() {
    let fm = FileManager.default
    let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
    if let folders = try? fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) {
      projects = folders.filter { $0.hasDirectoryPath }.map { ProjectEngine(projectFolder: $0) }
    }
  }
}
