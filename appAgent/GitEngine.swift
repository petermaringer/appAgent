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
  
  ////
  private func unwrapData(_ dataOpt: Data?, _ responseOpt: HTTPURLResponse?, _ errorOpt: String?) -> (Data, HTTPURLResponse)? {
    guard let data = dataOpt, let response = responseOpt, errorOpt == nil else {
      setStatus(.error(errorOpt ?? "Keine gültige Antwort"))
      return nil
    }
    return (data, response)
  }
  
  private func fetchGitData(from urlString: String, token: String) async -> (Data?, HTTPURLResponse?, String?) {
    guard let url = URL(string: urlString) else {
      return (nil, nil, "Ungültige URL")
    }
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.httpMethod = "GET"
    request.cachePolicy = .reloadIgnoringLocalCacheData
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse else {
        return (nil, nil, "Keine gültige Antwort")
      }
      return (data, http, nil)
    } catch {
      return (nil, nil, error.localizedDescription)
    }
  }
  ////
  
  func performPush() async {
    
    setStatus(.checkingRepo)
    
    let token = UserDefaults.standard.string(forKey: "githubToken") ?? ""
    let owner = UserDefaults.standard.string(forKey: "githubOwner") ?? ""
    guard !token.isEmpty, !owner.isEmpty else {
      setStatus(.missingCredentials)
      return
    }
    
    private func checkNeedsGitSettings() -> Bool {
      let projectURL = project.projectFolder.appendingPathComponent(".project.json")
      do {
        if let projectData = try? Data(contentsOf: projectURL), !projectData.isEmpty,
           let json = try JSONSerialization.jsonObject(with: projectData) as? [String: Any] {
          return json["isPublic"] as? Bool == nil || (json["branch"] as? String ?? "").isEmpty
        }
      } catch {
        setStatus(.error("Fehler beim Lesen der Project-JSON: \(error.localizedDescription)"))
      }
      return true
    }
    let needsGitSettingsFlag = checkNeedsGitSettings()
    
    /*var needsGitSettingsFlag = false
    let projectURL = project.projectFolder.appendingPathComponent(".project.json")
    do {
      if let projectData = try? Data(contentsOf: projectURL), !projectData.isEmpty,
         let json = try JSONSerialization.jsonObject(with: projectData) as? [String: Any] {
        if json["isPublic"] as? Bool == nil || (json["branch"] as? String ?? "").isEmpty {
          needsGitSettingsFlag = true
        }
      } else {
        needsGitSettingsFlag = true
      }
    } catch {
      setStatus(.error("Fehler beim Lesen der Project-JSON: \(error.localizedDescription)"))
      return
    }*/
    
    ////
  // Aufruf 1: User
  if let (userData, userHTTP) = unwrapData(await fetchGitData(from: "https://api.github.com/user", token: token)) {
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
  }

  // Aufruf 2: Repo
  let repoName = project.projectName
  if let (repoData, repoHTTP) = unwrapData(await fetchGitData(from: "https://api.github.com/repos/\(owner)/\(repoName)", token: token)) {
    switch repoHTTP.statusCode {
      case 200:
        if !overwriteConfirmed && needsGitSettingsFlag {
          setStatus(.repoExists)
          return
        }
      case 401: setStatus(.unauthorized); return
      case 403: setStatus(.forbidden); return
      case 404: break
      default: setStatus(.error("HTTP \(repoHTTP.statusCode)")); return
    }
  }
    
    /*
    // Aufruf 1: User
    let (userDataOpt, userHTTPOpt, userErrorOpt) = await fetchGitData(from: "https://api.github.com/user", token: token)
    guard let userData = userDataOpt, let userHTTP = userHTTPOpt, userErrorOpt == nil else {
      setStatus(.error(userErrorOpt ?? "Keine gültige Antwort"))
      return
    }
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
    
    // Aufruf 2: Repo
    let repoName = project.projectName
    let (repoDataOpt, repoHTTPOpt, repoErrorOpt) = await fetchGitData(from: "https://api.github.com/repos/\(owner)/\(repoName)", token: token)
    guard let repoData = repoDataOpt, let repoHTTP = repoHTTPOpt, repoErrorOpt == nil else {
      setStatus(.error(repoErrorOpt ?? "Keine gültige Antwort"))
      return
    }
    switch repoHTTP.statusCode {
      case 200:
        if !overwriteConfirmed && needsGitSettingsFlag {
          setStatus(.repoExists)
          return
        }
      case 401: setStatus(.unauthorized); return
      case 403: setStatus(.forbidden); return
      case 404: break
      default: setStatus(.error("HTTP \(repoHTTP.statusCode)")); return
    }*/
    
    /*if let url = URL(string: "https://api.github.com/user") {
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
  }*/
    
    //let repoName = project.projectName
    /*guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repoName)") else {
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
    }*/
    
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
