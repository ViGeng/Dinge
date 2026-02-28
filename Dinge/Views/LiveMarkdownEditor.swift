//
//  LiveMarkdownEditor.swift
//  Dinge
//
//  A live markdown editor wrapping NSTextView.
//  Renders bold, italic, code, links, headings, checkboxes, highlights,
//  and #tags in real-time as the user types. Click checkboxes to toggle.
//

import SwiftUI
import AppKit

// MARK: - MarkdownTextView

/// Auto-growing NSTextView with placeholder and checkbox click support.
/// Key: overrides `setFrameSize` to keep the text container width in sync
/// with the actual view width — this prevents the narrow-column wrapping bug
/// that occurs when hosting NSTextView inside NSViewRepresentable.
final class MarkdownTextView: NSTextView {
    var placeholderString = "" { didSet { setNeedsDisplay(bounds) } }

    /// Sync text container width whenever SwiftUI / Auto Layout changes our frame.
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if let tc = textContainer, newSize.width > 0 {
            let containerW = newSize.width - textContainerInset.width * 2
            if abs(tc.containerSize.width - containerW) > 0.5 {
                tc.containerSize.width = containerW
            }
        }
    }

    override var intrinsicContentSize: NSSize {
        guard let lm = layoutManager, let tc = textContainer else { return super.intrinsicContentSize }
        lm.ensureLayout(for: tc)
        let h = lm.usedRect(for: tc).height + textContainerInset.height * 2
        return NSSize(width: NSView.noIntrinsicMetric, height: max(ceil(h), 18))
    }

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }

    // Placeholder
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholderString.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font ?? .systemFont(ofSize: 13),
            .foregroundColor: NSColor.placeholderTextColor
        ]
        (placeholderString as NSString).draw(
            at: NSPoint(x: textContainerInset.width + 5, y: textContainerInset.height),
            withAttributes: attrs
        )
    }

    // Always paste as plain text
    override func paste(_ sender: Any?) { pasteAsPlainText(sender) }

    // Click on checkbox marker (- [ ] / - [x]) to toggle,
    // or open link when clicking on link text.
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let lm = layoutManager, let tc = textContainer else { super.mouseDown(with: event); return }
        var fraction: CGFloat = 0
        let glyph = lm.glyphIndex(for: point, in: tc, fractionOfDistanceThroughGlyph: &fraction)
        let charIdx = lm.characterIndexForGlyph(at: glyph)
        if toggleCheckbox(at: charIdx) { return }

        // Open link if clicked on link text
        if charIdx < (string as NSString).length,
           let storage = textStorage,
           let url = storage.attribute(.link, at: charIdx, effectiveRange: nil) as? URL {
            NSWorkspace.shared.open(url)
            return
        }

        super.mouseDown(with: event)
    }

    // Show pointing-hand cursor over links
    override func resetCursorRects() {
        super.resetCursorRects()
        guard let storage = textStorage, let lm = layoutManager, let tc = textContainer else { return }
        let full = NSRange(location: 0, length: storage.length)
        storage.enumerateAttribute(.link, in: full) { value, range, _ in
            guard value != nil else { return }
            let glyphRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let rect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
            let adjustedRect = rect.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
            addCursorRect(adjustedRect, cursor: .pointingHand)
        }
    }

    private func toggleCheckbox(at idx: Int) -> Bool {
        let ns = string as NSString
        guard idx < ns.length else { return false }
        let lineRange = ns.lineRange(for: NSRange(location: idx, length: 0))
        let line = ns.substring(with: lineRange).replacingOccurrences(of: "\n", with: "")
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let leadingLen = line.prefix(while: { $0 == " " || $0 == "\t" }).count

        // Click must be near the checkbox marker area
        let clickOffset = idx - lineRange.location
        guard clickOffset < leadingLen + 7 else { return false }

        let rep: String
        let repLen: Int
        if trimmed.hasPrefix("- [ ] ")      { rep = "- [x] "; repLen = 6 }
        else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") { rep = "- [ ] "; repLen = 6 }
        else if trimmed.hasPrefix("[ ] ")   { rep = "[x] "; repLen = 4 }
        else if trimmed.hasPrefix("[x] ") || trimmed.hasPrefix("[X] ") { rep = "[ ] "; repLen = 4 }
        else { return false }

        let r = NSRange(location: lineRange.location + leadingLen, length: repLen)
        if shouldChangeText(in: r, replacementString: rep) {
            replaceCharacters(in: r, with: rep)
            didChangeText()
        }
        return true
    }
}

// MARK: - LiveMarkdownEditor

struct LiveMarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var font: NSFont = .systemFont(ofSize: 13)
    var textColor: NSColor = .secondaryLabelColor

    func makeNSView(context: Context) -> MarkdownTextView {
        let tv = MarkdownTextView()
        tv.delegate = context.coordinator
        tv.font = font
        tv.textColor = textColor
        tv.backgroundColor = .clear
        tv.drawsBackground = false
        tv.isRichText = true
        tv.allowsUndo = true
        tv.usesFontPanel = false
        tv.usesRuler = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.textContainerInset = NSSize(width: 0, height: 2)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]

        // Start with a large container width so text doesn't wrap at 0px.
        // setFrameSize() will correct this as soon as SwiftUI assigns the real frame.
        tv.textContainer?.widthTracksTextView = false
        tv.textContainer?.containerSize = NSSize(width: 10_000, height: CGFloat.greatestFiniteMagnitude)

        tv.setContentHuggingPriority(.defaultHigh, for: .vertical)
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tv.setContentCompressionResistancePriority(.required, for: .horizontal)
        tv.placeholderString = placeholder
        tv.string = text
        context.coordinator.applyFormatting(tv)
        return tv
    }

    func updateNSView(_ tv: MarkdownTextView, context: Context) {
        guard tv.string != text, !context.coordinator.isUpdating else { return }
        context.coordinator.isUpdating = true
        defer { context.coordinator.isUpdating = false }
        let sel = tv.selectedRanges
        tv.string = text
        context.coordinator.applyFormatting(tv)
        tv.selectedRanges = sel
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: MarkdownTextView, context: Context) -> CGSize? {
        let w = proposal.width ?? nsView.bounds.width
        guard w > 0, let lm = nsView.layoutManager, let tc = nsView.textContainer else { return nil }

        // Temporarily set the container to the proposed width to calculate the correct height.
        let prevWidth = tc.containerSize.width
        let targetWidth = w - nsView.textContainerInset.width * 2
        tc.containerSize.width = targetWidth
        lm.ensureLayout(for: tc)
        let h = max(ceil(lm.usedRect(for: tc).height) + nsView.textContainerInset.height * 2, 20)

        // Restore if the text view hasn't been sized yet (avoid persisting the wrong value).
        if nsView.bounds.width <= 0 {
            tc.containerSize.width = prevWidth
        }

        return CGSize(width: w, height: h)
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, baseFont: font, baseColor: textColor) }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        let baseFont: NSFont
        let baseColor: NSColor
        var isUpdating = false

        init(text: Binding<String>, baseFont: NSFont, baseColor: NSColor) {
            self.text = text; self.baseFont = baseFont; self.baseColor = baseColor
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? MarkdownTextView, !isUpdating else { return }
            isUpdating = true
            defer { isUpdating = false }
            text.wrappedValue = tv.string
            applyFormatting(tv)
        }

        /// Re-apply formatting when cursor moves so syntax markers show/hide.
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? MarkdownTextView, !isUpdating else { return }
            isUpdating = true
            defer { isUpdating = false }
            applyFormatting(tv)
        }

        // MARK: Formatting

        func applyFormatting(_ tv: NSTextView) {
            guard let storage = tv.textStorage, storage.length > 0 else { return }
            let raw = storage.string
            let ns = raw as NSString
            let sel = tv.selectedRanges

            // Determine lines the cursor is on → show raw markdown only on these lines
            let editingLineRange: NSRange
            if let selVal = sel.first as? NSValue {
                let selRange = selVal.rangeValue
                if selRange.location != NSNotFound && selRange.location <= ns.length {
                    let clamped = NSRange(
                        location: min(selRange.location, ns.length),
                        length: min(selRange.length, ns.length - min(selRange.location, ns.length))
                    )
                    editingLineRange = ns.lineRange(for: clamped)
                } else {
                    editingLineRange = NSRange(location: NSNotFound, length: 0)
                }
            } else {
                editingLineRange = NSRange(location: NSNotFound, length: 0)
            }

            let full = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.setAttributes([.font: baseFont, .foregroundColor: baseColor], range: full)

            // Line-level
            var offset = 0
            for line in raw.components(separatedBy: "\n") {
                let len = (line as NSString).length
                let lineRange = NSRange(location: offset, length: len)
                let isEditing = editingLineRange.location != NSNotFound
                    && NSIntersectionRange(lineRange, editingLineRange).length > 0
                formatLine(line, range: lineRange, storage: storage, isEditing: isEditing)
                offset += len + 1
            }

            // Inline
            formatInline(storage, text: raw, editingLineRange: editingLineRange)
            storage.endEditing()

            tv.selectedRanges = sel
            tv.typingAttributes = [.font: baseFont, .foregroundColor: baseColor]
            tv.resetCursorRects()
        }

        // MARK: Line-level

        private func formatLine(_ line: String, range: NSRange, storage: NSTextStorage, isEditing: Bool) {
            guard range.length > 0 else { return }

            // Headings: # through ######
            if line.range(of: "^#{1,6}\\s", options: .regularExpression) != nil {
                let level = line.prefix(while: { $0 == "#" }).count
                let sizes: [CGFloat] = [22, 19, 17, 15, 14, 13]
                let sz = sizes[min(level, sizes.count) - 1]
                storage.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: sz), range: range)
                let hashLen = min(level + 1, range.length)
                hideOrDim(storage, range: NSRange(location: range.location, length: hashLen), isEditing: isEditing)
                return
            }

            // Checkbox: "- [ ] ", "[ ] ", "- [x] ", "[x] " (with optional leading whitespace)
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            let leadingLen = line.prefix(while: { $0 == " " || $0 == "\t" }).count
            let hasDash = trimmedLine.hasPrefix("- ")
            let afterDash = hasDash ? String(trimmedLine.dropFirst(2)) : trimmedLine
            let isUnchecked = afterDash.hasPrefix("[ ] ") || afterDash == "[ ]"
            let isChecked = afterDash.hasPrefix("[x] ") || afterDash.hasPrefix("[X] ") || afterDash == "[x]" || afterDash == "[X]"

            if isUnchecked || isChecked {
                let dashLen = hasDash ? 2 : 0
                let markerStart = range.location + leadingLen
                let bracketLen = 3 // [ ] or [x]
                let hasContent = afterDash.count > 3
                let fullMarkerLen = dashLen + bracketLen + (hasContent ? 1 : 0)

                if isEditing {
                    storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor,
                                        range: NSRange(location: markerStart, length: min(fullMarkerLen, range.length - leadingLen)))
                } else {
                    // Hide entire marker, then place a checkbox icon on the "[" character
                    let markerLen = min(fullMarkerLen, range.length - leadingLen)
                    hideOrDim(storage, range: NSRange(location: markerStart, length: markerLen), isEditing: false)

                    // Render SF Symbol checkbox icon via NSTextAttachment on the "[" char
                    let iconName = isChecked ? "checkmark.square.fill" : "square"
                    let iconColor = isChecked ? NSColor.controlAccentColor : NSColor.secondaryLabelColor
                    let iconSize = baseFont.pointSize + 2
                    if let symbolImg = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
                        let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .regular)
                        let configured = symbolImg.withSymbolConfiguration(config) ?? symbolImg
                        // Pre-tint the image so the color shows correctly
                        let tinted = NSImage(size: configured.size, flipped: false) { rect in
                            iconColor.set()
                            configured.draw(in: rect)
                            return true
                        }
                        tinted.isTemplate = false
                        let attachment = NSTextAttachment()
                        attachment.image = tinted
                        let yOffset = (baseFont.capHeight - iconSize) / 2.0
                        attachment.bounds = CGRect(x: 0, y: yOffset, width: iconSize, height: iconSize)
                        let iconRange = NSRange(location: markerStart + dashLen, length: 1)
                        storage.addAttribute(.attachment, value: attachment, range: iconRange)
                    }
                }
                // Strikethrough content for checked items
                if isChecked {
                    let contentStart = markerStart + fullMarkerLen
                    let contentLen = range.location + range.length - contentStart
                    if contentLen > 0 {
                        let rest = NSRange(location: contentStart, length: contentLen)
                        storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: rest)
                        storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: rest)
                    }
                }
                return
            }

            // Unordered list items: "- " or "* "
            if (line.hasPrefix("- ") || line.hasPrefix("* ")), line.count > 2 {
                storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor,
                                    range: NSRange(location: range.location, length: 1))
                return
            }

            // Blockquotes
            if line.hasPrefix("> "), range.length > 2 {
                hideOrDim(storage, range: NSRange(location: range.location, length: 2), isEditing: isEditing)
                let body = NSRange(location: range.location + 2, length: range.length - 2)
                storage.addAttribute(.font, value: NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask), range: body)
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: body)
            }
        }

        // MARK: Inline

        private func formatInline(_ storage: NSTextStorage, text: String, editingLineRange: NSRange) {
            let full = NSRange(location: 0, length: (text as NSString).length)

            // Bold: **text** or __text__
            apply("\\*\\*(.+?)\\*\\*", in: text, to: storage) { s, m in
                let editing = self.overlaps(m.range, editingLineRange)
                s.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: self.baseFont.pointSize), range: m.range(at: 1))
                self.dimInline(s, match: m.range, content: m.range(at: 1), isEditing: editing)
            }
            apply("__(.+?)__", in: text, to: storage) { s, m in
                let editing = self.overlaps(m.range, editingLineRange)
                s.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: self.baseFont.pointSize), range: m.range(at: 1))
                self.dimInline(s, match: m.range, content: m.range(at: 1), isEditing: editing)
            }

            // Italic: *text* (not **) or _text_ (not __)
            apply("(?<!\\*)\\*(?!\\*| )(.+?)(?<! )\\*(?!\\*)", in: text, to: storage) { s, m in
                let editing = self.overlaps(m.range, editingLineRange)
                s.addAttribute(.font, value: NSFontManager.shared.convert(self.baseFont, toHaveTrait: .italicFontMask), range: m.range(at: 1))
                self.dimInline(s, match: m.range, content: m.range(at: 1), isEditing: editing)
            }
            apply("(?<!_)_(?!_| )(.+?)(?<! )_(?!_)", in: text, to: storage) { s, m in
                let editing = self.overlaps(m.range, editingLineRange)
                s.addAttribute(.font, value: NSFontManager.shared.convert(self.baseFont, toHaveTrait: .italicFontMask), range: m.range(at: 1))
                self.dimInline(s, match: m.range, content: m.range(at: 1), isEditing: editing)
            }

            // Strikethrough: ~~text~~
            apply("~~(.+?)~~", in: text, to: storage) { s, m in
                let editing = self.overlaps(m.range, editingLineRange)
                s.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: m.range(at: 1))
                self.dimInline(s, match: m.range, content: m.range(at: 1), isEditing: editing)
            }

            // Inline code: `text`
            apply("`([^`]+)`", in: text, to: storage) { s, m in
                let editing = self.overlaps(m.range, editingLineRange)
                let mono = NSFont.monospacedSystemFont(ofSize: self.baseFont.pointSize - 1, weight: .regular)
                s.addAttribute(.font, value: mono, range: m.range(at: 1))
                s.addAttribute(.backgroundColor, value: NSColor.quaternaryLabelColor, range: m.range(at: 1))
                self.dimInline(s, match: m.range, content: m.range(at: 1), isEditing: editing)
            }

            // Highlight: ==text==
            apply("==(.+?)==", in: text, to: storage) { s, m in
                let editing = self.overlaps(m.range, editingLineRange)
                s.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.3), range: m.range(at: 1))
                self.dimInline(s, match: m.range, content: m.range(at: 1), isEditing: editing)
            }

            // Links: [text](url) — clickable blue text, syntax hidden when not editing
            let linkRx = try! NSRegularExpression(pattern: "\\[(.+?)\\]\\((.+?)\\)")
            for m in linkRx.matches(in: text, range: full) {
                let editing = overlaps(m.range, editingLineRange)
                let linkTextRange = m.range(at: 1)
                let urlRange = m.range(at: 2)

                // Style link text as blue underlined
                storage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: linkTextRange)
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: linkTextRange)
                if let urlStr = Range(urlRange, in: text).map({ String(text[$0]) }),
                   let url = URL(string: urlStr) {
                    storage.addAttribute(.link, value: url, range: linkTextRange)
                }

                // Hide or dim "[" before link text
                let openBracket = NSRange(location: m.range.location, length: 1)
                hideOrDim(storage, range: openBracket, isEditing: editing)

                // Hide or dim "](url)" after link text
                let closePart = NSRange(
                    location: linkTextRange.location + linkTextRange.length,
                    length: m.range.location + m.range.length - linkTextRange.location - linkTextRange.length
                )
                hideOrDim(storage, range: closePart, isEditing: editing)
            }

            // Tags: #word (not heading markers)
            let tagRx = try! NSRegularExpression(pattern: "(?<![\\w#])#(\\w+)")
            for m in tagRx.matches(in: text, range: full) {
                storage.addAttribute(.foregroundColor, value: NSColor.controlAccentColor, range: m.range)
            }
        }

        // MARK: Helpers

        private func overlaps(_ range: NSRange, _ editingLineRange: NSRange) -> Bool {
            guard editingLineRange.location != NSNotFound else { return false }
            return NSIntersectionRange(range, editingLineRange).length > 0
        }

        /// Make syntax markers invisible (when not editing) or dim (when editing).
        private func hideOrDim(_ storage: NSTextStorage, range: NSRange, isEditing: Bool) {
            guard range.length > 0 else { return }
            if isEditing {
                storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: range)
            } else {
                storage.addAttributes([
                    .font: NSFont.systemFont(ofSize: 0.01),
                    .foregroundColor: NSColor.clear
                ], range: range)
            }
        }

        /// Hide or dim the syntax markers around inline content (e.g. ** around bold).
        private func dimInline(_ s: NSTextStorage, match: NSRange, content: NSRange, isEditing: Bool) {
            let pre = content.location - match.location
            if pre > 0 {
                hideOrDim(s, range: NSRange(location: match.location, length: pre), isEditing: isEditing)
            }
            let postStart = content.location + content.length
            let post = (match.location + match.length) - postStart
            if post > 0 {
                hideOrDim(s, range: NSRange(location: postStart, length: post), isEditing: isEditing)
            }
        }

        private func apply(_ pattern: String, in text: String, to s: NSTextStorage,
                           _ body: (NSTextStorage, NSTextCheckingResult) -> Void) {
            guard let rx = try? NSRegularExpression(pattern: pattern) else { return }
            for m in rx.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)) {
                body(s, m)
            }
        }
    }
}
