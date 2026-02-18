import SwiftUI

struct FileEditorView: View {
  let fileURL: URL
  @Environment(\.dismiss) var dismiss
  @State private var codeText: String = ""
  
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
      
      Button("Speichern & schließen") {
        // Tastatur nur hier schließen
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        saveFile()
        dismiss()
      }
      .padding()
    }
    .padding()
    .onAppear(perform: loadFile)
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
  
  func makeUIView(context: Context) -> UIView {
    let container = UIView()
    
    // Hintergrund für Zeilennummern
    let lineNumbersView = UITextView()
    lineNumbersView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    lineNumbersView.backgroundColor = UIColor.secondarySystemBackground
    lineNumbersView.isEditable = false
    lineNumbersView.isScrollEnabled = true
    lineNumbersView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
    
    // Vordergrund für editierbaren Code
    let codeView = UITextView()
    codeView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    codeView.backgroundColor = .clear
    codeView.delegate = context.coordinator
    codeView.isScrollEnabled = true
    codeView.autocorrectionType = .no
    codeView.autocapitalizationType = .none
    codeView.textContainerInset = UIEdgeInsets(top: 8, left: 40, bottom: 8, right: 8)
    
    container.addSubview(lineNumbersView)
    container.addSubview(codeView)
    
    lineNumbersView.translatesAutoresizingMaskIntoConstraints = false
    codeView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      lineNumbersView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      lineNumbersView.topAnchor.constraint(equalTo: container.topAnchor),
      lineNumbersView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      lineNumbersView.widthAnchor.constraint(equalToConstant: 40),
      
      codeView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      codeView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      codeView.topAnchor.constraint(equalTo: container.topAnchor),
      codeView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])
    
    // Scroll synchronisieren, Tastatur NICHT automatisch schließen
    codeView.addObserver(context.coordinator, forKeyPath: "contentOffset", options: .new, context: nil)
    context.coordinator.lineNumbersView = lineNumbersView
    context.coordinator.codeView = codeView
    
    return container
  }
  
  func updateUIView(_ uiView: UIView, context: Context) {
    guard let codeView = context.coordinator.codeView, let lineNumbersView = context.coordinator.lineNumbersView else { return }
    
    let selectedRange = codeView.selectedRange
    codeView.attributedText = highlightedText(text)
    codeView.selectedRange = selectedRange
    
    // Zeilennummern aktualisieren – Korrektur für EnumeratedSequence
    let lines = text.components(separatedBy: "\n")
    lineNumbersView.text = lines.enumerated().map { index, _ in "\(index + 1)" }.joined(separator: "\n")
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
    }
    
    // Scroll synchronisieren, Tastatur bleibt
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
      if keyPath == "contentOffset" {
        if let codeView = codeView, let lineNumbersView = lineNumbersView {
          lineNumbersView.contentOffset = codeView.contentOffset
          // Tastatur wird hier NICHT geschlossen
        }
      }
    }
    
    deinit {
      codeView?.removeObserver(self, forKeyPath: "contentOffset")
    }
  }
  
  // Syntax-Highlighting
  private func highlightedText(_ code: String) -> NSAttributedString {
    let attrString = NSMutableAttributedString(string: code)
    let fullRange = NSRange(location: 0, length: attrString.length)
    
    attrString.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
    attrString.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular), range: fullRange)
    
    for keyword in keywords {
      let pattern = "\\b\(keyword)\\b"
      if let regex = try? NSRegularExpression(pattern: pattern) {
        let nsString = code as NSString
        let matches = regex.matches(in: code, range: NSRange(location: 0, length: nsString.length))
        for match in matches {
          attrString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: match.range)
          attrString.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 14, weight: .bold), range: match.range)
        }
      }
    }
    
    return attrString
  }
}
