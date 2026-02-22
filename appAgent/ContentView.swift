import SwiftUI

struct ContentView: View {
  @State private var projects: [ProjectEngine] = []
  @State private var showingNewProjectSheet = false
  @State private var selectedProject: ProjectEngine?

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        NavigationLink(
          destination: Group { if let project = selectedProject { ProjectDetailView(project: project) } },
          isActive: Binding(
            get: { selectedProject != nil },
            set: { if !$0 { selectedProject = nil } }
          )
        ) {
          EmptyView()
        }
        List {
          ForEach(projects) { project in
            NavigationLink(destination: ProjectDetailView(project: project)) {
              Text(project.projectName)
                .font(.body)
                .frame(height: 36, alignment: .leading)
            }
            .swipeActions(allowsFullSwipe: false) {
              Button(role: .destructive) {
                if let index = projects.firstIndex(where: { $0.id == project.id }) {
                  try? FileManager.default.removeItem(at: project.projectFolder)
                  projects.remove(at: index)
                }
              } label: {
                Label("Delete", systemImage: "trash")
              }
            }
          }
        }
        .listStyle(.plain)

        Button("Neues Projekt") {
          showingNewProjectSheet = true
        }
        .font(.body.bold())
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
      NewProjectView(projects: $projects) { newProject in
        showingNewProjectSheet = false
        selectedProject = newProject
      }
    }
    .onAppear(perform: loadProjects)
  }

  func loadProjects() {
    let fm = FileManager.default
    let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
    if let folders = try? fm.contentsOfDirectory(
      at: docs,
      includingPropertiesForKeys: [.creationDateKey],
      options: []
    ) {
      projects = folders
        .filter { $0.hasDirectoryPath }
        .sorted {
          let date1 = (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
          let date2 = (try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
          return date1 > date2
        }
        .map { ProjectEngine(projectFolder: $0) }
    }
  }
}

/*import SwiftUI

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
}*/
