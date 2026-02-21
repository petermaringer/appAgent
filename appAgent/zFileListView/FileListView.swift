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
  private var renamingCheckButton: UIButton?

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
    cell.contentView.subviews.forEach { $0.removeFromSuperview() } // alte Subviews entfernen

    var content = cell.defaultContentConfiguration()
    content.text = node.url.lastPathComponent
    content.image = UIImage(systemName: node.isFolder ? "folder.fill" : "doc.text")
    cell.contentConfiguration = content

    cell.indentationLevel = item.depth
    cell.indentationWidth = 20

    // Pfeile mit nativer Breite
    cell.accessoryView = nil
    if node.isFolder {
      let symbolName = node.isExpanded ? "chevron.down" : "chevron.right"
      let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
      let image = UIImage(systemName: symbolName, withConfiguration: config)
      let arrow = UIImageView(image: image)
      cell.accessoryView = arrow
    }

    // Rename-Modus
    if renamingIndexPath == indexPath {
      let tf = UITextField()
      tf.text = node.url.lastPathComponent
      tf.borderStyle = .roundedRect
      tf.translatesAutoresizingMaskIntoConstraints = false
      cell.contentView.addSubview(tf)
      renamingTextField = tf
      tf.becomeFirstResponder()

      let check = UIButton(type: .system)
      check.setTitle("✅", for: .normal)
      check.translatesAutoresizingMaskIntoConstraints = false
      cell.contentView.addSubview(check)
      renamingCheckButton = check
      check.addAction(UIAction { [weak self] _ in
        self?.renameCommit()
      }, for: .touchUpInside)

      // AutoLayout: Textfeld links, Häkchen rechts, Icon unverändert
      NSLayoutConstraint.activate([
        tf.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor, constant: 24),
        tf.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
        tf.trailingAnchor.constraint(equalTo: check.leadingAnchor, constant: -8),
        tf.heightAnchor.constraint(equalToConstant: 30),

        check.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
        check.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
        check.widthAnchor.constraint(equalToConstant: 30),
        check.heightAnchor.constraint(equalToConstant: 30)
      ])
    }

    return cell
  }

  override func tableView(_ tableView: UITableView,
                          didSelectRowAt indexPath: IndexPath) {

    let node = visibleNodes[indexPath.row].node

    // Wenn Rename aktiv und Datei → nichts tun
    if renamingIndexPath == indexPath && !node.isFolder { return }

    if node.isFolder {
      if node.children.isEmpty {
        node.children = loadChildren(of: node.url)
      }
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
          let text = tf.text, !text.isEmpty
    else { return }

    let node = visibleNodes[indexPath.row].node
    let newURL = node.url.deletingLastPathComponent().appendingPathComponent(text)

    try? FileManager.default.moveItem(at: node.url, to: newURL)

    renamingIndexPath = nil
    renamingTextField = nil
    renamingCheckButton = nil

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
