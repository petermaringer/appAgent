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
      lineNumbersView.text = lines.enumerated().map { "\($0.offset + 1)" }.joined(separator: "\n")
      
      let digits = max(3, String(lines.count).count)
      let sample = String(repeating: "8", count: digits) as NSString
      let width = sample.size(withAttributes: [.font: lineNumbersView.font!]).width + 16
      
      if let constraint = lineNumbersView.constraints.first(where: { $0.firstAttribute == .width }) {
        constraint.constant = width
      } else {
        lineNumbersView.widthAnchor.constraint(equalToConstant: width).isActive = true
      }
      
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
  }
}
