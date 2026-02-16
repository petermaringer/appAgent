import SwiftUI

struct FileListView: View {
  let projectFolder: URL
  @State private var files: [URL] = []
  @State private var selectedFile: URL?
  @State private var targetFile: URL?
  @State private var showingEditor: Bool = false
  
  var body: some View {
    VStack(alignment: .leading) {
      Text("Projekt-Dateien")
        .font(.headline)
        .padding(.bottom, 5)
      
      List {
        ForEach(files, id: \.self) { file in
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
            selectedFile = file
            showingEditor = true
          }
        }
      }
    }
    .onAppear(perform: loadFiles)
    .sheet(isPresented: $showingEditor) {
      if let file = selectedFile {
        FileEditorView(fileURL: file)
      }
    }
  }
  
  func loadFiles() {
    let fm = FileManager.default
    guard let folderContents = try? fm.contentsOfDirectory(at: projectFolder, includingPropertiesForKeys: nil) else { return }
    files = folderContents.filter { $0.pathExtension == "swift" }
    if let lastModified = files.max(by: { f1, f2 in
      (try? f1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast) <
      (try? f2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast)
    }) {
      targetFile = lastModified
    }
  }
}
