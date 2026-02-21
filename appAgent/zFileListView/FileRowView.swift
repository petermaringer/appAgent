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

      ZStack(alignment: .leading) {
        // Alte Bezeichnung, immer sichtbar
        Text(node.file.lastPathComponent)
          .foregroundColor(node.file == targetFile ? .yellow : (node.isFolder ? .blue : .primary))

        // TextField + Häkchen nur sichtbar, wenn Rename aktiv
        if renamingNode?.id == node.id {
          HStack {
            TextField("", text: $newName)
              .textFieldStyle(.roundedBorder)
              .frame(maxWidth: 200)

            Button(action: {
              renameAction(node)
              renamingNode = nil
              selectedFile = nil
            }) {
              Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            }
          }
          .transition(.opacity) // sanft einblenden
        }
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
        if node.children == nil || node.children!.isEmpty {
          node.reloadChildren()
        } else {
          node.children = nil
        }
      } else {
        selectedFile = node
      }
    }
    .onDrag {
      NSItemProvider(object: node.file as NSURL)
    }
    .onDrop(of: ["public.file-url"], delegate: FileNodeDropDelegate(destination: node))
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
     
        Button("Löschen", role: .destructive) { deleteAction(node) }
        Button("Umbenennen") {
          renamingNode = node
          newName = node.file.lastPathComponent
        }
      
    }
  }
}
