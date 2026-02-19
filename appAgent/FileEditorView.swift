import SwiftUI

struct FileEditorView: View {
  let fileURL: URL
  @Environment(\.dismiss) var dismiss
  @State private var codeText: String = ""
  @State private var isKeyboardVisible: Bool = false

  private let keywords = ["let","var","func","struct","class","import","if","else","for","while","return","in","enum","extension","switch","case","default","break","guard","do","try","catch"]

  var body: some View {
    VStack {
      Text("Bearbeite: \(fileURL.lastPathComponent)")
        .font(.headline)
        .padding()

      //SyntaxTextViewWithLineNumbersSync(text: $codeText, keywords: keywords)
      CodeEditorContainerView(codeText: $codeText, keywords: keywords)
        .frame(minHeight: 300)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
        .padding()

      HStack {
        Button {
          UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        } label: {
          Image(systemName: "keyboard.chevron.compact.down")
        }
        .opacity(isKeyboardVisible ? 1 : 0)
        .disabled(!isKeyboardVisible)
        .animation(.easeInOut(duration: 0.25), value: isKeyboardVisible)

        Spacer()

        Button("Speichern & schließen") {
          UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
          saveFile()
          dismiss()
        }
      }
      .padding(.horizontal)
    }
    .padding()
    .onAppear {
      loadFile()
      NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
        isKeyboardVisible = true
      }
      NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
        isKeyboardVisible = false
      }
    }
    .onDisappear {
      NotificationCenter.default.removeObserver(self)
    }
  }

  func loadFile() {
    if let text = try? String(contentsOf: fileURL) {
      codeText = text
    }
  }

  func saveFile() {
    try? codeText.write(to: fileURL, atomically: true, encoding: .utf8)
  }
}

// MARK: - Editierbarer CodeView mit synchronisierten Zeilennummern (ohne WordWrap)
struct SyntaxTextViewWithLineNumbersSync: UIViewRepresentable {
  @Binding var text: String
  let keywords: [String]
  
  func makeUIView(context: Context) -> UIView {
    let container = UIView()
    
    let lineNumbersView = UITextView()
    lineNumbersView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    lineNumbersView.backgroundColor = UIColor.secondarySystemBackground
    lineNumbersView.isEditable = false
    lineNumbersView.isScrollEnabled = true
    lineNumbersView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
    lineNumbersView.textContainer.lineBreakMode = .byClipping
    lineNumbersView.textContainer.widthTracksTextView = false
    
    let codeView = UITextView()
    codeView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    codeView.backgroundColor = .clear
    codeView.delegate = context.coordinator
    codeView.isScrollEnabled = true
    codeView.alwaysBounceHorizontal = true
    codeView.autocorrectionType = .no
    codeView.autocapitalizationType = .none
    codeView.textContainerInset = UIEdgeInsets(top: 8, left: 50, bottom: 8, right: 8)
    codeView.textContainer.lineBreakMode = .byClipping
    codeView.textContainer.widthTracksTextView = false
    
    container.addSubview(lineNumbersView)
    container.addSubview(codeView)
    
    lineNumbersView.translatesAutoresizingMaskIntoConstraints = false
    codeView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      lineNumbersView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      lineNumbersView.topAnchor.constraint(equalTo: container.topAnchor),
      lineNumbersView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      
      codeView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      codeView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      codeView.topAnchor.constraint(equalTo: container.topAnchor),
      codeView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])
    
    context.coordinator.codeView = codeView
    context.coordinator.lineNumbersView = lineNumbersView
    
    codeView.text = text
    context.coordinator.updateLineNumbers()
    context.coordinator.applyHighlighting()
    
    codeView.addObserver(context.coordinator, forKeyPath: "contentOffset", options: .new, context: nil)
    
    return container
  }
  
  func updateUIView(_ uiView: UIView, context: Context) {
    guard let codeView = context.coordinator.codeView else { return }
    
    if codeView.text != text {
      codeView.text = text
      context.coordinator.updateLineNumbers()
      context.coordinator.applyHighlighting()
    }
  }
  
  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }
  
  class Coordinator: NSObject, UITextViewDelegate {
    var parent: SyntaxTextViewWithLineNumbersSync
    weak var codeView: UITextView?
    weak var lineNumbersView: UITextView?
    
    init(parent: SyntaxTextViewWithLineNumbersSync) {
      self.parent = parent
    }
    
    func textViewDidChange(_ textView: UITextView) {
      parent.text = textView.text
      updateLineNumbers()
      applyHighlighting()
    }
    
    func updateLineNumbers() {
      guard let codeView = codeView, let lineNumbersView = lineNumbersView else { return }

      let lines = codeView.text.components(separatedBy: "\n")
      let numbers = (1...max(lines.count,1)).map { "\($0)" }
      lineNumbersView.text = numbers.joined(separator: "\n")

      let maxLineNumber = max(lines.count, 1)
      let digits = String(maxLineNumber).count
      let sample = String(repeating: "8", count: digits) as NSString
      let width = sample.size(withAttributes: [.font: lineNumbersView.font!]).width + 24

      lineNumbersView.constraints
        .filter { $0.firstAttribute == .width }
        .forEach { $0.isActive = false }

      lineNumbersView.widthAnchor.constraint(equalToConstant: width).isActive = true
      codeView.textContainerInset.left = width + 4
    }
    
    func applyHighlighting() {
      guard let codeView = codeView else { return }
      
      let selected = codeView.selectedRange
      let textStorage = codeView.textStorage
      let fullRange = NSRange(location: 0, length: textStorage.length)
      
      textStorage.beginEditing()
      textStorage.setAttributes([
        .foregroundColor: UIColor.label,
        .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
      ], range: fullRange)
      
      for keyword in parent.keywords {
        let pattern = "\\b\(keyword)\\b"
        if let regex = try? NSRegularExpression(pattern: pattern) {
          let matches = regex.matches(in: codeView.text, range: fullRange)
          for match in matches {
            textStorage.addAttributes([
              .foregroundColor: UIColor.systemBlue,
              .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
            ], range: match.range)
          }
        }
      }
      
      textStorage.endEditing()
      codeView.selectedRange = selected
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
      if keyPath == "contentOffset" {
        if let codeView = codeView, let lineNumbersView = lineNumbersView {
          lineNumbersView.contentOffset = codeView.contentOffset
        }
      }
    }
    
    deinit {
      codeView?.removeObserver(self, forKeyPath: "contentOffset")
    }
  }
}

/*//import SwiftUI
import UIKit

// -----------------------------------
// SwiftUI Container
// -----------------------------------
struct CodeEditorContainerView: UIViewRepresentable {
  @Binding var codeText: String
  let keywords: [String]

  func makeUIView(context: Context) -> CodeEditorView {
    let editor = CodeEditorView()
    editor.codeText = codeText
    editor.keywords = keywords
    editor.delegate = context.coordinator
    return editor
  }

  func updateUIView(_ uiView: CodeEditorView, context: Context) {
    uiView.codeText = codeText
    uiView.updateLineNumbers()
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject, CodeEditorViewDelegate {
    var parent: CodeEditorContainerView

    init(_ parent: CodeEditorContainerView) {
      self.parent = parent
    }

    func codeDidChange(_ newText: String) {
      parent.codeText = newText
    }
  }
}

// -----------------------------------
// Protocol für Delegate
// -----------------------------------
protocol CodeEditorViewDelegate: AnyObject {
  func codeDidChange(_ newText: String)
}

// -----------------------------------
// UIKit Editor mit Overlay
// -----------------------------------
class CodeEditorView: UIView, UITextViewDelegate {
  var codeText: String = "" {
    didSet { textView.text = codeText }
  }
  var keywords: [String] = []
  weak var delegate: CodeEditorViewDelegate?

  private let textView = UITextView()
  private let lineNumberOverlay = LineNumberOverlayView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  private func setup() {
    textView.delegate = self
    textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    textView.autocorrectionType = .no
    textView.backgroundColor = .clear
    addSubview(textView)
    addSubview(lineNumberOverlay)

    textView.translatesAutoresizingMaskIntoConstraints = false
    lineNumberOverlay.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      textView.leadingAnchor.constraint(equalTo: leadingAnchor),
      textView.trailingAnchor.constraint(equalTo: trailingAnchor),
      textView.topAnchor.constraint(equalTo: topAnchor),
      textView.bottomAnchor.constraint(equalTo: bottomAnchor),

      lineNumberOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
      lineNumberOverlay.topAnchor.constraint(equalTo: topAnchor),
      lineNumberOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
      lineNumberOverlay.widthAnchor.constraint(equalToConstant: 50)
    ])
  }

  func textViewDidChange(_ textView: UITextView) {
    codeText = textView.text
    delegate?.codeDidChange(codeText)
    updateLineNumbers()
  }

  func updateLineNumbers() {
    lineNumberOverlay.update(for: textView)
  }
}

// -----------------------------------
// Overlay für Zeilennummern (dynamische Breite)
// -----------------------------------
class LineNumberOverlayView: UIView {
  private var lineLabels: [UILabel] = []
  private let padding: CGFloat = 4

  func update(for textView: UITextView) {
    let layoutManager = textView.layoutManager
    let textStorage = textView.textStorage

    let numberOfLines = textStorage.string.components(separatedBy: "\n").count
    let maxDigits = "\(numberOfLines)".count

    // Berechne Zeichenbreite
    let charWidth = ("0" as NSString).size(withAttributes: [.font: textView.font!]).width
    let width = CGFloat(maxDigits) * charWidth + padding

    // Overlay-Breite anpassen
    NSLayoutConstraint.deactivate(self.constraints.filter { $0.firstAttribute == .width })
    self.widthAnchor.constraint(equalToConstant: width).isActive = true

    // Labels erstellen/anpassen
    if lineLabels.count != numberOfLines {
      lineLabels.forEach { $0.removeFromSuperview() }
      lineLabels = (0..<numberOfLines).map { i in
        let label = UILabel()
        label.font = textView.font
        label.textColor = .gray
        label.textAlignment = .right
        label.text = "\(i+1)"
        addSubview(label)
        return label
      }
    }

    // Positionierung
    var glyphIndex = 0
    for (i, label) in lineLabels.enumerated() {
      if glyphIndex >= layoutManager.numberOfGlyphs { break }
      var lineRange = NSRange(location: 0, length: 0)
      let lineRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange)
      label.frame = CGRect(x: 0,
                           y: lineRect.minY + textView.textContainerInset.top,
                           width: width - padding,
                           height: lineRect.height)
      glyphIndex = NSMaxRange(lineRange)
    }
  }
}*/

// MARK: - Editierbarer CodeView mit synchronisierten Zeilennummern
/*struct SyntaxTextViewWithLineNumbersSync: UIViewRepresentable {
  @Binding var text: String
  let keywords: [String]
  
  func makeUIView(context: Context) -> UIView {
    let container = UIView()
    
    let lineNumbersView = UITextView()
    lineNumbersView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    lineNumbersView.backgroundColor = UIColor.secondarySystemBackground
    lineNumbersView.isEditable = false
    lineNumbersView.isScrollEnabled = true
    lineNumbersView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
    
    let codeView = UITextView()
    codeView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    codeView.backgroundColor = .clear
    codeView.delegate = context.coordinator
    codeView.isScrollEnabled = true
    codeView.autocorrectionType = .no
    codeView.autocapitalizationType = .none
    codeView.textContainerInset = UIEdgeInsets(top: 8, left: 50, bottom: 8, right: 8)
    
    container.addSubview(lineNumbersView)
    container.addSubview(codeView)
    
    lineNumbersView.translatesAutoresizingMaskIntoConstraints = false
    codeView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      lineNumbersView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      lineNumbersView.topAnchor.constraint(equalTo: container.topAnchor),
      lineNumbersView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      
      codeView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      codeView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      codeView.topAnchor.constraint(equalTo: container.topAnchor),
      codeView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])
    
    context.coordinator.codeView = codeView
    context.coordinator.lineNumbersView = lineNumbersView
    
    codeView.text = text
    context.coordinator.updateLineNumbers()
    context.coordinator.applyHighlighting()
    
    // Scroll synchronisieren
    codeView.addObserver(context.coordinator, forKeyPath: "contentOffset", options: .new, context: nil)
    
    return container
  }
  
  func updateUIView(_ uiView: UIView, context: Context) {
    guard let codeView = context.coordinator.codeView else { return }
    
    if codeView.text != text {
      codeView.text = text
      context.coordinator.updateLineNumbers()
      context.coordinator.applyHighlighting()
    }
  }
  
  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }
  
  class Coordinator: NSObject, UITextViewDelegate {
  var parent: SyntaxTextViewWithLineNumbersSync
  weak var codeView: UITextView?
  weak var lineNumbersView: UITextView?
  
  init(parent: SyntaxTextViewWithLineNumbersSync) {
    self.parent = parent
  }
  
  func textViewDidChange(_ textView: UITextView) {
    parent.text = textView.text
    updateLineNumbers()
    applyHighlighting()
  }
  
func updateLineNumbers() {
  guard let codeView = codeView, let lineNumbersView = lineNumbersView else { return }

  let text = codeView.text as NSString
  let lines = text.components(separatedBy: "\n")
  
  var lineNumberStrings: [String] = []
  
  for (index, line) in lines.enumerated() {
    lineNumberStrings.append("\(index + 1)")
    let layoutManager = codeView.layoutManager
    let charRange = NSRange(location: 0, length: line.utf16.count)
    var glyphIndex = layoutManager.glyphRange(forCharacterRange: charRange, actualCharacterRange: nil).location
    let lineRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: nil)
    let numberOfWrappedLines = max(Int(lineRect.height / codeView.font!.lineHeight) - 1, 0)
    for _ in 0..<numberOfWrappedLines {
      lineNumberStrings.append("") // leere Zeilen für Wrapping
    }
  }

  lineNumbersView.text = lineNumberStrings.joined(separator: "\n")

  // Dynamische Breite der Gutter-Spalte
  let maxLineNumber = max(lines.count, 1)
  let digits = String(maxLineNumber).count
  let sample = String(repeating: "8", count: digits) as NSString
  let width = sample.size(withAttributes: [.font: lineNumbersView.font!]).width + 24

  lineNumbersView.constraints.filter { $0.firstAttribute == .width }.forEach { $0.isActive = false }
  lineNumbersView.widthAnchor.constraint(equalToConstant: width).isActive = true

  codeView.textContainerInset.left = width + 4
}
  
  func applyHighlighting() {
    guard let codeView = codeView else { return }
    
    let selected = codeView.selectedRange
    let textStorage = codeView.textStorage
    let fullRange = NSRange(location: 0, length: textStorage.length)
    
    textStorage.beginEditing()
    textStorage.setAttributes([
      .foregroundColor: UIColor.label,
      .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    ], range: fullRange)
    
    for keyword in parent.keywords {
      let pattern = "\\b\(keyword)\\b"
      if let regex = try? NSRegularExpression(pattern: pattern) {
        let matches = regex.matches(in: codeView.text, range: fullRange)
        for match in matches {
          textStorage.addAttributes([
            .foregroundColor: UIColor.systemBlue,
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
          ], range: match.range)
        }
      }
    }
    
    textStorage.endEditing()
    codeView.selectedRange = selected
  }
  
  // Scroll synchronisieren
  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    if keyPath == "contentOffset" {
      if let codeView = codeView, let lineNumbersView = lineNumbersView {
        lineNumbersView.contentOffset = codeView.contentOffset
      }
    }
  }
  
  deinit {
    codeView?.removeObserver(self, forKeyPath: "contentOffset")
  }
}
}*/
