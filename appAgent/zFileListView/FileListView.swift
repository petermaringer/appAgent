import SwiftUI

struct FileListView: View {
  let projectFolder: URL
  @StateObject private var viewModel = FileListViewModel()

  var body: some View {
    VStack(alignment: .leading) {
      Text("Projekt-Dateien")
        .font(.headline)
        .padding(.bottom, 5)

      List {
        OutlineGroup(viewModel.rootFiles, children: \.children) { node in
          FileRowView(
            node: node,
            selectedFile: $viewModel.selectedFile,
            targetFile: $viewModel.targetFile,
            renamingNode: $viewModel.renamingNode,
            newName: $viewModel.newName,
            renameAction: { viewModel.renameNode($0, newName: viewModel.newName) },
            deleteAction: { viewModel.deleteNode($0) }
          )
        }
      }
    }
    .onAppear { viewModel.loadFiles(folder: projectFolder) }
    .sheet(item: $viewModel.selectedFile) { FileEditorView(fileURL: $0.file) }
  }
}
