import SwiftUI

struct NewProjectView: View {
  @Binding var projects: [ProjectEngine]
  @Environment(\.dismiss) var dismiss
  @State private var projectName: String = ""
  @State private var appIdentifier: String = ""
  @State private var showingAlert = false
  @State private var alertMessage = ""
  let onCreated: (ProjectEngine) -> Void
  @AppStorage("bundleIDPrefix") private var bundleIDPrefix: String = ""
  
  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Angaben zum Projekt")) {
          TextField("Projektname", text: $projectName)
            //.onChange(of: projectName) { newValue in
            .onChange(of: projectName) { projectName, _ in
              let sanitized = projectName.lowercased().components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).inverted).joined()
              
              let basePrefix = bundleIDPrefix.isEmpty ? "com.meinefirma" : bundleIDPrefix
              
              if let lastDot = appIdentifier.lastIndex(of: ".") {
                let prefix = String(appIdentifier[..<lastDot])
                appIdentifier = "\(prefix).\(sanitized)"
              } else if !appIdentifier.isEmpty {
                appIdentifier = "\(appIdentifier).\(sanitized)"
              } else {
                appIdentifier = "\(basePrefix).\(sanitized)"
              }
            }
            /*.onChange(of: projectName) { newValue in
              let sanitized = newValue.lowercased().components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).inverted).joined()
              appIdentifier = "\(bundleIDPrefix).\(sanitized)"
            }*/
          TextField("App-Identifier (z.B. com.meinefirma.projekt)", text: $appIdentifier)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
        }
      }
      .navigationTitle("Neues Projekt")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Erstellen") { createProject() }
        }
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
      }
      .alert("Ungültige Eingabe", isPresented: $showingAlert) {
        Button("OK", role: .cancel) { }
      } message: {
        Text(alertMessage)
      }
    }
    .tint(.blue)
  }
  
  func createProject() {
    guard !projectName.isEmpty else { return }
    let fm = FileManager.default
    let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    // Projektname validieren
    let validName = projectName.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).inverted).joined()
    guard !validName.isEmpty else {
      alertMessage = "Der Projektname darf nur Buchstaben, Zahlen und Unterstriche enthalten."
      showingAlert = true
      return
    }
    
    // Prüfen, ob das Projekt bereits existiert
    let newFolder = docs.appendingPathComponent(validName)
    if fm.fileExists(atPath: newFolder.path) {
      alertMessage = "Ein Projekt mit diesem Namen existiert bereits."
      showingAlert = true
      return
    }
    
    // App-Identifier validieren
    let allowedIdentifierChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
    let filteredIdentifier = appIdentifier.components(separatedBy: allowedIdentifierChars.inverted).joined()
    guard !filteredIdentifier.isEmpty else {
      alertMessage = "Der App-Identifier darf nur Buchstaben, Zahlen, Punkte, Bindestriche und Unterstriche enthalten."
      showingAlert = true
      return
    }
    
    try? fm.createDirectory(at: newFolder, withIntermediateDirectories: true)
    
    // Unterordner nach Projektname anlegen
    let projectSubfolder = newFolder.appendingPathComponent(validName)
    try? fm.createDirectory(at: projectSubfolder, withIntermediateDirectories: true)
    
    // ContentView.swift anlegen
    let contentFile = projectSubfolder.appendingPathComponent("ContentView.swift")
    let defaultContent = """
    import SwiftUI

    struct ContentView: View {
      var body: some View {
        Text("Hello, \(validName)!")
          .padding()
      }
    }
    """
    try? defaultContent.write(to: contentFile, atomically: true, encoding: .utf8)
    
    // {Projektname}App.swift anlegen
    let appFile = projectSubfolder.appendingPathComponent("\(validName)App.swift")
    let defaultAppContent = """
    import SwiftUI

    @main
    struct \(validName)App: App {
      // App-Identifier: \(filteredIdentifier)
      var body: some Scene {
        WindowGroup {
          ContentView()
        }
      }
    }
    """
    try? defaultAppContent.write(to: appFile, atomically: true, encoding: .utf8)
    
    // project.yml im Hauptordner anlegen
    let ymlFile = newFolder.appendingPathComponent("project.yml")
    let ymlContent = """
    name: \(validName)
    options:
      minimumXcodeGenVersion: "2.42.0"
      bundleIdPrefix: \(filteredIdentifier)
      deploymentTarget:
        iOS: "16.0"
    targets:
      \(validName):
        type: application
        platform: iOS
        sources:
          - path: \(validName)
            excludes:
              - Excludes
        settings:
          CODE_SIGN_ENTITLEMENTS: \(validName)/App.entitlements
        scheme:
          configVariants:
    """
    try? ymlContent.write(to: ymlFile, atomically: true, encoding: .utf8)
    
    let engine = ProjectEngine(projectFolder: newFolder)
    //projects.append(engine)
    onCreated(engine)
    dismiss()
  }
}
