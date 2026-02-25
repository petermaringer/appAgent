import SwiftUI

struct SettingsView: View {
  @AppStorage("bundleIDPrefix") private var bundleIDPrefix: String = ""
  
  @AppStorage("githubToken") private var githubToken: String = ""
  @AppStorage("githubOwner") private var githubOwner: String = ""
  @AppStorage("githubRepo") private var githubRepo: String = ""
  
  @AppStorage("openRouterAPIKey") private var apiKey: String = ""
  @AppStorage("openRouterModel") private var model: String = "gpt-4.1-mini"
  
  @Environment(\.dismiss) var dismiss

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Projekt Einstellungen")) {
          TextField("Bundle-ID Prefix", text: $bundleIDPrefix)
            //.textContentType(.none)
          Text("Beispiel: com.meinunternehmen")
            .font(.footnote)
            .foregroundColor(.gray)
        }

        Section(header: Text("GitHub Einstellungen")) {
          TextField("Token", text: $githubToken)
            //.textContentType(.password)
          TextField("Owner", text: $githubOwner)
          TextField("Repo", text: $githubRepo)
          Text("Repo wird automatisch erstellt, wenn es nicht existiert.")
            .font(.footnote)
            .foregroundColor(.gray)
        }

        Section(header: Text("OpenRouter Einstellungen")) {
          TextField("API-Key", text: $apiKey)
            //.textContentType(.password)
          TextField("Modell", text: $model)
          Text("Beispielmodelle: gpt-4.1-mini, gpt-4.1, gpt-3.5-turbo")
            .font(.footnote)
            .foregroundColor(.gray)
        }
      }
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled(true)
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Fertig") { dismiss() }
        }
      }
    }
  }
}
