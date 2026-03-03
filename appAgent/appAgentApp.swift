import SwiftUI

@main
struct appAgentApp: App {
  @StateObject private var settings = AppSettings()
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(settings)
    }
  }
}
