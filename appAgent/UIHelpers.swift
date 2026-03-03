import SwiftUI

// MARK: - Funktion für max. Breite innerhalb der Safe Areas
func calculateSafeMaxWidth(for safeAreaInsets: EdgeInsets) -> CGFloat {
  UIScreen.main.bounds.width - safeAreaInsets.leading - safeAreaInsets.trailing
}

// MARK: - ButtonStyle für gedrückt-Opacity
struct PressedOpacityButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.5 : 1)
  }
}

// MARK: - Enum für Button-Typen
enum ToolbarButtonType {
  case standard
  case prominent
}

// MARK: - ViewModifier für Toolbar Buttons
struct ToolbarButtonModifier: ViewModifier {
  let type: ToolbarButtonType
  func body(content: Content) -> some View {
    switch type {
    case .standard:
      content
        .foregroundColor(.blue)
        .padding(12)
        .contentShape(Rectangle())
    case .prominent:
      content
        .padding(12)
        .contentShape(Rectangle())
        .buttonStyle(.borderedProminent)
    }
  }
}

// MARK: - Extension für einfache Nutzung
extension View {
  func toolbarButton(_ type: ToolbarButtonType) -> some View {
    self.modifier(ToolbarButtonModifier(type: type))
      .buttonStyle(PressedOpacityButtonStyle())
  }
}

/*import SwiftUI

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
