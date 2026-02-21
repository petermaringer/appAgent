import SwiftUI

struct SettingsView: View {
  @AppStorage("openRouterAPIKey") private var apiKey: String = ""
  @AppStorage("openRouterModel") private var model: String = "gpt-4.1-mini"
  
  @AppStorage("githubToken") private var githubToken: String = ""
  @AppStorage("githubOwner") private var githubOwner: String = ""
  @AppStorage("githubRepo") private var githubRepo: String = ""
  
  @Environment(\.dismiss) var dismiss

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("OpenRouter Einstellungen")) {
          TextField("API-Key", text: $apiKey)
            .textContentType(.password)
          TextField("Modell", text: $model)
          Text("Beispielmodelle: gpt-4.1-mini, gpt-4.1, gpt-3.5-turbo")
            .font(.footnote)
            .foregroundColor(.gray)
        }

        Section(header: Text("GitHub Einstellungen")) {
          TextField("Token", text: $githubToken)
            .textContentType(.password)
          TextField("Owner", text: $githubOwner)
          TextField("Repo", text: $githubRepo)
          Text("Repo wird automatisch erstellt, wenn es nicht existiert.")
            .font(.footnote)
            .foregroundColor(.gray)
        }
      }
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Fertig") { dismiss() }
        }
      }
    }
  }
}
