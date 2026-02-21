import SwiftUI

struct FileNodeDropDelegate: DropDelegate {
  let destination: FileNode

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
