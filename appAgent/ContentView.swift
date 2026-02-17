import SwiftUI

struct ContentView: View {
  @State private var projects: [ProjectEngine] = []
  @State private var showingNewProjectSheet = false

  var body: some View {
    NavigationStack {
      ZStack {
        Color(.systemBackground).ignoresSafeArea() // Hintergrund füllt ganzen Screen

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
          .frame(maxHeight: .infinity) // List füllt den verfügbaren Platz

          Button("Neues Projekti") {
            showingNewProjectSheet = true
          }
          .font(.body)
          .frame(height: 44)
          .frame(maxWidth: .infinity)
          .padding(.horizontal)
          .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .navigationTitle("App-Generator")
    }
    .sheet(isPresented: $showingNewProjectSheet) {
      NewProjectView(projects: $projects)
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
