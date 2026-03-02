import SwiftUI
import UIKit

struct GradientOverlayView<Content: View>: UIViewRepresentable {
  let content: Content
  let gradientHeight: CGFloat

  init(gradientHeight: CGFloat = 16, @ViewBuilder content: () -> Content) {
    self.content = content()
    self.gradientHeight = gradientHeight
  }

  func makeUIView(context: Context) -> UIView {
    let container = UIView()

    // HostingController für SwiftUI-Content
    let hosting = UIHostingController(rootView: content)
    hosting.view.translatesAutoresizingMaskIntoConstraints = false
    hosting.view.backgroundColor = .clear
    container.addSubview(hosting.view)

    NSLayoutConstraint.activate([
      hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      hosting.view.topAnchor.constraint(equalTo: container.topAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])

    // Gradient-Layer fixiert oben
    let gradientLayer = CAGradientLayer()
    /*gradientLayer.colors = [
      UIColor.systemBackground.cgColor,
      UIColor.systemBackground.withAlphaComponent(0).cgColor
    ]*/
    gradientLayer.colors = [
  UIColor.red.cgColor,    // obere Farbe, sichtbar
  UIColor.clear.cgColor   // untere Farbe, transparent
]
    
    gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
    gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
    gradientLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: gradientHeight)
    container.layer.addSublayer(gradientLayer)

    return container
  }

  func updateUIView(_ uiView: UIView, context: Context) {}
}
