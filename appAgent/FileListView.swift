import SwiftUI

struct FileListView: View {
  let projectFolder: URL
  @State private var rootFiles: [FileNode] = []
  @State private var selectedFile: FileNode?
  @State private var targetFile: URL?
  @State private var renamingNode: FileNode?
  @State private var newName: String = ""

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

  var body: some View {
    VStack(alignment: .leading) {
      Text("Projekt-Dateien")
        .font(.headline)
        .padding(.bottom, 5)

      List {
        OutlineGroup(rootFiles, children: \.children) { node in
          HStack {
            if node.isFolder {
              Image(systemName: "folder.fill")
                .foregroundColor(.blue)
            } else {
              Image(systemName: "doc.text")
            }

            if renamingNode?.id == node.id {
              TextField("", text: $newName, onCommit: { renameNode(node) })
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
              Button("Löschen", role: .destructive) { deleteNode(node) }
              Button("Umbenennen") {
                renamingNode = node
                newName = node.file.lastPathComponent
              }
            }
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

struct FileNodeDropDelegate: DropDelegate {
  let destination: FileListView.FileNode

  func performDrop(info: DropInfo) -> Bool {
    guard destination.isFolder,
          let item = info.itemProviders(for: ["public.file-url"]).first else { return false }

    item.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
      guard let data = data as? Data,
            let url = NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL? else { return }

      let destURL = destination.file.appendingPathComponent(url.lastPathComponent)
      try? FileManager.default.moveItem(at: url, to: destURL)

      DispatchQueue.main.async {
        destination.reloadChildren()
      }
    }
    return true
  }
}

/*import SwiftUI

struct FileListView: View {
  let projectFolder: URL
  @State private var rootFiles: [FileNode] = []
  @State private var selectedFile: FileNode?
  @State private var targetFile: URL?
  
  @State private var showingEditor: Bool = false
  @State private var renamingNode: FileNode?
  @State private var newName: String = ""
  
  class FileNode: Identifiable, ObservableObject {
    let id = UUID()
    @Published var file: URL
    @Published var children: [FileNode]? = nil
    @Published var isExpanded: Bool = false
    
    init(file: URL) {
      self.file = file
      reloadChildren()
    }
    
    func reloadChildren() {
      guard file.hasDirectoryPath else { children = nil; return }
      let fm = FileManager.default
      if let sub = try? fm.contentsOfDirectory(at: file, includingPropertiesForKeys: nil) {
        children = sub.map { FileNode(file: $0) }
          .sorted { $0.file.lastPathComponent.lowercased() < $1.file.lastPathComponent.lowercased() }
      } else {
        children = []
      }
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
            if node.file.hasDirectoryPath {
              Image(systemName: node.isExpanded ? "folder.open.fill" : "folder.fill")
                .foregroundColor(.blue)
            }
            
            if renamingNode?.id == node.id {
              TextField("", text: $newName, onCommit: { renameNode(node) })
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
            } else {
              Text(node.file.lastPathComponent)
                .foregroundColor(node.file == targetFile ? .yellow : (node.file.hasDirectoryPath ? .blue : .primary))
            }
            
            Spacer()
            
            if node.file == targetFile {
              Image(systemName: "star.fill")
                .foregroundColor(.yellow)
            }
          }
          .contentShape(Rectangle())
          .padding(.leading, indentation(for: node))
          .onTapGesture {
            selectedFile = node
            if node.file.hasDirectoryPath {
              node.isExpanded.toggle()
              node.reloadChildren()
            }
          }
          .onDrag {
            NSItemProvider(object: node.file as NSURL)
          }
          .onDrop(of: ["public.file-url"], delegate: FileNodeDropDelegate(destination: node))
          .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !node.file.hasDirectoryPath {
              Button("Löschen", role: .destructive) { deleteNode(node) }
              Button("Umbenennen") {
                renamingNode = node
                newName = node.file.lastPathComponent
              }
            }
          }
        }
      }
    }
    .onAppear(perform: loadFiles)
    .sheet(item: $selectedFile) { item in
      if !item.file.hasDirectoryPath {
        FileEditorView(fileURL: item.file)
      }
    }
  }
  
  func indentation(for node: FileNode) -> CGFloat {
    var depth = 0
    var parent = findParent(of: node, in: rootFiles)
    while parent != nil {
      depth += 1
      parent = findParent(of: parent!, in: rootFiles)
    }
    return CGFloat(depth * 20)
  }
  
  func findParent(of child: FileNode, in nodes: [FileNode]) -> FileNode? {
    for node in nodes {
      if node.children?.contains(where: { $0.id == child.id }) ?? false {
        return node
      }
      if let sub = node.children, let found = findParent(of: child, in: sub) {
        return found
      }
    }
    return nil
  }
  
  func loadFiles() {
    rootFiles = [FileNode(file: projectFolder)]
  }
  
  func renameNode(_ node: FileNode) {
    guard !newName.isEmpty else { return }
    let newURL = node.file.deletingLastPathComponent().appendingPathComponent(newName)
    do {
      try FileManager.default.moveItem(at: node.file, to: newURL)
      node.file = newURL
      node.reloadChildren()
    } catch {
      print("Fehler beim Umbenennen: \(error)")
    }
    renamingNode = nil
  }
  
  func deleteNode(_ node: FileNode) {
    do {
      try FileManager.default.removeItem(at: node.file)
      removeNode(node, from: &rootFiles)
    } catch {
      print("Fehler beim Löschen: \(error)")
    }
  }
  
  func removeNode(_ node: FileNode, from array: inout [FileNode]) {
    if let index = array.firstIndex(where: { $0.id == node.id }) {
      array.remove(at: index)
      return
    }
    for i in 0..<array.count {
      if var children = array[i].children {
        removeNode(node, from: &children)
        array[i].children = children
      }
    }
  }
}

// MARK: - Drop Delegate für stabilen Ordner-Drag
struct FileNodeDropDelegate: DropDelegate {
  let destination: FileListView.FileNode
  
  func performDrop(info: DropInfo) -> Bool {
    guard let item = info.itemProviders(for: ["public.file-url"]).first else { return false }
    item.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, error in
      guard let data = data as? Data,
            let url = NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL? else { return }
      let destURL = destination.file.appendingPathComponent(url.lastPathComponent)
      do {
        try FileManager.default.moveItem(at: url, to: destURL)
        DispatchQueue.main.async {
          destination.reloadChildren()
        }
      } catch {
        print("Fehler beim Verschieben: \(error)")
      }
    }
    return true
  }
}*/

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
