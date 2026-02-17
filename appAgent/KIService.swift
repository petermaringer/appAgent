import SwiftUI
import Foundation

class KIService: ObservableObject {
  @AppStorage("openRouterAPIKey") private var apiKey: String = "xx-or-v1-0d9cbcaa12e1462c8c010b2910fd6396d53dda5e1f592dfbfe3f6964c791f46f"
  @AppStorage("openRouterModel") private var model: String = "arcee-ai/trinity-mini:free"

  func generateCode(prompt: String, context: String) async throws -> String {
    guard !apiKey.isEmpty else {
      throw NSError(
        domain: "KIService",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "API-Key fehlt"]
      )
    }
    
    let url = URL(string: "https://openrouter.ai/api/v1/completions")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body: [String: Any] = [
      "model": model,
      "prompt": context + "\n\n" + prompt,
      "max_tokens": 1500
    ]
    
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (data, _) = try await URLSession.shared.data(for: request)
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let text = (json["choices"] as? [[String: Any]])?.first?["text"] as? String {
      return text
    } else {
      throw NSError(
        domain: "KIService",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Fehlerhafte Antwort vom KI-Server"]
      )
    }
  }
}
