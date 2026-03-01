import Foundation

class ProjectEngine: ObservableObject, Identifiable, Hashable {
  let id = UUID()
  let projectFolder: URL
  
  static func == (lhs: ProjectEngine, rhs: ProjectEngine) -> Bool {
    lhs.id == rhs.id
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
  
  @Published var promptHistory: [String] = []

  var projectName: String { projectFolder.lastPathComponent }
  var projectFile: URL { projectFolder.appendingPathComponent(".project.json") }
  
  init(projectFolder: URL) {
    self.projectFolder = projectFolder
    let backupFolder = projectFolder.appendingPathComponent("Backups")
    if !FileManager.default.fileExists(atPath: backupFolder.path) {
      try? FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)
    }
  }

  func generateOrUpdateProject(userPrompt: String, kiService: KIService) async throws {
    promptHistory.append(userPrompt)

    // Alle Swift-Dateien rekursiv suchen
    let files = try recursiveSwiftFiles(in: projectFolder)

    // ContentView.swift bevorzugt, sonst letzte Swift-Datei
    let targetFile = files.first(where: { $0.lastPathComponent == "ContentView.swift" }) ?? files.last

    guard let targetFile = targetFile else { return }

    try backupFile(targetFile)

    var context = ""
    for file in files {
      let text = try String(contentsOf: file)
      context += "\n// --- \(file.lastPathComponent) ---\n"
      context += text
    }

    let newContent = try await kiService.generateCode(prompt: userPrompt, context: context)
    try newContent.write(to: targetFile, atomically: true, encoding: .utf8)
  }

  private func backupFile(_ file: URL) throws {
    let backupFolder = projectFolder.appendingPathComponent("Backups")
    let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
    let backupFile = backupFolder.appendingPathComponent("\(file.lastPathComponent)_\(timestamp).swift")
    try FileManager.default.copyItem(at: file, to: backupFile)
  }

  // MARK: - Rekursive Suche nach allen Swift-Dateien
  private func recursiveSwiftFiles(in folder: URL) throws -> [URL] {
    var result: [URL] = []
    let fm = FileManager.default
    let contents = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)

    for item in contents {
      if item.hasDirectoryPath {
        result.append(contentsOf: try recursiveSwiftFiles(in: item))
      } else if item.pathExtension == "swift" {
        result.append(item)
      }
    }
    return result
  }
}

/*import Foundation

class ProjectEngine: ObservableObject, Identifiable {
  let id = UUID()
  let projectFolder: URL
  @Published var promptHistory: [String] = []
  
  var projectName: String { projectFolder.lastPathComponent }
  
  init(projectFolder: URL) {
    self.projectFolder = projectFolder
    let backupFolder = projectFolder.appendingPathComponent("Backups")
    if !FileManager.default.fileExists(atPath: backupFolder.path) {
      try? FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)
    }
  }
  
  func generateOrUpdateProject(userPrompt: String, kiService: KIService) async throws {
    promptHistory.append(userPrompt)
    
    let files = try FileManager.default.contentsOfDirectory(at: projectFolder, includingPropertiesForKeys: nil).filter { $0.pathExtension == "swift" }
    let targetFile = files.last ?? projectFolder.appendingPathComponent("ContentView.swift")
    
    try backupFile(targetFile)
    
    var context = ""
    for file in files {
      let text = try String(contentsOf: file)
      context += "\n// --- \(file.lastPathComponent) ---\n"
      context += text
    }
    
    let newContent = try await kiService.generateCode(prompt: userPrompt, context: context)
    try newContent.write(to: targetFile, atomically: true, encoding: .utf8)
  }
  
  private func backupFile(_ file: URL) throws {
    let backupFolder = projectFolder.appendingPathComponent("Backups")
    let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
    let backupFile = backupFolder.appendingPathComponent("\(file.lastPathComponent)_\(timestamp).swift")
    try FileManager.default.copyItem(at: file, to: backupFile)
  }
}*/
