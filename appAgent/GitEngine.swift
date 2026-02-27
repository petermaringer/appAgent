import Foundation

actor GitEngine {
  private(set) var overwriteConfirmed = false
  func setOverwriteConfirmed(_ value: Bool) { overwriteConfirmed = value }
  
  private let project: ProjectEngine
  init(project: ProjectEngine) { self.project = project }
  
  func performPush() async -> GitStatus {
    let token = UserDefaults.standard.string(forKey: "githubToken") ?? ""
    let owner = UserDefaults.standard.string(forKey: "githubOwner") ?? ""
    guard !token.isEmpty, !owner.isEmpty else { return .missingCredentials }
    
    let repoName = project.projectName
    
    guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repoName)") else { return .error("Ungültige URL") }
    var request = URLRequest(url: url)
    request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
    request.httpMethod = "GET"
    
    do {
      let (_, response) = try await URLSession.shared.data(for: request)
      if let http = response as? HTTPURLResponse {
        switch http.statusCode {
          case 200:
            if !overwriteConfirmed { return .repoExists }
          case 401: return .unauthorized
          case 403: return .forbidden
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
