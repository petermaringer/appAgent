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
class LineNumberTextView: UIView {
  let textView = UITextView()
  private let gutterView = UITextView()
  var keywords: [String] = []
  
  private let gutterWidthPadding: CGFloat = 8
  private var lastLineCount: Int = 0
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  private func setup() {
    // Gutter
    gutterView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    gutterView.backgroundColor = UIColor.secondarySystemBackground
    gutterView.isEditable = false
    gutterView.isScrollEnabled = false
    gutterView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 0)
    addSubview(gutterView)
    
    // Code TextView
    textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    textView.backgroundColor = .clear
    textView.autocorrectionType = .no
    textView.autocapitalizationType = .none
    textView.isScrollEnabled = true
    textView.textContainerInset = UIEdgeInsets(top: 8, left: 50, bottom: 8, right: 8)
    addSubview(textView)
    
    textView.translatesAutoresizingMaskIntoConstraints = false
    gutterView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      gutterView.leadingAnchor.constraint(equalTo: leadingAnchor),
      gutterView.topAnchor.constraint(equalTo: topAnchor),
      gutterView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      textView.leadingAnchor.constraint(equalTo: leadingAnchor),
      textView.trailingAnchor.constraint(equalTo: trailingAnchor),
      textView.topAnchor.constraint(equalTo: topAnchor),
      textView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
    
    textView.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
  }
  
  deinit {
    textView.removeObserver(self, forKeyPath: "contentOffset")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    updateGutterFrame()
  }
  
  private func updateGutterFrame() {
    let contentHeight = max(textView.contentSize.height, bounds.height)
    let maxLineNumber = max(numberOfLines(), 1)
    
    let digits = String(maxLineNumber).count
    let sample = String(repeating: "8", count: digits) as NSString
    let width = sample.size(withAttributes: [.font: gutterView.font!]).width + gutterWidthPadding
    
    gutterView.frame = CGRect(x: 0, y: 0, width: width, height: contentHeight)
    textView.textContainerInset.left = width + 4
  }
  
  func numberOfLines() -> Int {
    return max(textView.text.components(separatedBy: "\n").count, 1)
  }
  
  func updateLineNumbers() {
    let lines = textView.text.components(separatedBy: "\n")
    gutterView.text = lines.enumerated().map { "\($0.offset + 1)" }.joined(separator: "\n")
    setNeedsLayout()
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
  
  func syncScroll() {
    gutterView.contentOffset = textView.contentOffset
  }
  
  override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                             change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    if keyPath == "contentOffset" {
      syncScroll()
    }
  }
}
