import Foundation
import SwiftUI
import CryptoKit

actor GitHubService {
  let token: String
  let repoOwner: String
  let repoName: String
  let branch: String

  init(token: String, repoOwner: String, repoName: String, branch: String = "main") {
    self.token = token
    self.repoOwner = repoOwner
    self.repoName = repoName
    self.branch = branch
  }

  func pushProject(at folderURL: URL, statusUpdate: @escaping (String) -> Void) async {
    guard await checkOrCreateRepo(statusUpdate: statusUpdate) else { return }
    _ = await pushFolder(folderURL, relativePath: "", statusUpdate: statusUpdate)
    statusUpdate("✅ Push abgeschlossen")
  }

  private func checkOrCreateRepo(statusUpdate: @escaping (String) -> Void) async -> Bool {
    let repoURL = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)")!
    var repoRequest = URLRequest(url: repoURL)
    repoRequest.httpMethod = "GET"
    repoRequest.setValue("token \(token)", forHTTPHeaderField: "Authorization")

    do {
      let (_, response) = try await URLSession.shared.data(for: repoRequest)
      if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 404 {
        statusUpdate("⚡ Repo existiert nicht, erstelle...")
        let createURL = URL(string: "https://api.github.com/user/repos")!
        var createRequest = URLRequest(url: createURL)
        createRequest.httpMethod = "POST"
        createRequest.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["name": repoName, "private": true]
        createRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, createResponse) = try await URLSession.shared.data(for: createRequest)
        if let createHttp = createResponse as? HTTPURLResponse, createHttp.statusCode >= 400 {
          statusUpdate("❌ Repo konnte nicht erstellt werden (\(createHttp.statusCode))")
          return false
        }
        statusUpdate("✅ Repo erstellt")
      }
      return true
    } catch {
      statusUpdate("❌ Fehler beim Prüfen/Erstellen des Repo: \(error.localizedDescription)")
      return false
    }
  }

  private func pushFolder(_ url: URL, relativePath: String, statusUpdate: @escaping (String) -> Void) async -> Bool {
    let fm = FileManager.default
    guard let items = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return true }

    for item in items {
      let path = relativePath.isEmpty ? item.lastPathComponent : "\(relativePath)/\(item.lastPathComponent)"
      if item.hasDirectoryPath {
        let ok = await pushFolder(item, relativePath: path, statusUpdate: statusUpdate)
        if !ok { return false }
      } else {
        guard let contentData = try? Data(contentsOf: item) else { continue }
        let contentBase64 = contentData.base64EncodedString()

        // SHA prüfen
        let apiURL = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/contents/\(path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)")!
        var getRequest = URLRequest(url: apiURL)
        getRequest.httpMethod = "GET"
        getRequest.setValue("token \(token)", forHTTPHeaderField: "Authorization")

        var sha: String? = nil
        do {
          let (data, response) = try await URLSession.shared.data(for: getRequest)
          if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let remoteSHA = json["sha"] as? String {
              sha = remoteSHA
            }
          }
        } catch { /* Fehler ignorieren */ }

        if sha == nil || sha != shaForData(contentData) {
          var putRequest = URLRequest(url: apiURL)
          putRequest.httpMethod = "PUT"
          putRequest.setValue("token \(token)", forHTTPHeaderField: "Authorization")
          putRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
          var body: [String: Any] = ["message": "Update from App", "branch": branch, "content": contentBase64]
          if let sha = sha { body["sha"] = sha }
          putRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)

          do {
            let (_, response) = try await URLSession.shared.data(for: putRequest)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode >= 400 {
              statusUpdate("❌ Fehler beim Pushen von \(path): \(httpResp.statusCode)")
              return false
            }
          } catch {
            statusUpdate("❌ Fehler beim Pushen von \(path): \(error.localizedDescription)")
            return false
          }
          statusUpdate("✅ Gepusht: \(path)")
        } else {
          statusUpdate("➡️ Unverändert: \(path)")
        }
      }
    }
    return true
  }

  private func shaForData(_ data: Data) -> String {
    let digest = Insecure.SHA1.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}
