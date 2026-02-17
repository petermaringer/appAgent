import SwiftUI

struct FileEditorView: View {
  let fileURL: URL
  @State private var codeText: String = ""
  @Environment(\.dismiss) var dismiss
  
  private let keywords = ["let","var","func","struct","class","import","if","else","for","while","return","in","enum","extension","switch","case","default","break","guard","do","try","catch"]
  
  var body: some View {
    VStack {
      Text("Bearbeite: \(fileURL.lastPathComponent)")
        .font(.headline)
        .padding()
      
      ScrollView {
        Text(highlightedCode())
          .font(.system(.body, design: .monospaced))
          .padding()
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color(UIColor.secondarySystemBackground))
          .cornerRadius(8)
          .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
      }
      
      Button("Speichern & schließen") {
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
  
  func highlightedCode() -> AttributedString {
    var attrString = AttributedString(codeText)
    
    for keyword in keywords {
      let pattern = "\\b\(keyword)\\b"
      if let regex = try? NSRegularExpression(pattern: pattern) {
        let nsString = NSString(string: codeText)
        let matches = regex.matches(in: codeText, options: [], range: NSRange(location: 0, length: nsString.length))
        for match in matches {
          if let range = Range(match.range, in: attrString) {
            attrString[range].foregroundColor = .blue
            attrString[range].font = .system(.body, design: .monospaced).bold()
          }
        }
      }
    }
    
    return attrString
  }
}
