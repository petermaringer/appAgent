import Foundation

actor GitEngine {
  // Zugriff auf GitShared aus der View
  //var gitShared: GitSectionView.GitShared?
  var overwriteConfirmed = false

  func performPush() async -> GitStatus {
    let token = UserDefaults.standard.string(forKey: "githubToken") ?? ""
    let owner = UserDefaults.standard.string(forKey: "githubOwner") ?? ""

    guard !token.isEmpty, !owner.isEmpty else { return .missingCredentials }
    
    if !overwriteConfirmed { return .repoExists }
    
    // Project JSON prüfen
    let projectURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
      .first?.appendingPathComponent("project.json")
    guard let projectData = try? Data(contentsOf: projectURL ?? URL(fileURLWithPath: "")), !projectData.isEmpty else {
      return .needsGitSettings
    }

    // GitShared abfragen
    //let overwrite = gitShared?.overwriteConfirmed ?? false
   
      return .success
  }
}
