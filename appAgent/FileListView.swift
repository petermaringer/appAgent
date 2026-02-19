import SwiftUI

struct FileListView: View {
  let projectFolder: URL
  @State private var files: [IdentifiableFile] = []
  @State private var selectedFile: IdentifiableFile?
  @State private var targetFile: URL?

  @State private var showingEditor: Bool = false
  @State private var showingRenameAlert: Bool = false
  @State private var renameText: String = ""
  @State private var fileToRename: IdentifiableFile?

  struct IdentifiableFile: Identifiable, Equatable {
    let file: URL
    var level: Int = 0
    var id: String { file.absoluteString }
    var isFolder: Bool { file.hasDirectoryPath }
    var isExpanded: Bool = false
  }

  var body: some View {
    VStack(alignment: .leading) {
      Text("Projekt-Dateien")
        .font(.headline)
        .padding(.bottom, 5)

      List {
        ForEach(files) { item in
          FileRow(item: item)
            .padding(.leading, CGFloat(item.level * 16))
            .contentShape(Rectangle())
            .onTapGesture {
              if item.isFolder {
                toggleFolder(item)
              } else {
                selectedFile = item
              }
            }
            .swipeActions(edge: .trailing) {
              Button("Löschen", role: .destructive) { delete(item) }
              Button("Umbenennen") {
                fileToRename = item
                renameText = item.file.lastPathComponent
                showingRenameAlert = true
              }
            }
            .onDrag { NSItemProvider(object: item.file as NSURL) }
            .onDrop(of: [.fileURL], delegate: FileDropDelegate(item: item, files: $files))
        }
      }
    }
    .onAppear(perform: loadFiles)
    .sheet(item: $selectedFile) { item in
      FileEditorView(fileURL: item.file)
    }
    .alert("Umbenennen", isPresented: $showingRenameAlert, actions: {
      TextField("Neuer Name", text: $renameText)
      Button("OK") { if let file = fileToRename?.file { rename(file: file, to: renameText) } }
      Button("Abbrechen", role: .cancel) {}
    }, message: { Text("Gib einen neuen Namen ein") })
  }

  @ViewBuilder
  func FileRow(item: IdentifiableFile) -> some View {
    HStack {
      if item.isFolder {
        Image(systemName: item.isExpanded ? "folder.fill" : "folder")
          .foregroundColor(.blue)
      } else {
        Image(systemName: "doc.text")
          .foregroundColor(.gray)
      }

      Text(item.file.lastPathComponent)
        .foregroundColor(item.file == targetFile ? .yellow : (item.isFolder ? .blue : .primary))
        .fontWeight(item.file == targetFile ? .bold : .regular)

      Spacer()

      if item.file == targetFile {
        Image(systemName: "star.fill")
          .foregroundColor(.yellow)
      }
    }
  }

  // MARK: - File Operations
  func loadFiles() {
    files = flattenFiles(at: projectFolder, level: 0)
    if let lastModified = files.filter({ !$0.isFolder }).max(by: { f1, f2 in
      let date1 = (try? f1.file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      let date2 = (try? f2.file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      return date1 < date2
    }) {
      targetFile = lastModified.file
    }
  }

  func flattenFiles(at url: URL, level: Int) -> [IdentifiableFile] {
    let fm = FileManager.default
    guard let folderContents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return [] }

    var list: [IdentifiableFile] = []
    for file in folderContents.sorted(by: { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }) {
      var item = IdentifiableFile(file: file, level: level, isExpanded: false)
      list.append(item)
      if file.hasDirectoryPath && item.isExpanded {
        list.append(contentsOf: flattenFiles(at: file, level: level + 1))
      }
    }
    return list
  }

  func toggleFolder(_ item: IdentifiableFile) {
    guard let index = files.firstIndex(where: { $0.id == item.id }) else { return }
    files[index].isExpanded.toggle()
    files = flattenFiles(at: projectFolder, level: 0)
  }

  func delete(_ item: IdentifiableFile) {
    try? FileManager.default.removeItem(at: item.file)
    loadFiles()
  }

  func rename(file: URL, to newName: String) {
    let newURL = file.deletingLastPathComponent().appendingPathComponent(newName)
    try? FileManager.default.moveItem(at: file, to: newURL)
    loadFiles()
  }
}

// MARK: - Drag & Drop Delegate
struct FileDropDelegate: DropDelegate {
  let item: FileListView.IdentifiableFile
  @Binding var files: [FileListView.IdentifiableFile]

  func performDrop(info: DropInfo) -> Bool {
    guard let itemProvider = info.itemProviders(for: [.fileURL]).first else { return false }
    itemProvider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, error in
      guard let data = data as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
      moveFile(url: url, to: item.file)
    }
    return true
  }

  private func moveFile(url: URL, to destination: URL) {
    let fm = FileManager.default
    let targetURL = destination.hasDirectoryPath ? destination.appendingPathComponent(url.lastPathComponent) : destination.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent)
    try? fm.moveItem(at: url, to: targetURL)
    DispatchQueue.main.async {
      // force refresh
      files = files
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
