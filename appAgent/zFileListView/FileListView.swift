import UIKit
import SwiftUI

// MARK: - Notification für SwiftUI Sheet
extension Notification.Name {
  static let openFileInEditor = Notification.Name("openFileInEditor")
}

// MARK: - File Node
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

  // Callback für Datei-Tap
  var onFileSelected: ((URL) -> Void)?

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

  let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

  var content = cell.defaultContentConfiguration()
  content.image = UIImage(systemName: node.isFolder ? "folder.fill" : "doc.text")

  // Standardtext nur anzeigen, wenn nicht umbenannt wird
  if renamingIndexPath != indexPath {
    content.text = node.url.lastPathComponent
  }

  cell.contentConfiguration = content

  cell.indentationLevel = item.depth
  cell.indentationWidth = 20

  // Pfeil als accessoryView
  cell.accessoryView = nil
  if node.isFolder {
    let symbolName = node.isExpanded ? "chevron.down" : "chevron.right"
    let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
    let image = UIImageView(image: UIImage(systemName: symbolName, withConfiguration: config))
    cell.accessoryView = image
  }

  // Rename TextField anstelle des Textes, aber Icon bleibt
  if renamingIndexPath == indexPath {
    if let tf = renamingTextField {
      tf.removeFromSuperview()
    }
    let tf = UITextField(frame: CGRect(x: 40, // rechts vom Icon (ca. 24 px Icon + Padding)
                                       y: 0,
                                       width: cell.bounds.width - 60, // Platz bis Pfeil
                                       height: cell.bounds.height))
    tf.text = node.url.lastPathComponent
    tf.borderStyle = .roundedRect
    tf.addTarget(self, action: #selector(renameCommit),
                 for: .editingDidEndOnExit)
    cell.contentView.addSubview(tf)
    renamingTextField = tf
    tf.becomeFirstResponder()
  }

  return cell
}

  override func tableView(_ tableView: UITableView,
                          didSelectRowAt indexPath: IndexPath) {

    let node = visibleNodes[indexPath.row].node

    if node.isFolder {

      if node.children.isEmpty {
        node.children = loadChildren(of: node.url)
      }

      node.isExpanded.toggle()
      rebuildVisible()
      tableView.reloadData()

    } else {
      // Datei ausgewählt → Callback
      onFileSelected?(node.url)
    }
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

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeUIViewController(context: Context) -> FileListViewController {
    let vc = FileListViewController()
    vc.loadFolder(projectFolder)
    vc.onFileSelected = { url in
      context.coordinator.openFile(url)
    }
    return vc
  }

  func updateUIViewController(_ uiViewController: FileListViewController,
                              context: Context) {
  }

  class Coordinator {
    let parent: FileListView

    init(_ parent: FileListView) {
      self.parent = parent
    }

    func openFile(_ url: URL) {
      NotificationCenter.default.post(
        name: .openFileInEditor,
        object: url
      )
    }
  }
}
