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
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Image(systemName: node.isFolder ? "folder.fill" : "doc.text")
          .foregroundColor(node.isFolder ? .blue : .primary)

        Text(node.file.lastPathComponent)
          .foregroundColor(node.file == targetFile ? .yellow : (node.isFolder ? .blue : .primary))
          .lineLimit(1)

        Spacer()

        if node.isFolder {
          Image(systemName: "chevron.right")
            .rotationEffect(.degrees(node.isExpanded ? 90 : 0))
            .foregroundColor(.gray)
            .animation(.easeInOut(duration: 0.2), value: node.isExpanded)
        }

        if renamingNode?.id == node.id {
          HStack(spacing: 5) {
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
      .padding(.vertical, 8)
      .padding(.horizontal, 5)
      .background(Color(UIColor.systemBackground))
      .contentShape(Rectangle())
      .onTapGesture {
        guard renamingNode?.id != node.id else { return }
        if node.isFolder {
          withAnimation(.easeInOut(duration: 0.2)) {
            node.isExpanded.toggle()
            if node.isExpanded { node.reloadChildren() }
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

      Divider() // Trennstrich wie bei OutlineGroup

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
