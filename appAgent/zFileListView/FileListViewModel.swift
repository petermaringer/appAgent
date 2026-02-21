import SwiftUI

class FileListViewModel: ObservableObject {
  @Published var rootFiles: [FileNode] = []
  @Published var selectedFile: FileNode?
  @Published var targetFile: URL?
  @Published var renamingNode: FileNode?
  @Published var newName: String = ""

  func loadFiles(folder: URL) {
    let fm = FileManager.default
    guard let contents = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
      rootFiles = []
      return
    }
    rootFiles = contents
      .sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }
      .map { FileNode(file: $0) }
  }

  func renameNode(_ node: FileNode, newName: String) {
    guard !newName.isEmpty else { return }
    let newURL = node.file.deletingLastPathComponent().appendingPathComponent(newName)
    try? FileManager.default.moveItem(at: node.file, to: newURL)
    node.file = newURL
    renamingNode = nil
    if let folder = node.file.deletingLastPathComponent() as URL? {
      loadFiles(folder: folder)
    }
  }

  func deleteNode(_ node: FileNode) {
    try? FileManager.default.removeItem(at: node.file)
    if let folder = node.file.deletingLastPathComponent() as URL? {
      loadFiles(folder: folder)
    }
  }
}
