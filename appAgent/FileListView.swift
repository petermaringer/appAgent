import SwiftUI

struct FileListView: View {
  let projectFolder: URL
  @State private var rootFiles: [FileNode] = []
  @State private var selectedFile: FileNode?
  @State private var targetFile: URL?
  @State private var showingEditor: Bool = false

  class FileNode: Identifiable, ObservableObject {
    var file: URL
    @Published var children: [FileNode]? = nil
    @Published var isExpanded: Bool = false
    @Published var isFolder: Bool = false

    var id: String { file.absoluteString }

    init(file: URL) {
      self.file = file
      self.isFolder = file.hasDirectoryPath
    }
  }

  var body: some View {
    VStack(alignment: .leading) {
      Text("Projekt-Dateien")
        .font(.headline)
        .padding(.bottom, 5)

      List {
        OutlineGroup(rootFiles, children: \.children) { node in
          HStack {
            Image(systemName: node.isFolder ? (node.isExpanded ? "folder.open" : "folder") : "doc.text")
              .foregroundColor(node.isFolder ? .blue : .primary)
            Text(node.file.lastPathComponent)
              .foregroundColor(node.file == targetFile ? .yellow : (node.isFolder ? .blue : .primary))
              .fontWeight(node.file == targetFile ? .bold : .regular)
            Spacer()
            if node.file == targetFile {
              Image(systemName: "star.fill")
                .foregroundColor(.yellow)
            }
          }
          .padding(.leading, CGFloat(level(of: node)) * 16)
          .contentShape(Rectangle())
          .onTapGesture {
            if node.isFolder {
              withAnimation { node.isExpanded.toggle() }
            } else {
              selectedFile = node
            }
          }
          .swipeActions {
            if !node.isFolder {
              Button(role: .destructive) { deleteNode(node) } label: { Label("Löschen", systemImage: "trash") }
            }
          }
          .onDrag {
            node.file as NSURL
          }
          .onDrop(of: [.fileURL], delegate: FileDropDelegate(targetNode: node))
        }
      }
    }
    .onAppear(perform: loadFiles)
    .sheet(item: $selectedFile) { item in
      FileEditorView(fileURL: item.file)
    }
  }

  func level(of node: FileNode) -> Int {
    var level = 0
    var current = node.file.deletingLastPathComponent()
    while current.path.hasPrefix(projectFolder.path) && current.path != projectFolder.path {
      level += 1
      current.deleteLastPathComponent()
    }
    return level
  }

  func loadFiles() {
    rootFiles = buildFileTree(for: projectFolder)
    targetFile = findTargetFile(in: rootFiles)
  }

  private func buildFileTree(for folder: URL) -> [FileNode] {
    let fm = FileManager.default
    guard let contents = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return [] }

    return contents.map { url in
      let node = FileNode(file: url)
      if url.hasDirectoryPath {
        node.children = buildFileTree(for: url)
      }
      return node
    }
  }

  private func findTargetFile(in nodes: [FileNode]) -> URL? {
    let swiftFiles = nodes.flatMap { flatten(node: $0) }.filter { !$0.isFolder && $0.file.pathExtension == "swift" }
    return swiftFiles.max(by: { (f1, f2) in
      let date1 = (try? f1.file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      let date2 = (try? f2.file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      return date1 < date2
    })?.file
  }

  private func flatten(node: FileNode) -> [FileNode] {
    [node] + (node.children?.flatMap { flatten(node: $0) } ?? [])
  }

  func deleteNode(_ node: FileNode) {
    try? FileManager.default.removeItem(at: node.file)
    loadFiles()
  }

  func renameNode(_ node: FileNode) {
    let alert = UIAlertController(title: "Umbenennen", message: "Neuer Name", preferredStyle: .alert)
    alert.addTextField { $0.text = node.file.lastPathComponent }
    alert.addAction(UIAlertAction(title: "Abbrechen", style: .cancel))
    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
      guard let newName = alert.textFields?.first?.text, !newName.isEmpty else { return }
      let newURL = node.file.deletingLastPathComponent().appendingPathComponent(newName)
      try? FileManager.default.moveItem(at: node.file, to: newURL)
      node.file = newURL
      loadFiles()
    })
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let rootVC = windowScene.windows.first?.rootViewController {
      rootVC.present(alert, animated: true)
    }
  }
}

// MARK: - Drag & Drop Delegate
struct FileDropDelegate: DropDelegate {
  let targetNode: FileListView.FileNode

  func performDrop(info: DropInfo) -> Bool {
    guard let item = info.itemProviders(for: [.fileURL]).first else { return false }
    item.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
      guard let data = data as? Data,
            let url = NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL? else { return }
      let destURL = targetNode.isFolder ? targetNode.file.appendingPathComponent(url.lastPathComponent) : targetNode.file.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent)
      try? FileManager.default.moveItem(at: url, to: destURL)
    }
    return true
  }
}

/*import SwiftUI

struct FileListView: View {
  let projectFolder: URL
  @State private var items: [IdentifiableItem] = []
  @State private var selectedItem: IdentifiableItem?
  @State private var targetFile: URL?
  @State private var expandedFolders: Set<URL> = []

  struct IdentifiableItem: Identifiable {
    let url: URL
    let depth: Int
    var isDirectory: Bool { url.hasDirectoryPath }
    var id: String { url.absoluteString }
  }

  var body: some View {
    VStack(alignment: .leading) {
      Text("Projekt-Dateien")
        .font(.headline)
        .padding(.bottom, 5)

      List {
        ForEach(displayedItems(items)) { item in
          HStack {
            if item.isDirectory {
              Image(systemName: expandedFolders.contains(item.url) ? "folder.fill" : "folder")
                .foregroundColor(.blue)
            } else {
              Image(systemName: "doc.text")
                .foregroundColor(.primary)
            }
            Text(item.url.lastPathComponent)
              .fontWeight(item.url == targetFile ? .bold : .regular)
              .foregroundColor(item.isDirectory ? .blue : (item.url == targetFile ? .yellow : .primary))
            Spacer()
            if item.url == targetFile {
              Image(systemName: "star.fill")
                .foregroundColor(.yellow)
            }
          }
          .padding(.leading, CGFloat(item.depth) * 16)
          .contentShape(Rectangle())
          .onTapGesture {
            if item.isDirectory {
              toggleFolder(item.url)
            } else {
              selectedItem = item
            }
          }
        }
      }
    }
    .onAppear(perform: loadItems)
    .sheet(item: $selectedItem) { item in
      if !item.isDirectory {
        FileEditorView(fileURL: item.url)
      }
    }
  }

  func loadItems() {
    do {
      items = try recursiveItems(in: projectFolder)
      
      let swiftFiles = items.filter { !$0.isDirectory && $0.url.pathExtension == "swift" }
      if let lastModified = swiftFiles.max(by: { f1, f2 in
        let date1: Date = (try? f1.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        let date2: Date = (try? f2.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        return date1 < date2
      }) {
        targetFile = lastModified.url
      }
    } catch {
      print("Fehler beim Laden der Dateien: \(error)")
    }
  }

  private func recursiveItems(in folder: URL, depth: Int = 0) throws -> [IdentifiableItem] {
    let fm = FileManager.default
    let contents = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
    var result: [IdentifiableItem] = []

    for item in contents.sorted(by: { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }) {
      let entry = IdentifiableItem(url: item, depth: depth)
      result.append(entry)
      if item.hasDirectoryPath {
        result.append(contentsOf: try recursiveItems(in: item, depth: depth + 1))
      }
    }
    return result
  }

  private func displayedItems(_ allItems: [IdentifiableItem]) -> [IdentifiableItem] {
    var result: [IdentifiableItem] = []
    var skipDepth: Int? = nil

    for item in allItems {
      if let skip = skipDepth {
        if item.depth > skip {
          continue
        } else {
          skipDepth = nil
        }
      }

      result.append(item)

      if item.isDirectory && !expandedFolders.contains(item.url) {
        skipDepth = item.depth
      }
    }

    return result
  }

  private func toggleFolder(_ url: URL) {
    if expandedFolders.contains(url) {
      expandedFolders.remove(url)
    } else {
      expandedFolders.insert(url)
    }
  }
}*/

/*import SwiftUI

struct FileListView: View {
  let projectFolder: URL
  @State private var files: [IdentifiableFile] = []
  @State private var selectedFile: IdentifiableFile?
  @State private var targetFile: URL?
  
  @State private var showingEditor: Bool = false

  struct IdentifiableFile: Identifiable {
    let file: URL
    var id: String { file.absoluteString }
  }

  var body: some View {
    VStack(alignment: .leading) {
      Text("Projekt-Dateien")
        .font(.headline)
        .padding(.bottom, 5)

      List {
        ForEach(files) { item in
          let file = item.file
          HStack {
            Text(file.lastPathComponent)
              .fontWeight(file == targetFile ? .bold : .regular)
              .foregroundColor(file == targetFile ? .blue : .primary)
            Spacer()
            if file == targetFile {
              Image(systemName: "star.fill")
                .foregroundColor(.yellow)
            }
          }
          .contentShape(Rectangle())
          .onTapGesture {
            selectedFile = item
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
    guard let folderContents = try? fm.contentsOfDirectory(at: projectFolder, includingPropertiesForKeys: nil) else { return }

    files = folderContents
      .filter { $0.pathExtension == "swift" }
      .map { IdentifiableFile(file: $0) }

    if let lastModified = files.max(by: { f1, f2 in
      let date1: Date = (try? f1.file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      let date2: Date = (try? f2.file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      return date1 < date2
    }) {
      targetFile = lastModified.file
    }
  }
}*/
