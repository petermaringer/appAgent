import SwiftUI

struct FileRowView: View {
  @ObservedObject var node: FileNode
  @Binding var selectedFile: FileNode?
  @Binding var targetFile: URL?
  @Binding var renamingNode: FileNode?
  @Binding var newName: String
  @FocusState private var isRenamingFocused: Bool

  var renameAction: (FileNode) -> Void
  var deleteAction: (FileNode) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Image(systemName: node.isFolder ? "folder.fill" : "doc.text")
          .foregroundColor(node.isFolder ? .blue : .primary)

        ZStack(alignment: .leading) {
          Text(node.file.lastPathComponent)
            .foregroundColor(node.file == targetFile ? .yellow : (node.isFolder ? .blue : .primary))

          if renamingNode?.id == node.id {
            HStack {
              TextField("", text: $newName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                .focused($isRenamingFocused)

              Button(action: {
                renameAction(node)
                renamingNode = nil
                selectedFile = nil
                isRenamingFocused = false
              }) {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(.green)
              }
            }
            .transition(.opacity)
          }
        }

        Spacer()

        // Pfeil am Ende der Zeile für Folder
        if node.isFolder {
          Image(systemName: "chevron.right")
            .rotationEffect(.degrees(node.isExpanded ? 90 : 0))
            .foregroundColor(.gray)
            .padding(.trailing, 5)
            .animation(.easeInOut(duration: 0.2), value: node.isExpanded)
        }

        if node.file == targetFile {
          Image(systemName: "star.fill")
            .foregroundColor(.yellow)
        }
      }
      .contentShape(Rectangle())
      .onTapGesture {
        guard renamingNode?.id != node.id else { return }
        if node.isFolder {
          withAnimation(.easeInOut(duration: 0.2)) {
            if node.isExpanded {
              node.isExpanded = false
            } else {
              node.reloadChildren()
              node.isExpanded = true
            }
          }
        } else {
          selectedFile = node
        }
      }
      .onDrag { NSItemProvider(object: node.file as NSURL) }
      .onDrop(of: ["public.file-url"], delegate: FileNodeDropDelegate(destination: node))
      .swipeActions(edge: .trailing, allowsFullSwipe: false) {
        Button("Löschen", role: .destructive) { deleteAction(node) }
        Button("Umbenennen") {
          withAnimation(.none) {
            renamingNode = node
            newName = node.file.lastPathComponent
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
              isRenamingFocused = true
            }
          }
        }
      }

      if node.isFolder && node.isExpanded, let children = node.children {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(children) { child in
            FileRowView(
              node: child,
              selectedFile: $selectedFile,
              targetFile: $targetFile,
              renamingNode: $renamingNode,
              newName: $newName,
              renameAction: renameAction,
              deleteAction: deleteAction
            )
            .padding(.leading, 20)
          }
        }
      }
    }
  }
}
