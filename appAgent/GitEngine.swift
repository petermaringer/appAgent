import Foundation
import Observation

//actor GitEngine {
@Observable
class GitEngine {
  private(set) var overwriteConfirmed = false
  func setOverwriteConfirmed(_ value: Bool) { overwriteConfirmed = value }
  
  private let project: ProjectEngine
  init(project: ProjectEngine) { self.project = project }
  /*static var currentProject: ProjectEngine!
  private var project: ProjectEngine {
    GitEngine.currentProject
  }*/
  
  /*var status: GitStatus = .idle {
    didSet { onStatusChange?(status) }
  }
  var onStatusChange: ((GitStatus) -> Void)?*/
  /*var onStatusChange: ((GitStatus) -> Void)?

  func setOnStatusChange(_ callback: @escaping (GitStatus) -> Void) {
    onStatusChange = callback
  }
  
    // --- HIER HINZUFÜGEN ---
  func setStatus(_ newStatus: GitStatus) {
    status = newStatus
    Task { @MainActor in
      await onStatusChange?(newStatus)
    }
  }
  // --- ENDE HINZUFÜGEN ---*/
  
  func setStatus(_ newStatus: GitStatus) {
  Task { @MainActor in
    if newStatus == .missingCredentials || newStatus.isImmediateError {
      try? await Task.sleep(nanoseconds: 200_000_000)
    }
    status = newStatus
  }
}

  /*var status: GitStatus = .idle {
    //didSet { onStatusChange?(status) }
    didSet {
      Task { @MainActor in      // <--- Hier ist der MainActor wichtig
        //onStatusChange?(status)
        await onStatusChange?(status)
      }
    }
  }*/
  var status: GitStatus = .idle
  
  //func performPush() async -> GitStatus {
  func performPush() async {
    
    //status = .idle
   
    status = .checkingRepo
     //await Task.yield()
   //setStatus(.checkingRepo)
   /*let callback = onStatusChange
await MainActor.run {
    callback?(.checkingRepo)
}*/
//try? await Task.sleep(nanoseconds: 150_000_000)
    
    let token = UserDefaults.standard.string(forKey: "githubToken") ?? ""
    let owner = UserDefaults.standard.string(forKey: "githubOwner") ?? ""
    guard !token.isEmpty, !owner.isEmpty else {
    //return .missingCredentials
    //status = .missingCredentials
    setStatus(.missingCredentials)
      return
    }
    
    var needsGitSettingsFlag = false
let projectURL = project.projectFolder.appendingPathComponent(".project.json")

do {
  let projectData = try? Data(contentsOf: projectURL)
  if projectData == nil || projectData!.isEmpty {
    needsGitSettingsFlag = true
  } else {
    let json = try JSONSerialization.jsonObject(with: projectData!) as! [String: Any]
    if json["isPublic"] as? Bool == nil || (json["branch"] as? String ?? "").isEmpty {
      needsGitSettingsFlag = true
    }
  }
} catch {
  status = .error("Fehler beim Lesen der Project-JSON: \(error.localizedDescription)")
  return
}
    
    if let url = URL(string: "https://api.github.com/user") {
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.httpMethod = "GET"
    request.cachePolicy = .reloadIgnoringLocalCacheData
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse else {
      status = .error("Keine Antwort")
      return
      }
      switch http.statusCode {
        case 200:
          // Token ist gültig → check Owner
          if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
             let login = json["login"] as? String,
             login.lowercased() != owner.lowercased() {
            status = .forbidden // Token stimmt nicht mit Owner überein
            return
          }
        case 401: status = .unauthorized
        return
        case 403: status = .forbidden
        return
        default: status = .error("HTTP \(http.statusCode)")
        return
      }
    } catch {
      status = .error(error.localizedDescription)
      return
    }
  } else {
    status = .error("Ungültige User-URL")
    return
  }
    
    let repoName = project.projectName
    
    guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repoName)") else {
    status = .error("Ungültige URL")
    return
    }
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.httpMethod = "GET"
    request.cachePolicy = .reloadIgnoringLocalCacheData
    
    do {
      let (_, response) = try await URLSession.shared.data(for: request)
      if let http = response as? HTTPURLResponse {
        switch http.statusCode {
          case 200:
            if !overwriteConfirmed && needsGitSettingsFlag {
            status = .repoExists
            return
            }
          case 401: status = .unauthorized
          return
          case 403: status = .forbidden
          return
          case 404: break
          default: status = .error("HTTP \(http.statusCode)")
          return
        }
      }
    } catch {
      status = .error(error.localizedDescription)
      return
    }
    
    if needsGitSettingsFlag { status = .needsGitSettings
    return
    }
    
    /*let projectURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
      .first?.appendingPathComponent("project.json")
    guard let projectData = try? Data(contentsOf: projectURL ?? URL(fileURLWithPath: "")), !projectData.isEmpty else {
      return .needsGitSettings
    }*/
    /*let projectURL = project.projectFolder.appendingPathComponent(".project.json")
    guard let projectData = try? Data(contentsOf: projectURL), !projectData.isEmpty else {
      return .needsGitSettings
    }*/
    
    status = .success
    
  }
}

extension GitStatus {
  var isImmediateError: Bool {
    switch self {
      case .error(_):
        return true
      default:
        return false
    }
  }
}
