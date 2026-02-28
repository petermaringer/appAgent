import Foundation

actor GitEngine {
  private(set) var overwriteConfirmed = false
  func setOverwriteConfirmed(_ value: Bool) { overwriteConfirmed = value }
  
  private let project: ProjectEngine
  init(project: ProjectEngine) { self.project = project }
  /*static var currentProject: ProjectEngine!
  private var project: ProjectEngine {
    GitEngine.currentProject
  }*/
  
  func performPush() async -> GitStatus {
    let token = UserDefaults.standard.string(forKey: "githubToken") ?? ""
    let owner = UserDefaults.standard.string(forKey: "githubOwner") ?? ""
    guard !token.isEmpty, !owner.isEmpty else { return .missingCredentials }
    
    if let url = URL(string: "https://api.github.com/user") {
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.httpMethod = "GET"
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse else { return .error("Keine Antwort") }
      switch http.statusCode {
        case 200:
          // Token ist gültig → check Owner
          if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
             let login = json["login"] as? String,
             login.lowercased() != owner.lowercased() {
            return .forbidden // Token stimmt nicht mit Owner überein
          }
        case 401: return .unauthorized
        case 403: return .forbidden
        default: return .error("HTTP \(http.statusCode)")
      }
    } catch {
      return .error(error.localizedDescription)
    }
  } else {
    return .error("Ungültige User-URL")
  }
    
    let repoName = project.projectName
    
    guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repoName)") else { return .error("Ungültige URL") }
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.httpMethod = "GET"
    
    do {
      let (_, response) = try await URLSession.shared.data(for: request)
      if let http = response as? HTTPURLResponse {
        switch http.statusCode {
          case 200:
            if !overwriteConfirmed { return .repoExists }
          case 401: return .unauthorized
          case 403: return .forbidden
          case 404: break
          //case 404: return .needsGitSettings
          default: return .error("HTTP \(http.statusCode)")
        }
      }
    } catch {
      return .error(error.localizedDescription)
    }
    
    //if !overwriteConfirmed { return .repoExists }
    
    /*let projectURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
      .first?.appendingPathComponent("project.json")
    guard let projectData = try? Data(contentsOf: projectURL ?? URL(fileURLWithPath: "")), !projectData.isEmpty else {
      return .needsGitSettings
    }*/
    let projectURL = project.projectFolder.appendingPathComponent(".project.json")
    guard let projectData = try? Data(contentsOf: projectURL), !projectData.isEmpty else {
      return .needsGitSettings
    }
    
    return .success
    
  }
}
