import UIKit
import SwiftUI

// MARK: - Notification für SwiftUI Sheet
extension Notification.Name {
  static let openFileInEditor = Notification.Name("openFileInEditor")
}

// MARK: - File Node
final class FileNode: Identifiable {
  var id = UUID()
  var url: URL
  var children: [FileNode] = []
  var isExpanded = false
  var isFolder: Bool { url.hasDirectoryPath }
  var isRenaming = false

  init(url: URL) {
    self.url = url
  }
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
    guard let urls = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return [] }
    return urls.sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }
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
    tableView.dragInteractionEnabled = true
    tableView.dragDelegate = self
    tableView.dropDelegate = self
  }

  // MARK: - UITableView DataSource / Delegate
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    visibleNodes.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

    let item = visibleNodes[indexPath.row]
    let node = item.node

    let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
    var content = cell.defaultContentConfiguration()

    content.image = UIImage(systemName: node.isFolder ? "folder.fill" : "doc.text")
    cell.contentConfiguration = content
    cell.indentationLevel = item.depth
    cell.indentationWidth = 20

    // Pfeile für Ordner
    if node.isFolder {
      let symbolName = node.isExpanded ? "chevron.down" : "chevron.right"
      let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
      let image = UIImage(systemName: symbolName, withConfiguration: config)
      let arrow = UIImageView(image: image)
      cell.accessoryView = arrow
    } else {
      cell.accessoryView = nil
    }

    // Rename-Modus
    if node.isRenaming {
      let tf = UITextField(frame: .zero)
      tf.translatesAutoresizingMaskIntoConstraints = false
      tf.text = node.url.lastPathComponent
      tf.borderStyle = .roundedRect
      tf.returnKeyType = .done

      let button = UIButton(type: .system)
      button.setTitle("✅", for: .normal)
      button.addAction(UIAction { [weak self] _ in
        self?.commitRename(node: node)
      }, for: .touchUpInside)

      let stack = UIStackView(arrangedSubviews: [tf, button])
      stack.axis = .horizontal
      stack.spacing = 8
      stack.alignment = .center

      cell.contentView.subviews.forEach { $0.removeFromSuperview() }
      cell.contentView.addSubview(stack)
      NSLayoutConstraint.activate([
        stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16 + CGFloat(item.depth) * 20),
        stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
        stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 4),
        stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -4)
      ])

      renamingTextField = tf
      tf.becomeFirstResponder()
    } else {
      content.text = node.url.lastPathComponent
      cell.contentConfiguration = content
    }

    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let node = visibleNodes[indexPath.row].node
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
                          trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

    let node = visibleNodes[indexPath.row].node

    let delete = UIContextualAction(style: .destructive, title: "Löschen") { _, _, completion in
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

  // MARK: - Rename Commit
  private func commitRename(node: FileNode) {
    guard let tf = renamingTextField, let text = tf.text else { return }
    let newURL = node.url.deletingLastPathComponent().appendingPathComponent(text)
    try? FileManager.default.moveItem(at: node.url, to: newURL)
    node.url = newURL
    node.isRenaming = false
    rebuildVisible()
    tableView.reloadData()
  }
}

// MARK: - Drag & Drop
extension FileListViewController: UITableViewDragDelegate, UITableViewDropDelegate {
  func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
    let node = visibleNodes[indexPath.row].node
    guard !node.isFolder && !node.isRenaming else { return [] }
    let provider = NSItemProvider(object: node.url as NSURL)
    return [UIDragItem(itemProvider: provider)]
  }

  func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) { }

  func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    let node = visibleNodes[indexPath.row].node
    return !node.isFolder && !node.isRenaming
  }

  func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
    let sourceNode = visibleNodes[sourceIndexPath.row].node
    let destNode = visibleNodes[destinationIndexPath.row].node
    guard destNode.isFolder else { return }

    let newURL = destNode.url.appendingPathComponent(sourceNode.url.lastPathComponent)
    try? FileManager.default.moveItem(at: sourceNode.url, to: newURL)
    sourceNode.url = newURL
    if let idx = rootNodes.firstIndex(where: { $0 === sourceNode }) { rootNodes.remove(at: idx) }
    destNode.children.append(sourceNode)
    rebuildVisible()
    tableView.reloadData()
  }

  func tableView(_ tableView: UITableView,
                 targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
                 toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
    let destNode = visibleNodes[proposedDestinationIndexPath.row].node
    return destNode.isFolder ? proposedDestinationIndexPath : sourceIndexPath
  }
}

// MARK: - SwiftUI Bridge
struct FileListView: UIViewControllerRepresentable {
  let projectFolder: URL

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeUIViewController(context: Context) -> FileListViewController {
    let vc = FileListViewController()
    vc.loadFolder(projectFolder)
    vc.onFileSelected = { url in context.coordinator.openFile(url) }
    return vc
  }

  func updateUIViewController(_ uiViewController: FileListViewController, context: Context) { }

  class Coordinator {
    let parent: FileListView
    init(_ parent: FileListView) { self.parent = parent }

    func openFile(_ url: URL) {
      NotificationCenter.default.post(name: .openFileInEditor, object: url)
    }
  }
}
