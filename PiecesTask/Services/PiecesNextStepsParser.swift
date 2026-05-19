import Foundation

enum PiecesNextStepsParser {
  /// Pull bullet lines from the `### **Next Steps**` section of a SUMMARY annotation.
  static func parse(from text: String) -> [String] {
    guard let section = extractNextStepsSection(from: text) else { return [] }

    var steps: [String] = []
    for line in section.split(separator: "\n", omittingEmptySubsequences: false) {
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard trimmed.hasPrefix("-") || trimmed.hasPrefix("*") else { continue }

      var content = trimmed
      while let first = content.first, first == "-" || first == "*" || first == " " {
        content.removeFirst()
      }
      content = stripMarkdown(content.trimmingCharacters(in: .whitespacesAndNewlines))
      if content.count >= 4 {
        steps.append(content)
      }
    }
    return steps
  }

  private static func extractNextStepsSection(from text: String) -> String? {
    let markers = [
      "### **Next Steps**",
      "### Next Steps",
      "### **Next steps**",
    ]
    guard let marker = markers.first(where: { text.localizedCaseInsensitiveContains($0) }) else {
      return nil
    }

    guard let range = text.range(
      of: marker,
      options: [.caseInsensitive, .diacriticInsensitive]
    ) else { return nil }

    let after = text[range.upperBound...]
    if let nextHeading = after.range(of: "\n### ", options: .regularExpression) {
      return String(after[..<nextHeading.lowerBound])
    }
    return String(after)
  }

  private static func stripMarkdown(_ text: String) -> String {
    var s = text
    s = s.replacingOccurrences(of: "**", with: "")
    s = s.replacingOccurrences(of: "__", with: "")
    if s.hasSuffix(":") { s.removeLast() }
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
