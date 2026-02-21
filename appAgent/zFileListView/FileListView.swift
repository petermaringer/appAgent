import UIKit
import SwiftUI

// MARK: - Notification für SwiftUI Sheet
extension Notification.Name {
  static let openFileInEditor = Notification.Name("openFileInEditor")
}

// MARK: - File Node
final class FileNode {
  var url: URL
  var children: [FileNode] = []
  var isExpanded = false
  var isFolder: Bool { url.hasDirectoryPath }
  var isRenaming = false   // Rename-Status direkt im Node

  init(url: URL) { self.url = url }
}

// MARK: - UIKit Controller
final class FileListViewController: UITableViewController {

  private var rootNodes: [FileNode] = []
  private var visibleNodes: [(node: FileNode, depth: Int)] = []

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
    for node in rootNodes { append(node, depth: 0) }
  }

  private func append(_ node: FileNode, depth: Int) {
    visibleNodes.append((node, depth))
    if node.isExpanded {
      for child in node.children { append(child, depth: depth + 1) }
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
    cell.indentationLevel = item.depth
    cell.indentationWidth = 20
    cell.accessoryView = nil

    // Icon + Text oder TextField+Häkchen
    if node.isRenaming && !node.isFolder {

      let tf = UITextField(frame: CGRect(x: 0, y: 0, width: 200, height: 30))
      tf.text = node.url.lastPathComponent
      tf.borderStyle = .roundedRect
      tf.returnKeyType = .done
      tf.addTarget(self, action: #selector(renameCommitTextField(_:)), for: .editingDidEndOnExit)
      renamingTextField = tf

      let check = UIButton(type: .system)
      check.setTitle("✅", for: .normal)
      check.addAction(UIAction { _ in
        self.renameCommitButton(for: node)
      }, for: .touchUpInside)

      let stack = UIStackView(arrangedSubviews: [tf, check])
      stack.axis = .horizontal
      stack.spacing = 8
      cell.accessoryView = stack

    } else {
      var content = cell.defaultContentConfiguration()
      content.text = node.url.lastPathComponent
      content.image = UIImage(systemName: node.isFolder ? "folder.fill" : "doc.text")
      cell.contentConfiguration = content

      if node.isFolder {
        let symbolName = node.isExpanded ? "chevron.down" : "chevron.right"
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image = UIImage(systemName: symbolName, withConfiguration: config)
        let arrow = UIImageView(image: image)
        cell.accessoryView = arrow
      }
    }

    return cell
  }

  override func tableView(_ tableView: UITableView,
                          didSelectRowAt indexPath: IndexPath) {

    let node = visibleNodes[indexPath.row].node

    // Wenn Rename aktiv, nichts tun
    if node.isRenaming { return }

    if node.isFolder {
      if node.children.isEmpty { node.children = loadChildren(of: node.url) }
      node.isExpanded.toggle()
      rebuildVisible()
      tableView.reloadData()
    } else {
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

    let rename = UIContextualAction(style: .normal, title: "Umbenennen") { _, _, completion in
      node.isRenaming = true
      self.tableView.reloadRows(at: [indexPath], with: .none)
      completion(true)
    }

    return UISwipeActionsConfiguration(actions: [delete, rename])
  }

  @objc private func renameCommitTextField(_ tf: UITextField) {
    guard let indexPath = visibleNodes.firstIndex(where: { $0.node.isRenaming }),
          let text = tf.text else { return }
    let node = visibleNodes[indexPath].node
    commitRename(node, newName: text)
  }

  private func renameCommitButton(for node: FileNode) {
    guard let text = renamingTextField?.text else { return }
    commitRename(node, newName: text)
  }

  private func commitRename(_ node: FileNode, newName: String) {
    let newURL = node.url.deletingLastPathComponent().appendingPathComponent(newName)
    try? FileManager.default.moveItem(at: node.url, to: newURL)
    node.url = newURL
    node.isRenaming = false

    if let row = visibleNodes.firstIndex(where: { $0.node === node }) {
      tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
    }
  }
}
