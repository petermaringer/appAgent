import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var settings: AppSettings
  
  @AppStorage("bundleIDPrefix") private var bundleIDPrefix: String = ""
  
  @AppStorage("githubToken") private var githubToken: String = ""
  @AppStorage("githubOwner") private var githubOwner: String = ""
  //@AppStorage("githubRepo") private var githubRepo: String = ""
  
  @AppStorage("openRouterAPIKey") private var apiKey: String = ""
  @AppStorage("openRouterModel") private var model: String = "gpt-4.1-mini"
  
  @Environment(\.dismiss) var dismiss
  
  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("App-Einstellungen")) {
  Text("Akzentfarbe auswählen")
    .font(.subheadline)
    .foregroundColor(.primary)
  ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 15) {
      ForEach([
        (Color.blue, "Blau"),
        (Color.gray, "Grau"),
        (Color.black, "Schwarz"),
        (Color.indigo, "Indigo"),
        (Color.yellow, "Gelb")
        /*(Color.blue, "Blau"),
        (Color.black, "Schwarz"),
        (Color.yellow, "Gelb")*/
      ], id: \.1) { color, name in
        VStack {
          ColorCircle(color: color)
          /*Circle()
            .fill(color)
            .frame(width: 40, height: 40)
            .overlay(
              Circle()
                .stroke(settings.tintColor == color ? (color.isLight ? .black : .gray) : Color.clear, lineWidth: 2)
            )
            //.overlay(
              //Circle()
                //.stroke(settings.tintColor == color ? Color.black : Color.clear, lineWidth: 2)
            //)
            .onTapGesture {
              settings.updateTintColor(color)
              //settings.tintColor = color
            }*/
          Text(name)
            .font(.caption)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 5)
  }
  Text("Wähle die Akzentfarbe für die gesamte App.")
    .font(.footnote)
    .foregroundColor(.gray)
}
        
        Section(header: Text("Projekt-Einstellungen")) {
          TextField("Bundle-ID Prefix", text: $bundleIDPrefix)
            //.textContentType(.none)
          Text("Beispiel: com.meinefirma")
            .font(.footnote)
            .foregroundColor(.gray)
        }
        
        Section(header: Text("GitHub-Einstellungen")) {
          TextField("Token", text: $githubToken)
            //.textContentType(.password)
          TextField("Owner", text: $githubOwner)
          //TextField("Repo", text: $githubRepo)
          Text("Repo wird automatisch erstellt, wenn es nicht existiert.")
            .font(.footnote)
            .foregroundColor(.gray)
        }
        
        Section(header: Text("OpenRouter-Einstellungen")) {
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
    .tint(settings.tintColor)
    //.tint(.blue)
  }
}

struct ColorCircle: View {
  let color: Color
  @EnvironmentObject var settings: AppSettings
  var body: some View {
    Circle()
      .fill(color)
      .frame(width: 40, height: 40)
      .overlay(
        Circle()
          .stroke(
            settings.tintColor == color ?
              (color.isLight ? .black : Color(white: 0.85)) :
              Color.clear,
            lineWidth: 2
          )
      )
      .onTapGesture { settings.updateTintColor(color) }
  }
}
