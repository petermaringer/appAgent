import SwiftUI

struct NewProjectView: View {
  @Binding var projects: [ProjectEngine]
  @Environment(\.dismiss) var dismiss
  @State private var projectName: String = ""
  
  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Neues Projekt")) {
          TextField("Projektname", text: $projectName)
        }
      }
      .navigationTitle("Neues Projekt")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Erstellen") { createProject() }
        }
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
      }
    }
  }
  
  func createProject() {
    guard !projectName.isEmpty else { return }
    let fm = FileManager.default
    let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
    let newFolder = docs.appendingPathComponent(projectName)
    
    try? fm.createDirectory(at: newFolder, withIntermediateDirectories: true)
    
    // Default ContentView.swift anlegen
    let contentFile = newFolder.appendingPathComponent("ContentView.swift")
    let defaultContent = """
    import SwiftUI

    struct ContentView: View {
      var body: some View {
        Text("Hello, \(projectName)!")
          .padding()
      }
    }
    """
    try? defaultContent.write(to: contentFile, atomically: true, encoding: .utf8)
    
    let engine = ProjectEngine(projectFolder: newFolder)
    projects.append(engine)
    dismiss()
  }
}
