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
// MARK: - Editierbarer CodeView mit Zeilennummern
struct SyntaxTextViewWithLineNumbersSync: UIViewRepresentable {
  @Binding var text: String
  let keywords: [String]

  func makeUIView(context: Context) -> LineNumberTextView {
    let view = LineNumberTextView()
    view.textView.text = text
    view.keywords = keywords
    view.applyHighlighting()
    view.refresh()
    view.textView.delegate = context.coordinator
    context.coordinator.editor = view
    return view
  }

  func updateUIView(_ uiView: LineNumberTextView, context: Context) {
    if uiView.textView.text != text {
      uiView.textView.text = text
      uiView.refresh()
      uiView.applyHighlighting()
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject, UITextViewDelegate {
    var parent: SyntaxTextViewWithLineNumbersSync
    weak var editor: LineNumberTextView?

    init(_ parent: SyntaxTextViewWithLineNumbersSync) {
      self.parent = parent
    }

    func textViewDidChange(_ textView: UITextView) {
      parent.text = textView.text
      editor?.refresh()
      editor?.applyHighlighting()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
      editor?.refresh()
    }
  }
}

// MARK: - Neuer LineNumberTextView
class LineNumberTextView: UIView {

  let textView = UITextView()
  private let gutterView = UIView()
  private var lineLabels: [UILabel] = []

  var keywords: [String] = []

  private let gutterPadding: CGFloat = 8
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

    // TextView Setup
    textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    textView.autocorrectionType = .no
    textView.autocapitalizationType = .none
    textView.backgroundColor = .clear
    textView.isScrollEnabled = true
    textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 8)
    textView.delegate = nil
    addSubview(textView)

    // Gutter Setup
    gutterView.backgroundColor = UIColor.secondarySystemBackground
    addSubview(gutterView)

    // Scroll synchronisieren
    textView.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
  }

  deinit {
    textView.removeObserver(self, forKeyPath: "contentOffset")
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    updateGutterWidth()

    gutterView.frame = CGRect(x: 0, y: 0, width: gutterWidth, height: bounds.height)
    textView.frame = CGRect(
      x: gutterWidth,
      y: 0,
      width: bounds.width - gutterWidth,
      height: bounds.height
    )

    updateLineLabels()
  }

  func refresh() {
    textView.layoutManager.ensureLayout(for: textView.textContainer)
    updateGutterWidth()
    updateLineLabels()
  }

  private func numberOfLines() -> Int {
    let lines = textView.text.split(separator: "\n", omittingEmptySubsequences: false)
    return max(lines.count, 1)
  }

  private func updateGutterWidth() {
    let lines = numberOfLines()
    let digits = String(lines).count
    let sample = String(repeating: "8", count: digits) as NSString
    let width = sample.size(withAttributes: [.font: textView.font!]).width
    gutterWidth = width + gutterPadding
  }

  private func updateLineLabels() {
    // Alle alten Labels entfernen
    lineLabels.forEach { $0.removeFromSuperview() }
    lineLabels.removeAll()

    let text = textView.text as NSString
    let lines = text.components(separatedBy: "\n")
    var yOffset: CGFloat = textView.textContainerInset.top

    for (i, _) in lines.enumerated() {
      let lineHeight = textView.font!.lineHeight
      let label = UILabel(frame: CGRect(x: 0, y: yOffset, width: gutterWidth - gutterPadding, height: lineHeight))
      label.font = textView.font
      label.textColor = UIColor.secondaryLabel
      label.textAlignment = .right
      label.text = "\(i + 1)"
      gutterView.addSubview(label)
      lineLabels.append(label)
      yOffset += lineHeight
    }
  }

  func applyHighlighting() {
    let textStorage = textView.textStorage
    let fullRange = NSRange(location: 0, length: textStorage.length)
    let selected = textView.selectedRange

    textStorage.beginEditing()
    textStorage.setAttributes([
      .foregroundColor: UIColor.label,
      .font: textView.font!
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

  // Synchronisiere Gutter beim Scrollen
  override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                             change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    if keyPath == "contentOffset" {
      gutterView.frame.origin.y = -textView.contentOffset.y
    }
  }
}
