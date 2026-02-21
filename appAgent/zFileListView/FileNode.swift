import Foundation
import SwiftUI

class FileNode: Identifiable, ObservableObject {
  let id = UUID()
  @Published var file: URL
  @Published var children: [FileNode]? = nil

  var isFolder: Bool { file.hasDirectoryPath }

  init(file: URL) {
    self.file = file
    if file.hasDirectoryPath {
      reloadChildren()
    }
  }

  func reloadChildren() {
    guard isFolder else { return }
    let fm = FileManager.default
    if let sub = try? fm.contentsOfDirectory(at: file, includingPropertiesForKeys: nil) {
      children = sub
        .sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }
        .map { FileNode(file: $0) }
    } else {
      children = []
    }
  }
}
