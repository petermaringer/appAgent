import SwiftUI

struct ContentView: View {
  @State private var projects: [ProjectEngine] = []
  @State private var showingSettingsSheet = false
  @State private var showingNewProjectSheet = false
  @State private var navigationPath = NavigationPath()
  
  var body: some View {
    NavigationStack(path: $navigationPath) {
      VStack(spacing: 0) {
        ScrollViewReader { scrollProxy in
          List {
            ForEach(projects) { project in
              NavigationLink(value: project) {
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
                .tint(nil)
              }
              .id(project.id)
            }
          }
          .listStyle(.plain)
          .onChange(of: projects) {
            if let firstProject = projects.first {
              DispatchQueue.main.async {
                scrollProxy.scrollTo(firstProject.id, anchor: .top)
              }
            }
          }
        }
      }
      .background(Color(.systemBackground).ignoresSafeArea())
      .navigationTitle("App-Generator")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            showingSettingsSheet = true
          } label: {
            Image(systemName: "gearshape")
          }
        }
        ToolbarItem(placement: .bottomBar) {
          /*Button {
            showingNewProjectSheet = true
          } label: {
            Text("Neues Projekt")
              //.font(.headline)
              //.padding(.vertical, 12)
              //.padding(.vertical)
              //.contentShape(Rectangle())
          }
          //.controlSize(.large)
          .buttonStyle(.borderedProminent)
          .padding(.vertical)
          .contentShape(Rectangle())*/
          Button("Neues Projekt") {
            showingNewProjectSheet = true
          }
          .buttonStyle(ToolbarButton())
        }
      }
      .navigationDestination(for: ProjectEngine.self) { project in
        ProjectDetailView(project: project)
      }
    }
    .tint(.blue)
    .sheet(isPresented: $showingSettingsSheet) {
      SettingsView()
    }
    .sheet(isPresented: $showingNewProjectSheet) {
      NewProjectView(projects: $projects) { newProject in
        showingNewProjectSheet = false
        projects.append(newProject)
        projects.sort {
          let date1 = (try? $0.projectFolder.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
          let date2 = (try? $1.projectFolder.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
          return date1 > date2
        }
        navigationPath.append(newProject)
      }
    }
    .onAppear(perform: loadProjects)
  }
  
  struct ToolbarButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            //.foregroundStyle(.link)
            .font(.headline)
            .padding(.horizontal)
            //.frame(maxWidth: .infinity)
            //.background(.yellow)
            .opacity(configuration.isPressed ? 0.2 : 1)
            .contentShape(Rectangle())
    }
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
