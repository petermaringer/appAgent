import SwiftUI

struct LaunchScreen: View {
  var body: some View {
    ZStack {
      Color.white.edgesIgnoringSafeArea(.all)
      Text("appAgent")
        .font(.largeTitle)
        .foregroundColor(.blue)
    }
  }
}
