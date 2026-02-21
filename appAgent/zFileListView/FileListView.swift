import UIKit
import SwiftUI

extension Notification.Name {
  static let openFileInEditor = Notification.Name("openFileInEditor")
}

final class FileNode {
  let url: URL
  var children: [FileNode] = []
  var isExpanded = false
  var isFolder: Bool { url.hasDirectoryPath }

  init(url: URL) { self.url = url }
}

final class FileListViewController: UITableViewController {

  private var rootNodes: [FileNode] = []
  private var visibleNodes: [(node: FileNode, depth: Int)] = []

  private var renamingIndexPath: IndexPath?
  private var renamingTextField: UITextField?

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

    // Icon
    var content = cell.defaultContentConfiguration()
    content.image = UIImage(systemName: node.isFolder ? "folder.fill" : "doc.text")
    
    // Wenn Rename läuft für diese Zeile, nur Textfeld + Häkchen
    if renamingIndexPath == indexPath {
      let tf = UITextField()
      tf.text = node.url.lastPathComponent
      tf.borderStyle = .roundedRect
      tf.translatesAutoresizingMaskIntoConstraints = false
      tf.addTarget(self, action: #selector(renameCommitWithCheck), for: .editingDidEndOnExit)
      renamingTextField = tf

      let checkButton = UIButton(type: .system)
      checkButton.setTitle("✔︎", for: .normal)
      checkButton.addTarget(self, action: #selector(renameCommitWithCheck), for: .touchUpInside)
      checkButton.translatesAutoresizingMaskIntoConstraints = false

      let stack = UIStackView(arrangedSubviews: [tf, checkButton])
      stack.axis = .horizontal
      stack.spacing = 6
      stack.alignment = .center
      stack.translatesAutoresizingMaskIntoConstraints = false

      cell.contentView.subviews.forEach { $0.removeFromSuperview() }
      cell.contentView.addSubview(stack)
      NSLayoutConstraint.activate([
        stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
        stack.trailingAnchor.constraint(lessThanOrEqualTo: cell.contentView.trailingAnchor, constant: -16),
        stack.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
        tf.widthAnchor.constraint(equalToConstant: 200)
      ])
      tf.becomeFirstResponder()
      cell.accessoryView = nil
      content.text = nil
    } else {
      content.text = node.url.lastPathComponent
      cell.accessoryView = nil
      // Pfeil für Folder
      if node.isFolder {
        let symbolName = node.isExpanded ? "chevron.down" : "chevron.right"
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image = UIImage(systemName: symbolName, withConfiguration: config)
        cell.accessoryView = UIImageView(image: image)
      }
    }

    cell.contentConfiguration = content
    return cell
  }

  override func tableView(_ tableView: UITableView,
                          didSelectRowAt indexPath: IndexPath) {
    // Beim Rename-Modus nicht öffnen
    if renamingIndexPath == indexPath { return }

    let node = visibleNodes[indexPath.row].node
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

    let delete = UIContextualAction(style: .destructive, title: "Löschen") { _, _, completion in
      try? FileManager.default.removeItem(at: node.url)
      self.loadFolder(self.rootNodes.first?.url.deletingLastPathComponent() ?? node.url)
      completion(true)
    }

    let rename = UIContextualAction(style: .normal, title: "Umbenennen") { _, _, completion in
      self.renamingIndexPath = indexPath
      self.tableView.reloadRows(at: [indexPath], with: .none)
      completion(true)
    }

    return UISwipeActionsConfiguration(actions: [delete, rename])
  }

  @objc private func renameCommitWithCheck() {
    guard let indexPath = renamingIndexPath,
          let tf = renamingTextField,
          let text = tf.text,
          !text.isEmpty
    else { return }

    let node = visibleNodes[indexPath.row].node
    let newURL = node.url.deletingLastPathComponent().appendingPathComponent(text)
    try? FileManager.default.moveItem(at: node.url, to: newURL)

    renamingIndexPath = nil
    renamingTextField = nil
    loadFolder(rootNodes.first?.url.deletingLastPathComponent() ?? newURL)
  }
}

struct FileListView: UIViewControllerRepresentable {
  let projectFolder: URL

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeUIViewController(context: Context) -> FileListViewController {
    let vc = FileListViewController()
    vc.loadFolder(projectFolder)
    vc.onFileSelected = { url in context.coordinator.openFile(url) }
    return vc
  }

  func updateUIViewController(_ uiViewController: FileListViewController, context: Context) {}

  class Coordinator {
    let parent: FileListView
    init(_ parent: FileListView) { self.parent = parent }
    func openFile(_ url: URL) {
      NotificationCenter.default.post(name: .openFileInEditor, object: url)
    }
  }
}
