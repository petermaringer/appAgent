import Foundation
import Observation

@Observable
class GitEngine {
  private(set) var overwriteConfirmed = false
  func setOverwriteConfirmed(_ value: Bool) { overwriteConfirmed = value }
  
  private let project: ProjectEngine
  init(project: ProjectEngine) { self.project = project }
  
  func setStatus(_ newStatus: GitStatus) {
    Task { @MainActor in
      if newStatus == .missingCredentials || newStatus.isImmediateError {
        try? await Task.sleep(nanoseconds: 200_000_000)
      }
      status = newStatus
    }
  }
  
  var status: GitStatus = .idle
  
  func performPush() async {
    
    setStatus(.checkingRepo)
    
    let token = UserDefaults.standard.string(forKey: "githubToken") ?? ""
    let owner = UserDefaults.standard.string(forKey: "githubOwner") ?? ""
    guard !token.isEmpty, !owner.isEmpty else {
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
      setStatus(.error("Fehler beim Lesen der Project-JSON: \(error.localizedDescription)"))
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
      setStatus(.error("Keine Antwort"))
      return
      }
      switch http.statusCode {
        case 200:
          if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
             let login = json["login"] as? String,
             login.lowercased() != owner.lowercased() {
            setStatus(.forbidden)
            return
          }
        case 401: setStatus(.unauthorized)
        return
        case 403: setStatus(.forbidden)
        return
        default: setStatus(.error("HTTP \(http.statusCode)"))
        return
      }
    } catch {
      setStatus(.error(error.localizedDescription))
      return
    }
  } else {
    setStatus(.error("Ungültige User-URL"))
    return
  }
    
    let repoName = project.projectName
    guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repoName)") else {
      setStatus(.error("Ungültige URL"))
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
              setStatus(.repoExists)
              return
            }
          case 401: setStatus(.unauthorized)
            return
          case 403: setStatus(.forbidden)
            return
          case 404: break
          default: setStatus(.error("HTTP \(http.statusCode)"))
            return
        }
      }
    } catch {
      setStatus(.error(error.localizedDescription))
      return
    }
    
    if needsGitSettingsFlag {
      setStatus(.needsGitSettings)
      return
    }
    
    setStatus(.success)
    
  }
}

extension GitStatus {
  var isImmediateError: Bool {
    switch self {
      case .error(_): return true
      default: return false
    }
  }
}
