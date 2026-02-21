import SwiftUI

struct FileListView: View {
  let projectFolder: URL
  @State private var rootFiles: [FileNode] = []
  @State private var selectedFile: FileNode?
  @State private var targetFile: URL?
  @State private var renamingNode: FileNode?
  @State private var newName: String = ""

  var body: some View {
    VStack(alignment: .leading) {
      Text("Projekt-Dateien")
        .font(.headline)
        .padding(.bottom, 5)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(rootFiles) { node in
            FileRowView(
              node: node,
              selectedFile: $selectedFile,
              targetFile: $targetFile,
              renamingNode: $renamingNode,
              newName: $newName,
              renameAction: renameNode,
              deleteAction: deleteNode
            )
          }
        }
      }
    }
    .onAppear(perform: loadFiles)
    .sheet(item: $selectedFile) { item in
      FileEditorView(fileURL: item.file)
    }
  }

  func loadFiles() {
    let fm = FileManager.default
    guard let contents = try? fm.contentsOfDirectory(at: projectFolder, includingPropertiesForKeys: nil) else {
      rootFiles = []
      return
    }
    rootFiles = contents
      .sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }
      .map { FileNode(file: $0) }
  }

  func renameNode(_ node: FileNode) {
    guard !newName.isEmpty else { return }
    let newURL = node.file.deletingLastPathComponent().appendingPathComponent(newName)
    try? FileManager.default.moveItem(at: node.file, to: newURL)
    node.file = newURL
    renamingNode = nil
    loadFiles()
  }

  func deleteNode(_ node: FileNode) {
    try? FileManager.default.removeItem(at: node.file)
    loadFiles()
  }
}
