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
struct SyntaxTextViewWithLineNumbersSync: UIViewRepresentable {
  @Binding var text: String
  let keywords: [String]

  func makeUIView(context: Context) -> EditorTextView {
    let textView = EditorTextView()
    textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    textView.autocorrectionType = .no
    textView.autocapitalizationType = .none
    textView.delegate = context.coordinator
    textView.setText(text, keywords: keywords)
    return textView
  }

  func updateUIView(_ uiView: EditorTextView, context: Context) {
    if uiView.text != text {
      uiView.setText(text, keywords: keywords)
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject, UITextViewDelegate {
    var parent: SyntaxTextViewWithLineNumbersSync

    init(_ parent: SyntaxTextViewWithLineNumbersSync) {
      self.parent = parent
    }

    func textViewDidChange(_ textView: UITextView) {
      parent.text = textView.text
      if let editor = textView as? EditorTextView {
        editor.applyHighlighting(keywords: parent.keywords)
      }
    }
  }
}

class EditorTextView: UITextView {

  private var gutterWidth: CGFloat = 30
  private let gutterView = LineNumberGutterView()
  private var lastLineCount: Int = 0

  override init(frame: CGRect, textContainer: NSTextContainer?) {
    super.init(frame: frame, textContainer: textContainer)
    commonInit()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    commonInit()
  }

  private func commonInit() {
    backgroundColor = .clear
    textContainer.lineFragmentPadding = 0
    textContainerInset = UIEdgeInsets(top: 8, left: gutterWidth + 8, bottom: 8, right: 8)

    gutterView.textView = self
    addSubview(gutterView)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    gutterView.frame = CGRect(x: 0, y: 0, width: gutterWidth, height: bounds.height)
    gutterView.setNeedsDisplay()
  }

  override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
    super.setContentOffset(contentOffset, animated: animated)
    gutterView.setNeedsDisplay()
  }

  func setText(_ newText: String, keywords: [String]) {
    text = newText
    applyHighlighting(keywords: keywords)
    updateGutterWidth()
    gutterView.setNeedsDisplay()
  }

  func applyHighlighting(keywords: [String]) {
    let selected = selectedRange
    let storage = textStorage
    let fullRange = NSRange(location: 0, length: storage.length)

    storage.beginEditing()
    storage.setAttributes([
      .foregroundColor: UIColor.label,
      .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    ], range: fullRange)

    for keyword in keywords {
      let pattern = "\\b\(keyword)\\b"
      if let regex = try? NSRegularExpression(pattern: pattern) {
        let matches = regex.matches(in: text, range: fullRange)
        for match in matches {
          storage.addAttributes([
            .foregroundColor: UIColor.systemBlue,
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
          ], range: match.range)
        }
      }
    }

    storage.endEditing()
    selectedRange = selected
    updateGutterWidth()
  }

  private func updateGutterWidth() {
    let lineCount = max(text.components(separatedBy: "\n").count, 1)

    if lineCount == lastLineCount { return }
    lastLineCount = lineCount

    let digits = String(lineCount).count
    let sample = String(repeating: "8", count: digits) as NSString
    let width = sample.size(withAttributes: [
      .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    ]).width + 12

    gutterWidth = max(width, 24)

    textContainerInset.left = gutterWidth + 8
    setNeedsLayout()
  }
}

class LineNumberGutterView: UIView {

  weak var textView: UITextView?

  override func draw(_ rect: CGRect) {
    guard let textView = textView else { return }

    UIColor.secondarySystemBackground.setFill()
    UIRectFill(bounds)

    let layoutManager = textView.layoutManager
    let textContainer = textView.textContainer
    layoutManager.ensureLayout(for: textContainer)

    let visibleGlyphRange = layoutManager.glyphRange(
      forBoundingRect: textView.bounds,
      in: textContainer
    )

    var glyphIndex = visibleGlyphRange.location
    var lineNumber = 1
    let text = textView.text as NSString

    while glyphIndex < visibleGlyphRange.upperBound {

      var lineRange = NSRange()
      let lineRect = layoutManager.lineFragmentRect(
        forGlyphAt: glyphIndex,
        effectiveRange: &lineRange
      )

      let charRange = layoutManager.characterRange(
        forGlyphRange: lineRange,
        actualGlyphRange: nil
      )

      if charRange.location == 0 ||
         text.substring(with: NSRange(location: charRange.location - 1, length: 1)) == "\n" {

        let y = lineRect.minY

        let attributes: [NSAttributedString.Key: Any] = [
          .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
          .foregroundColor: UIColor.secondaryLabel
        ]

        "\(lineNumber)".draw(
          at: CGPoint(x: 4, y: y),
          withAttributes: attributes
        )

        lineNumber += 1
      }

      glyphIndex = NSMaxRange(lineRange)
    }

    if text.length == 0 {
      let attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
        .foregroundColor: UIColor.secondaryLabel
      ]

      "1".draw(at: CGPoint(x: 4, y: textView.textContainerInset.top),
               withAttributes: attributes)
    }
  }
}
