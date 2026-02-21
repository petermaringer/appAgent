import SwiftUI

struct FileRowView: View {
  @ObservedObject var node: FileNode
  @Binding var selectedFile: FileNode?
  @Binding var targetFile: URL?
  @Binding var renamingNode: FileNode?
  @Binding var newName: String

  var renameAction: (FileNode) -> Void
  var deleteAction: (FileNode) -> Void

  var body: some View {
    HStack {
      if node.isFolder {
        Image(systemName: "folder.fill")
          .foregroundColor(.blue)
      } else {
        Image(systemName: "doc.text")
      }

      if renamingNode?.id == node.id {
        TextField("", text: $newName, onCommit: { renameAction(node) })
          .textFieldStyle(.roundedBorder)
          .frame(maxWidth: 200)
      } else {
        Text(node.file.lastPathComponent)
          .foregroundColor(node.file == targetFile ? .yellow : (node.isFolder ? .blue : .primary))
      }

      Spacer()

      if node.file == targetFile {
        Image(systemName: "star.fill")
          .foregroundColor(.yellow)
      }
    }
    .contentShape(Rectangle())
    .onTapGesture {
      if node.isFolder {
        node.reloadChildren()
      } else {
        selectedFile = node
      }
    }
    .onDrag {
      NSItemProvider(object: node.file as NSURL)
    }
    .onDrop(of: ["public.file-url"], delegate: FileNodeDropDelegate(destination: node))
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if !node.isFolder {
        Button("Löschen", role: .destructive) { deleteAction(node) }
        Button("Umbenennen") {
          renamingNode = node
          newName = node.file.lastPathComponent
        }
      }
    }
  }
}
