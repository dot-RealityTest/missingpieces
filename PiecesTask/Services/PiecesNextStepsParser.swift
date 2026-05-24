import Foundation

enum PiecesNextStepsParser {
  /// Pull bullet lines from the `### **Next Steps**` section of a SUMMARY annotation.
  static func parse(from text: String) -> [String] {
    guard let section = extractNextStepsSection(from: text) else { return [] }

    var steps: [String] = []
    for line in section.split(separator: "\n", omittingEmptySubsequences: false) {
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard trimmed.hasPrefix("-") || trimmed.hasPrefix("*") else { continue }
      if trimmed.range(of: #"\[\s*[xX]\s*\]"#, options: .regularExpression) != nil { continue }

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

  /// Short label for the popover row — bold lead-in or text before the first colon.
  static func displayTitle(from step: String) -> String {
    let raw: String
    if let bold = extractBoldLead(from: step) {
      raw = bold
    } else if let colon = stripMarkdown(step).firstIndex(of: ":") {
      raw = String(stripMarkdown(step)[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
    } else {
      raw = stripMarkdown(step)
    }
    return plainWords(raw)
  }

  /// One-line hint under the title — the action after the colon, trimmed for scanning.
  static func displaySubtitle(from step: String) -> String? {
    guard let tail = detailTail(from: step) else { return nil }
    guard tail.count >= 10 else { return nil }
    return truncateWords(tail, limit: 72)
  }

  /// Full detail for an expanded row — only the part after the title, never a repeat of it.
  static func displayExpandedContent(from step: String) -> String? {
    if let tail = detailTail(from: step), tail.count >= 4 {
      return tail
    }

    let full = displayBody(from: step)
    let title = displayTitle(from: step)
    guard full.count > title.count + 8 else { return nil }

    let titleNorm = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let fullNorm = full.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard fullNorm.hasPrefix(titleNorm) else { return full }

    var rest = String(full.dropFirst(title.count))
      .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ":—-·")))
    return rest.count >= 8 ? rest : full
  }

  /// Full plain text for an expanded row.
  static func displayBody(from step: String) -> String {
    stripMarkdown(step).replacingOccurrences(of: "`", with: "")
  }

  /// Shorter session header when Pieces titles run long.
  static func sessionName(_ name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > 42 else { return trimmed }
    if let split = trimmed.range(of: " and ") {
      let head = String(trimmed[..<split.lowerBound])
      if head.count >= 12 { return head }
    }
    return truncateWords(trimmed, limit: 42)
  }

  private static func detailTail(from step: String) -> String? {
    var cleaned = stripMarkdown(step).replacingOccurrences(of: "`", with: "")
    guard let colon = cleaned.firstIndex(of: ":") else { return nil }
    let tail = String(cleaned[cleaned.index(after: colon)...])
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return tail.isEmpty ? nil : tail
  }

  private static func plainWords(_ text: String) -> String {
    var s = text
      .replacingOccurrences(of: "`", with: "")
      .replacingOccurrences(of: "**", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !s.isEmpty else { return s }
    if s == s.uppercased(), s.count <= 6 { return s }
    return s.prefix(1).uppercased() + s.dropFirst().lowercased()
  }

  private static func truncateWords(_ text: String, limit: Int) -> String {
    guard text.count > limit else { return text }
    let prefix = text.prefix(limit)
    if let lastSpace = prefix.lastIndex(of: " ") {
      return String(prefix[..<lastSpace]) + "…"
    }
    return String(prefix) + "…"
  }

  private static func extractBoldLead(from text: String) -> String? {
    guard let start = text.range(of: "**") else { return nil }
    let afterStart = text[start.upperBound...]
    guard let end = afterStart.range(of: "**") else { return nil }
    let lead = String(afterStart[..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    return lead.count >= 3 ? lead : nil
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
