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

struct SyntaxTextViewWithLineNumbersSync: UIViewRepresentable {
  @Binding var text: String
  let keywords: [String]

  func makeUIView(context: Context) -> UIScrollView {
    let scrollView = UIScrollView()
    scrollView.alwaysBounceVertical = true

    // Zeilennummern
    let lineNumberTextView = UITextView()
    lineNumberTextView.backgroundColor = UIColor.systemGray6
    lineNumberTextView.isEditable = false
    lineNumberTextView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    lineNumberTextView.textAlignment = .right
    lineNumberTextView.textColor = .gray
    lineNumberTextView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(lineNumberTextView)

    // Code TextView
    let textView = UITextView()
    textView.delegate = context.coordinator
    textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    textView.autocorrectionType = .no
    textView.autocapitalizationType = .none
    textView.backgroundColor = .white
    textView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(textView)

    context.coordinator.textView = textView
    context.coordinator.lineNumberTextView = lineNumberTextView

    context.coordinator.lineNumberWidthConstraint = lineNumberTextView.widthAnchor.constraint(equalToConstant: 40)
    context.coordinator.lineNumberWidthConstraint.isActive = true

    NSLayoutConstraint.activate([
      lineNumberTextView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
      lineNumberTextView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      lineNumberTextView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

      textView.leadingAnchor.constraint(equalTo: lineNumberTextView.trailingAnchor, constant: 4),
      textView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
      textView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      textView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      textView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -44)
    ])

    scrollView.delegate = context.coordinator
    return scrollView
  }

  func updateUIView(_ uiView: UIScrollView, context: Context) {
    context.coordinator.text = $text
    context.coordinator.updateText(text, keywords: keywords)
    context.coordinator.updateLineNumbers()
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
  }

  class Coordinator: NSObject, UITextViewDelegate, UIScrollViewDelegate {
    var textView: UITextView?
    var lineNumberTextView: UITextView?
    var lineNumberWidthConstraint: NSLayoutConstraint?
    @Binding var text: String

    init(text: Binding<String>) {
      _text = text
    }

    func textViewDidChange(_ textView: UITextView) {
      text = textView.text
      updateLineNumbers()
      applySyntaxHighlighting()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
      lineNumberTextView?.contentOffset = scrollView.contentOffset
    }

    func updateText(_ newText: String, keywords: [String]) {
      guard let textView = textView else { return }
      if textView.text != newText {
        textView.text = newText
        applySyntaxHighlighting()
      }
    }

    func updateLineNumbers() {
      guard let textView = textView, let lineNumberTextView = lineNumberTextView else { return }

      let lines = textView.text.components(separatedBy: "\n") // nur echte Zeilenumbrüche
      lineNumberTextView.text = lines.enumerated().map { "\($0.offset + 1)" }.joined(separator: "\n")

      // exakte Breite berechnen
      let maxLineNumber = lines.count
      let sampleText = "\(maxLineNumber)" as NSString
      let font = lineNumberTextView.font ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
      let attributes = [NSAttributedString.Key.font: font]
      let size = sampleText.size(withAttributes: attributes)
      lineNumberWidthConstraint?.constant = ceil(size.width) + 8
    }

    func applySyntaxHighlighting() {
      guard let textView = textView else { return }
      let attributed = NSMutableAttributedString(string: textView.text)
      let fullRange = NSRange(location: 0, length: attributed.length)
      attributed.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)

      for keyword in keywords {
        let pattern = "\\b\(keyword)\\b"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
          let matches = regex.matches(in: attributed.string, options: [], range: fullRange)
          for match in matches {
            attributed.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: match.range)
          }
        }
      }
      textView.attributedText = attributed
    }
  }
}
