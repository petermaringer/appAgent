import SwiftUI

struct FlatFileNode: Identifiable {
  let node: FileNode
  let depth: Int
  var id: UUID { node.id }
}

struct FileRowView: View {
  @ObservedObject var node: FileNode
  let depth: Int
  @Binding var renamingNode: FileNode?
  @Binding var newName: String
  @FocusState private var isRenamingFocused: Bool
  var renameAction: (FileNode) -> Void
  var deleteAction: (FileNode) -> Void

  var body: some View {
    HStack {
      Image(systemName: node.isFolder ? "folder.fill" : "doc.text")
        .foregroundColor(node.isFolder ? .blue : .primary)

      Text(node.file.lastPathComponent)
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
            isRenamingFocused = false
          }) {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.green)
          }
        }
        .transition(.opacity)
      }
    }
    .padding(.leading, CGFloat(depth) * 20)
    .padding(.vertical, 5)
    .contentShape(Rectangle())
    .onTapGesture {
      guard renamingNode?.id != node.id else { return }
      if node.isFolder {
        withAnimation(.easeInOut(duration: 0.2)) {
          node.isExpanded.toggle()
          if node.isExpanded { node.reloadChildren() }
        }
      }
    }
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
  }
}

struct FileListView: View {
  let rootFolder: URL
  @State private var rootNodes: [FileNode] = []
  @State private var renamingNode: FileNode? = nil
  @State private var newName: String = ""
  var renameAction: (FileNode) -> Void = { _ in }
  var deleteAction: (FileNode) -> Void = { _ in }

  init(rootFolder: URL, renameAction: @escaping (FileNode) -> Void = { _ in }, deleteAction: @escaping (FileNode) -> Void = { _ in }) {
    self.rootFolder = rootFolder
    self.renameAction = renameAction
    self.deleteAction = deleteAction
    _rootNodes = State(initialValue: [FileNode(file: rootFolder)])
  }

  private var visibleNodes: [FlatFileNode] {
    func flatten(nodes: [FileNode], depth: Int) -> [FlatFileNode] {
      nodes.flatMap { node in
        var result = [FlatFileNode(node: node, depth: depth)]
        if node.isExpanded, let children = node.children {
          result += flatten(nodes: children, depth: depth + 1)
        }
        return result
      }
    }
    return flatten(nodes: rootNodes, depth: 0)
  }

  var body: some View {
    List {
      ForEach(visibleNodes) { flatNode in
        VStack(spacing: 0) {
          FileRowView(
            node: flatNode.node,
            depth: flatNode.depth,
            renamingNode: $renamingNode,
            newName: $newName,
            renameAction: renameAction,
            deleteAction: deleteAction
          )
          Divider()
        }
      }
    }
    .listStyle(.plain)
  }
}
