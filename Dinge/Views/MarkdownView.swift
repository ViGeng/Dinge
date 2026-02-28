//
//  MarkdownView.swift
//  Dinge
//
//  Renders Markdown text with headings, code blocks, images,
//  lists, blockquotes, checkboxes (- [ ] / - [x]), and inline formatting.
//

import SwiftUI

struct MarkdownView: View {
    let text: String
    /// Called with the line index when a checkbox is toggled.
    var onToggleCheckbox: ((Int) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    // MARK: - Block Types

    private enum Block {
        case heading(Int, String)
        case paragraph(String)
        case codeBlock(String)
        case image(String, String)
        case listItem(String, Bool, Int)       // content, ordered, index
        case checkboxItem(String, Bool, Int)   // content, isChecked, lineIndex
        case blockquote(String)
        case divider
    }

    // MARK: - Parser

    private func parseBlocks() -> [Block] {
        var blocks: [Block] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0
        var paragraph = ""

        func flushParagraph() {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { blocks.append(.paragraph(trimmed)) }
            paragraph = ""
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code block
            if trimmed.hasPrefix("```") {
                flushParagraph()
                var code = ""
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code += (code.isEmpty ? "" : "\n") + lines[i]
                    i += 1
                }
                blocks.append(.codeBlock(code))
                i += 1
                continue
            }

            // Heading
            if trimmed.range(of: "^(#{1,6})\\s+(.+)", options: .regularExpression) != nil {
                flushParagraph()
                let hashes = trimmed.prefix(while: { $0 == "#" })
                let content = String(trimmed.dropFirst(hashes.count).drop(while: { $0 == " " }))
                blocks.append(.heading(hashes.count, content))
                i += 1
                continue
            }

            // Image
            if let imgMatch = trimmed.range(of: "^!\\[([^\\]]*)\\]\\(([^)]+)\\)$", options: .regularExpression) {
                flushParagraph()
                let inner = String(trimmed[imgMatch])
                let regex = try! NSRegularExpression(pattern: "!\\[([^\\]]*)\\]\\(([^)]+)\\)")
                let nsRange = NSRange(inner.startIndex..., in: inner)
                if let m = regex.firstMatch(in: inner, range: nsRange),
                   let altRange = Range(m.range(at: 1), in: inner),
                   let urlRange = Range(m.range(at: 2), in: inner) {
                    blocks.append(.image(String(inner[altRange]), String(inner[urlRange])))
                }
                i += 1
                continue
            }

            // Horizontal rule
            if trimmed.count >= 3 && trimmed.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }) {
                let chars = Set(trimmed)
                if chars.count == 1 {
                    flushParagraph()
                    blocks.append(.divider)
                    i += 1
                    continue
                }
            }

            // Checkbox list item: - [ ] / - [x] / [ ] / [x]
            do {
                let hasDash = trimmed.hasPrefix("- ")
                let afterDash = hasDash ? String(trimmed.dropFirst(2)) : trimmed
                if afterDash.hasPrefix("[") && afterDash.count >= 3 {
                    let inner = afterDash.dropFirst(1)
                    if inner.hasPrefix(" ] ") || inner.hasPrefix("x] ") || inner.hasPrefix("X] ") ||
                       inner == " ]" || inner == "x]" || inner == "X]" {
                        flushParagraph()
                        let isChecked = inner.first == "x" || inner.first == "X"
                        let content = inner.count > 3 ? String(inner.dropFirst(3)) : ""
                        blocks.append(.checkboxItem(content, isChecked, i))
                        i += 1
                        continue
                    }
                }
            }

            // Unordered list
            if (trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ")) && trimmed.count > 2 {
                flushParagraph()
                blocks.append(.listItem(String(trimmed.dropFirst(2)), false, 0))
                i += 1
                continue
            }

            // Ordered list
            if let dotIdx = trimmed.firstIndex(of: "."),
               let num = Int(trimmed[trimmed.startIndex..<dotIdx]),
               trimmed[trimmed.index(after: dotIdx)...].hasPrefix(" ") {
                flushParagraph()
                let content = String(trimmed[trimmed.index(dotIdx, offsetBy: 2)...])
                blocks.append(.listItem(content, true, num))
                i += 1
                continue
            }

            // Blockquote
            if trimmed.hasPrefix("> ") {
                flushParagraph()
                blocks.append(.blockquote(String(trimmed.dropFirst(2))))
                i += 1
                continue
            }

            // Empty line → paragraph break
            if trimmed.isEmpty {
                flushParagraph()
                i += 1
                continue
            }

            // Regular text
            paragraph += (paragraph.isEmpty ? "" : "\n") + line
            i += 1
        }

        flushParagraph()
        return blocks
    }

    // MARK: - Rendering

    @ViewBuilder
    private func renderBlock(_ block: Block) -> some View {
        switch block {
        case .heading(let level, let content):
            Text(inline(content))
                .font(headingFont(level))
                .fontWeight(.bold)
                .padding(.top, level <= 2 ? 4 : 0)

        case .paragraph(let content):
            Text(inline(content))
                .textSelection(.enabled)

        case .codeBlock(let code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.15)))

        case .image(let alt, let url):
            if let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    case .failure:
                        Label(alt.isEmpty ? "Image" : alt, systemImage: "photo")
                            .foregroundStyle(.secondary)
                    default:
                        ProgressView().frame(height: 100)
                    }
                }
            }

        case .listItem(let content, let ordered, let index):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(ordered ? "\(index)." : "•")
                    .foregroundStyle(.secondary)
                Text(inline(content))
            }
            .padding(.leading, 8)

        case .checkboxItem(let content, let isChecked, let lineIndex):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Button(action: { onToggleCheckbox?(lineIndex) }) {
                    Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isChecked ? Color.accentColor : .secondary)
                        .font(.callout)
                }
                .buttonStyle(.plain)

                Text(inline(content))
                    .strikethrough(isChecked)
                    .foregroundStyle(isChecked ? .secondary : .primary)
            }
            .padding(.leading, 4)

        case .blockquote(let content):
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 3)
                Text(inline(content))
                    .foregroundStyle(.secondary)
                    .italic()
                    .padding(.leading, 10)
            }
            .padding(.vertical, 2)

        case .divider:
            Divider()
        }
    }

    // MARK: - Helpers

    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title
        case 2: .title2
        case 3: .title3
        case 4: .headline
        default: .subheadline
        }
    }
}

// MARK: - Checkbox Toggle Helper

extension MarkdownView {
    /// Toggles a checkbox line at the given line index in the text.
    /// Returns the updated text.
    static func toggleCheckbox(in text: String, atLine lineIndex: Int) -> String {
        var lines = text.components(separatedBy: "\n")
        guard lineIndex < lines.count else { return text }
        let line = lines[lineIndex]
        if line.contains("- [ ]") {
            lines[lineIndex] = line.replacingOccurrences(of: "- [ ]", with: "- [x]")
        } else if line.contains("- [x]") || line.contains("- [X]") {
            lines[lineIndex] = line.replacingOccurrences(of: "- [x]", with: "- [ ]")
                .replacingOccurrences(of: "- [X]", with: "- [ ]")
        } else if line.contains("[ ]") {
            lines[lineIndex] = line.replacingOccurrences(of: "[ ]", with: "[x]")
        } else if line.contains("[x]") || line.contains("[X]") {
            lines[lineIndex] = line.replacingOccurrences(of: "[x]", with: "[ ]")
                .replacingOccurrences(of: "[X]", with: "[ ]")
        }
        return lines.joined(separator: "\n")
    }
}
