import Foundation
import Observation

@Observable
class GitEngine {
  
  private let project: ProjectEngine
  init(project: ProjectEngine) { self.project = project }
  
  var status: GitStatus = .idle
  
  func setStatus(_ newStatus: GitStatus) {
    Task { @MainActor in
      if newStatus == .missingCredentials || newStatus.isImmediateError {
        try? await Task.sleep(nanoseconds: 200_000_000)
      }
      status = newStatus
    }
  }
  
  private(set) var overwriteConfirmed = false
  func setOverwriteConfirmed(_ value: Bool) {
    overwriteConfirmed = value
  }
  
  private func checkNeedsGitSettings() -> Bool? {
    do {
      let projectData = try Data(contentsOf: project.projectFile)
      guard !projectData.isEmpty, let json = try JSONSerialization.jsonObject(with: projectData) as? [String: Any] else {
        return true
      }
      return json["isPublic"] as? Bool == nil || (json["branch"] as? String ?? "").isEmpty
    } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
      return true
    } catch {
      setStatus(.error("Fehler beim Lesen der Project-JSON: \(error.localizedDescription)"))
      return nil
    }
  }
  
  private func fetchGitData(from urlString: String, token: String) async -> (Data, HTTPURLResponse)? {
    guard let url = URL(string: urlString) else {
      setStatus(.error("Ungültige URL"))
      return nil
    }
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.httpMethod = "GET"
    request.cachePolicy = .reloadIgnoringLocalCacheData
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse else {
        setStatus(.error("Ungültige Serverantwort (keine HTTP-Response)"))
        return nil
      }
      return (data, http)
    } catch {
      setStatus(.error(error.localizedDescription))
      return nil
    }
  }
  
  func performPush() async {
    
    setStatus(.checkingRepo)
    
    let token = UserDefaults.standard.string(forKey: "githubToken") ?? ""
    let owner = UserDefaults.standard.string(forKey: "githubOwner") ?? ""
    guard !token.isEmpty, !owner.isEmpty else {
      setStatus(.missingCredentials)
      return
    }
    
    guard let (userData, userHTTP) = await fetchGitData(from: "https://api.github.com/user", token: token) else { return }
    switch userHTTP.statusCode {
      case 200:
        if let json = try? JSONSerialization.jsonObject(with: userData) as? [String: Any],
           let login = json["login"] as? String,
           login.lowercased() != owner.lowercased() {
          setStatus(.forbidden)
          return
        }
      case 401: setStatus(.unauthorized); return
      case 403: setStatus(.forbidden); return
      default: setStatus(.error("HTTP \(userHTTP.statusCode)")); return
    }
    
    guard let (_, repoHTTP) = await fetchGitData(from: "https://api.github.com/repos/\(owner)/\(project.projectName)", token: token) else { return }
    switch repoHTTP.statusCode {
      case 200:
        guard let needsGitSettings = checkNeedsGitSettings() else { return }
        if !overwriteConfirmed && needsGitSettings {
          setStatus(.repoExists)
          return
        }
      case 401: setStatus(.unauthorized); return
      case 403: setStatus(.forbidden); return
      case 404: break
      default: setStatus(.error("HTTP \(repoHTTP.statusCode)")); return
    }
    
    guard let needsGitSettings = checkNeedsGitSettings() else { return }
    if needsGitSettings {
      setStatus(.needsGitSettings)
      return
    }
    
    setStatus(.pushing(progress: 0.37))
    try? await Task.sleep(nanoseconds: 200_000_000)
    
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
