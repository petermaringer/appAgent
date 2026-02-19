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
          .onDelete { indexSet in
            for index in indexSet {
              let project = projects[index]
              try? FileManager.default.removeItem(at: project.projectFolder)
            }
            projects.remove(atOffsets: indexSet)
          }
        }
        .listStyle(.plain)

        Button("Neues Projekt") {
          showingNewProjectSheet = true
        }
        .font(.body)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
      }
      .background(Color(.systemBackground).ignoresSafeArea())
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
