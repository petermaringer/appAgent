import SwiftUI

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
              Image(systemName: expandedFolders.contains(item.url) ? "folder.open" : "folder")
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
}

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
