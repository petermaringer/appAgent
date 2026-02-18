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

  func makeUIView(context: Context) -> LineNumberTextView {
    let view = LineNumberTextView()
    view.textView.text = text
    view.keywords = keywords
    view.applyHighlighting()
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

// MARK: - LineNumberTextView (neu konzipiert)
class LineNumberTextView: UIView {

  let textView = UITextView()
  private let gutterLayer = CATextLayer()
  var keywords: [String] = []

  private let gutterPadding: CGFloat = 6
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
    textView.isScrollEnabled = true
    textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    addSubview(textView)

    gutterLayer.contentsScale = UIScreen.main.scale
    gutterLayer.alignmentMode = .right
    gutterLayer.foregroundColor = UIColor.secondaryLabel.cgColor
    layer.addSublayer(gutterLayer)

    // Synchronisiertes Scrollen
    textView.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
  }

  deinit {
    textView.removeObserver(self, forKeyPath: "contentOffset")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    updateGutterWidth()
    textView.frame = CGRect(x: gutterWidth, y: 0, width: bounds.width - gutterWidth, height: bounds.height)
    gutterLayer.frame = CGRect(x: 0, y: 0, width: gutterWidth - gutterPadding, height: bounds.height)
    refresh()
  }

  func refresh() {
    let lines = textView.text.components(separatedBy: "\n")
    let lineCount = max(lines.count, 1)

    // Breite dynamisch
    let digits = String(lineCount).count
    let sample = String(repeating: "8", count: digits) as NSString
    let width = sample.size(withAttributes: [.font: textView.font!]).width + gutterPadding
    gutterWidth = width

    // Gutter-Inhalt auf Layer
    let attrString = NSMutableAttributedString()
    for (i, _) in lines.enumerated() {
      attrString.append(NSAttributedString(
        string: "\(i + 1)\n",
        attributes: [.font: textView.font!]
      ))
    }
    gutterLayer.string = attrString
    gutterLayer.frame = CGRect(x: 0, y: -textView.contentOffset.y, width: gutterWidth - gutterPadding, height: CGFloat(lineCount) * textView.font!.lineHeight)
  }

  private func updateGutterWidth() {
    let lines = textView.text.components(separatedBy: "\n")
    let lineCount = max(lines.count, 1)
    let digits = String(lineCount).count
    let sample = String(repeating: "8", count: digits) as NSString
    gutterWidth = sample.size(withAttributes: [.font: textView.font!]).width + gutterPadding
  }

  override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                             change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    if keyPath == "contentOffset" {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      gutterLayer.frame.origin.y = -textView.contentOffset.y
      CATransaction.commit()
    }
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
