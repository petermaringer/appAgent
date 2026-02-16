import SwiftUI

struct SettingsView: View {
  @AppStorage("openRouterAPIKey") private var apiKey: String = ""
  @AppStorage("openRouterModel") private var model: String = "gpt-4.1-mini"
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
