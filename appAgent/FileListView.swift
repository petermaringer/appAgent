import SwiftUI

struct FileListView: View {
  let projectFolder: URL
  @State private var rootFiles: [FileNode] = []
  @State private var selectedFile: FileNode?

  @State private var showingEditor: Bool = false

  class FileNode: Identifiable, ObservableObject {
    let file: URL
    @Published var children: [FileNode] = []
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
            Image(systemName: node.isFolder ? (node.isExpanded ? "folder.open" : "folder") : "doc")
              .foregroundColor(node.isFolder ? .blue : .primary)

            Text(node.file.lastPathComponent)
              .foregroundColor(isTargetFile(node) ? .yellow : (node.isFolder ? .blue : .primary))
              .fontWeight(isTargetFile(node) ? .bold : .regular)

            Spacer()

            if isTargetFile(node) {
              Image(systemName: "star.fill")
                .foregroundColor(.yellow)
            }
          }
          .padding(.leading, CGFloat(level(of: node)) * 16)
          .contentShape(Rectangle())
          .onTapGesture {
            if node.isFolder {
              node.isExpanded.toggle()
            } else {
              selectedFile = node
            }
          }
          .onDrag {
            return NSItemProvider(object: node.file as NSURL)
          }
          .onDrop(of: [.fileURL], delegate: FileDropDelegate(target: node, rootNodes: $rootFiles))
          .swipeActions(edge: .trailing) {
            if !node.isFolder {
              Button(role: .destructive) { deleteNode(node) } label: { Label("Löschen", systemImage: "trash") }
            }
            Button { renameNode(node) } label: { Label("Umbenennen", systemImage: "pencil") }
          }
        }
      }
    }
    .onAppear(perform: loadFiles)
    .sheet(item: $selectedFile) { node in
      FileEditorView(fileURL: node.file)
    }
  }

  func isTargetFile(_ node: FileNode) -> Bool {
    return node.file.lastPathComponent == "ContentView.swift"
  }

  func level(of node: FileNode) -> Int {
    var count = 0
    var parent = findParent(of: node, in: rootFiles)
    while parent != nil {
      count += 1
      parent = findParent(of: parent!, in: rootFiles)
    }
    return count
  }

  func findParent(of node: FileNode, in nodes: [FileNode]) -> FileNode? {
    for n in nodes {
      if n.children.contains(where: { $0.id == node.id }) { return n }
      if let found = findParent(of: node, in: n.children) { return found }
    }
    return nil
  }

  func loadFiles() {
    rootFiles = buildNodes(at: projectFolder)
  }

  func buildNodes(at url: URL) -> [FileNode] {
    let fm = FileManager.default
    guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return [] }
    return contents.map { file in
      let node = FileNode(file: file)
      if node.isFolder {
        node.children = buildNodes(at: file)
      }
      return node
    }
  }

  func deleteNode(_ node: FileNode) {
    try? FileManager.default.removeItem(at: node.file)
    if let parent = findParent(of: node, in: rootFiles) {
      parent.children.removeAll { $0.id == node.id }
    } else {
      rootFiles.removeAll { $0.id == node.id }
    }
  }

  func renameNode(_ node: FileNode) {
    let alert = UIAlertController(title: "Umbenennen", message: "Neuer Name", preferredStyle: .alert)
    alert.addTextField { textField in
      textField.text = node.file.lastPathComponent
    }
    alert.addAction(UIAlertAction(title: "Abbrechen", style: .cancel))
    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
      guard let newName = alert.textFields?.first?.text, !newName.isEmpty else { return }
      let newURL = node.file.deletingLastPathComponent().appendingPathComponent(newName)
      try? FileManager.default.moveItem(at: node.file, to: newURL)
      node.file = newURL
    })
    UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
  }

  struct FileDropDelegate: DropDelegate {
    let target: FileNode
    @Binding var rootNodes: [FileNode]

    func performDrop(info: DropInfo) -> Bool {
      guard target.isFolder else { return false }
      for item in info.itemProviders(for: [.fileURL]) {
        item.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
          if let urlData = data as? Data, let sourceURL = URL(dataRepresentation: urlData, relativeTo: nil) {
            let destURL = target.file.appendingPathComponent(sourceURL.lastPathComponent)
            try? FileManager.default.moveItem(at: sourceURL, to: destURL)
            DispatchQueue.main.async {
              target.children.append(FileNode(file: destURL))
            }
          }
        }
      }
      return true
    }
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
