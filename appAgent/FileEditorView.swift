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
      
      SyntaxTextViewWithLineNumbersSync(text: $codeText, keywords: keywords)
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
      
      // Keyboard Observers
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

// MARK: - Editierbarer CodeView mit synchronisierten Zeilennummern
// MARK: - Editierbarer CodeView mit synchronisierten Zeilennummern
struct SyntaxTextViewWithLineNumbersSync: UIViewRepresentable {
  @Binding var text: String
  let keywords: [String]
  
  func makeUIView(context: Context) -> UIView {
    let container = LineNumberTextView()
    container.textView.text = text
    container.keywords = keywords
    container.updateLineNumbers()
    container.applyHighlighting()
    
    context.coordinator.editor = container
    container.textView.delegate = context.coordinator
    
    return container
  }
  
  func updateUIView(_ uiView: UIView, context: Context) {
    guard let container = uiView as? LineNumberTextView else { return }
    if container.textView.text != text {
      container.textView.text = text
      container.updateLineNumbers()
      container.applyHighlighting()
    }
  }
  
  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }
  
  class Coordinator: NSObject, UITextViewDelegate {
    var parent: SyntaxTextViewWithLineNumbersSync
    weak var editor: LineNumberTextView?
    
    init(parent: SyntaxTextViewWithLineNumbersSync) {
      self.parent = parent
    }
    
    func textViewDidChange(_ textView: UITextView) {
      parent.text = textView.text
      editor?.updateLineNumbers()
      editor?.applyHighlighting()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
      editor?.syncScroll()
    }
  }
}

// MARK: - UITextView mit integrierter Gutter-Spalte
class LineNumberTextView: UIView, UITextViewDelegate {

  let textView = UITextView()
  var keywords: [String] = []

  private let gutterWidthPadding: CGFloat = 12
  private var gutterWidth: CGFloat = 40

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  private func setup() {
    backgroundColor = .clear

    textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    textView.autocorrectionType = .no
    textView.autocapitalizationType = .none
    textView.backgroundColor = .clear
    textView.delegate = self
    textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

    addSubview(textView)

    textView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      textView.topAnchor.constraint(equalTo: topAnchor),
      textView.bottomAnchor.constraint(equalTo: bottomAnchor),
      textView.trailingAnchor.constraint(equalTo: trailingAnchor),
      textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: gutterWidth)
    ])
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    updateGutterWidth()
    textView.frame = CGRect(
      x: gutterWidth,
      y: 0,
      width: bounds.width - gutterWidth,
      height: bounds.height
    )
  }

  private func numberOfLines() -> Int {
    return max(textView.text.components(separatedBy: "\n").count, 1)
  }

  private func updateGutterWidth() {
    let lineCount = numberOfLines()
    let digits = String(lineCount).count
    let sample = String(repeating: "8", count: digits) as NSString
    let width = sample.size(withAttributes: [
      .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    ]).width

    gutterWidth = width + gutterWidthPadding
    setNeedsDisplay()
  }

  override func draw(_ rect: CGRect) {
    super.draw(rect)

    guard let context = UIGraphicsGetCurrentContext() else { return }

    // Grauer Hintergrund
    UIColor.secondarySystemBackground.setFill()
    context.fill(CGRect(x: 0, y: 0, width: gutterWidth, height: bounds.height))

    let layoutManager = textView.layoutManager
    let textContainer = textView.textContainer

    let visibleGlyphRange = layoutManager.glyphRange(
      forBoundingRect: textView.bounds,
      in: textContainer
    )

    let text = textView.text as NSString
    var lineNumber = 1
    var glyphIndex = 0

    while glyphIndex < layoutManager.numberOfGlyphs {

      var lineRange = NSRange()
      let rect = layoutManager.lineFragmentRect(
        forGlyphAt: glyphIndex,
        effectiveRange: &lineRange
      )

      let charRange = layoutManager.characterRange(
        forGlyphRange: lineRange,
        actualGlyphRange: nil
      )

      let isNewLine =
        charRange.location == 0 ||
        text.substring(with: NSRange(location: charRange.location - 1, length: 1)) == "\n"

      if isNewLine {

        if NSIntersectionRange(lineRange, visibleGlyphRange).length > 0 {
          let y = rect.minY + textView.textContainerInset.top - textView.contentOffset.y

          let numberString = "\(lineNumber)" as NSString
          numberString.draw(
            at: CGPoint(x: gutterWidth - numberString.size(withAttributes: [.font: textView.font!]).width - 6, y: y),
            withAttributes: [
              .font: textView.font!,
              .foregroundColor: UIColor.secondaryLabel
            ]
          )
        }

        lineNumber += 1
      }

      glyphIndex = NSMaxRange(lineRange)
    }
  }

  func textViewDidChange(_ textView: UITextView) {
    updateGutterWidth()
    setNeedsDisplay()
    applyHighlighting()
  }

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    setNeedsDisplay()
  }

  func applyHighlighting() {
    let textStorage = textView.textStorage
    let fullRange = NSRange(location: 0, length: textStorage.length)
    let selected = textView.selectedRange

    textStorage.beginEditing()
    textStorage.setAttributes([
      .foregroundColor: UIColor.label,
      .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    ], range: fullRange)

    for keyword in keywords {
      let pattern = "\\b\(keyword)\\b"
      if let regex = try? NSRegularExpression(pattern: pattern) {
        let matches = regex.matches(in: textView.text, range: fullRange)
        for match in matches {
          textStorage.addAttributes([
            .foregroundColor: UIColor.systemBlue,
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
          ], range: match.range)
        }
      }
    }

    textStorage.endEditing()
    textView.selectedRange = selected
  }
}
