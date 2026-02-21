import UIKit
import SwiftUI

// MARK: - Model

final class FileNode {
  let url: URL
  var children: [FileNode] = []
  var isExpanded = false
  var isFolder: Bool { url.hasDirectoryPath }

  init(url: URL) {
    self.url = url
  }
}

// MARK: - UIKit Controller

final class FileListViewController: UITableViewController {

  private var rootNodes: [FileNode] = []
  private var visibleNodes: [(node: FileNode, depth: Int)] = []

  private var renamingIndexPath: IndexPath?
  private var renamingTextField: UITextField?

  func loadFolder(_ folder: URL) {
    rootNodes = loadChildren(of: folder)
    rebuildVisible()
    tableView.reloadData()
  }

  private func loadChildren(of folder: URL) -> [FileNode] {
    let fm = FileManager.default
    guard let urls = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
    else { return [] }

    return urls
      .sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }
      .map { FileNode(url: $0) }
  }

  private func rebuildVisible() {
    visibleNodes.removeAll()
    for node in rootNodes {
      append(node, depth: 0)
    }
  }

  private func append(_ node: FileNode, depth: Int) {
    visibleNodes.append((node, depth))
    if node.isExpanded {
      for child in node.children {
        append(child, depth: depth + 1)
      }
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
  }

  override func tableView(_ tableView: UITableView,
                          numberOfRowsInSection section: Int) -> Int {
    visibleNodes.count
  }

  override func tableView(_ tableView: UITableView,
                          cellForRowAt indexPath: IndexPath) -> UITableViewCell {

    let item = visibleNodes[indexPath.row]
    let node = item.node

    let cell = tableView.dequeueReusableCell(withIdentifier: "cell",
                                             for: indexPath)

    var content = cell.defaultContentConfiguration()
    content.text = node.url.lastPathComponent
    content.image = UIImage(systemName: node.isFolder ? "folder.fill" : "doc.text")
    cell.contentConfiguration = content

    cell.indentationLevel = item.depth
    cell.indentationWidth = 20

    cell.accessoryView = nil
    if node.isFolder {
      let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
      arrow.transform = node.isExpanded ? CGAffineTransform(rotationAngle: .pi/2) : .identity
      cell.accessoryView = arrow
    }

    if renamingIndexPath == indexPath {
      let tf = UITextField(frame: CGRect(x: 0, y: 0, width: 200, height: 30))
      tf.text = node.url.lastPathComponent
      tf.borderStyle = .roundedRect
      tf.addTarget(self, action: #selector(renameCommit),
                   for: .editingDidEndOnExit)
      cell.accessoryView = tf
      renamingTextField = tf
      tf.becomeFirstResponder()
    }

    return cell
  }

  override func tableView(_ tableView: UITableView,
                          didSelectRowAt indexPath: IndexPath) {

    let node = visibleNodes[indexPath.row].node

    guard node.isFolder else { return }

    if node.children.isEmpty {
      node.children = loadChildren(of: node.url)
    }

    node.isExpanded.toggle()
    rebuildVisible()
    tableView.reloadData()
  }

  override func tableView(_ tableView: UITableView,
                          trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
  -> UISwipeActionsConfiguration? {

    let node = visibleNodes[indexPath.row].node

    let delete = UIContextualAction(style: .destructive,
                                     title: "Löschen") { _, _, completion in
      try? FileManager.default.removeItem(at: node.url)
      self.loadFolder(self.rootNodes.first?.url.deletingLastPathComponent() ?? node.url)
      completion(true)
    }

    let rename = UIContextualAction(style: .normal,
                                     title: "Umbenennen") { _, _, completion in
      self.renamingIndexPath = indexPath
      self.tableView.reloadRows(at: [indexPath], with: .none)
      completion(true)
    }

    return UISwipeActionsConfiguration(actions: [delete, rename])
  }

  @objc private func renameCommit() {
    guard let indexPath = renamingIndexPath,
          let tf = renamingTextField,
          let text = tf.text
    else { return }

    let node = visibleNodes[indexPath.row].node
    let newURL = node.url.deletingLastPathComponent().appendingPathComponent(text)

    try? FileManager.default.moveItem(at: node.url, to: newURL)

    renamingIndexPath = nil
    loadFolder(rootNodes.first?.url.deletingLastPathComponent() ?? newURL)
  }
}

// MARK: - SwiftUI Bridge

struct FileListView: UIViewControllerRepresentable {

  let projectFolder: URL

  func makeUIViewController(context: Context) -> FileListViewController {
    let vc = FileListViewController()
    vc.loadFolder(projectFolder)
    return vc
  }

  func updateUIViewController(_ uiViewController: FileListViewController,
                              context: Context) {
  }
}
