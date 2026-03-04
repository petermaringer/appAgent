import SwiftUI

// MARK: Color-Extension für Hex <-> UIColor
extension Color {
  init?(hex: String) {
    var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hex = hex.replacingOccurrences(of: "#", with: "")
    guard hex.count == 6, let int = Int(hex, radix: 16) else { return nil }
    let r = Double((int >> 16) & 0xFF)/255
    let g = Double((int >> 8) & 0xFF)/255
    let b = Double(int & 0xFF)/255
    self.init(red: r, green: g, blue: b)
  }
  func toHex() -> String? {
    let uiColor = UIColor(self)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
    let ri = Int(r*255), gi = Int(g*255), bi = Int(b*255)
    return String(format:"#%02X%02X%02X", ri, gi, bi)
  }
}

// MARK: ObservableObject für AppSettings
class AppSettings: ObservableObject {
  @Published var tintColor: Color
  /*@AppStorage("appTintColorHex") private var appTintColorHex: String = "#007AFF"
  @Published var tintColor: Color = .blue*/
  //@Published var tintColor: Color
  init() {
    let hex = UserDefaults.standard.string(forKey: "appTintColorHex") ?? "#007AFF"
    tintColor = Color(hex: hex) ?? .blue
  }
  /*init() {
    let initialColor: Color
    if let color = Color(hex: appTintColorHex) {
      initialColor = color
    } else { initialColor = .blue }
    self.tintColor = initialColor
    if let color = Color(hex: UserDefaults.standard.string(forKey: "appTintColorHex") ?? "#007AFF") {
      tintColor = color
    }
  }*/
  func updateTintColor(_ color: Color) {
    tintColor = color
    UserDefaults.standard.set(color.toHex() ?? "#007AFF", forKey: "appTintColorHex")
  }
  /*func updateTintColor(_ color: Color) {
    tintColor = color
    appTintColorHex = color.toHex() ?? "#007AFF"
  }*/
}
/*class AppSettings: ObservableObject {
  @Published var tintColor: Color {
    didSet { appTintColorHex = tintColor.toHex() ?? "#007AFF" }
  }
  @AppStorage("appTintColorHex") private var appTintColorHex: String = "#007AFF"
  init() {
    if let color = Color(hex: appTintColorHex) {
      tintColor = color
    } else { tintColor = .blue }
  }
}*/

// MARK: Func für max. Breite innerhalb der Safe Areas
func calculateSafeMaxWidth(for safeAreaInsets: EdgeInsets) -> CGFloat {
  UIScreen.main.bounds.width - safeAreaInsets.leading - safeAreaInsets.trailing
}

// MARK: ButtonStyle für Gedrückt-Opacity
struct PressedOpacityButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.5 : 1)
  }
}

// MARK: Enum für Button-Typen
enum ToolbarButtonType {
  case standard
  case prominent
}

// MARK: ViewModifier für Toolbar Buttons
struct ToolbarButtonModifier: ViewModifier {
  let type: ToolbarButtonType
  func body(content: Content) -> some View {
    switch type {
    case .standard:
      content
        .foregroundColor(settings.tintColor)
        //.foregroundColor(.blue)
        .padding(12)
        .contentShape(Rectangle())
    case .prominent:
      content
        .tint(settings.tintColor)
        .padding(12)
        .contentShape(Rectangle())
        .buttonStyle(.borderedProminent)
    }
  }
}

// MARK: View-Extension für einfache Nutzung
extension View {
  func toolbarButton(_ type: ToolbarButtonType) -> some View {
    self.modifier(ToolbarButtonModifier(type: type))
      .buttonStyle(PressedOpacityButtonStyle())
  }
}

/*
struct StandardToolbarButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundColor(.blue)
      .padding(12)
      .contentShape(Rectangle())
      .opacity(configuration.isPressed ? 0.5 : 1)
  }
}
struct ProminentToolbarButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(12)
      .contentShape(Rectangle())
      .opacity(configuration.isPressed ? 0.5 : 1)
      //.background(Color.blue.opacity(configuration.isPressed ? 0.2 : 1))
      .buttonStyle(.borderedProminent)
  }
}*/
