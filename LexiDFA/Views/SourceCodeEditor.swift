//
//  SourceCodeEditor.swift
//  LexiDFA
//
//  Created by Amirali Yazdani on 10/13/26.
//

import SwiftUI
import UIKit

/// A UIKit-backed editor that colors the most recent tokenization and reports
/// tapped characters using the scanner's Character-based source offsets.
struct SourceCodeEditor: UIViewRepresentable {
    @Binding var text: String
    let tokens: [Token]
    let scannedSource: String
    let highlightedCharacter: Int?
    let onSelectCharacter: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isEditable = true
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.autocapitalizationType = .none
        textView.adjustsFontForContentSizeCategory = true
        textView.accessibilityLabel = "Source code editor"
        textView.accessibilityHint = "Edit source code. Tap a character after scanning to inspect its DFA transition."
        textView.textContainerInset = UIEdgeInsets(top: 5, left: 2, bottom: 5, right: 2)
        textView.textContainer.lineFragmentPadding = 1
        textView.typingAttributes = Self.baseAttributes
        textView.attributedText = styledText(for: text)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleEditorTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        tap.delegate = context.coordinator
        textView.addGestureRecognizer(tap)

        context.coordinator.lastStyledSource = text
        context.coordinator.lastTokenSignature = tokenSignature
        context.coordinator.lastHighlightedCharacter = highlightedCharacter
        return textView
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 340
        let fittingSize = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: min(300, max(190, fittingSize.height)))
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        let sourceChanged = coordinator.lastStyledSource != text || textView.text != text
        let tokensChanged = coordinator.lastTokenSignature != tokenSignature
        let highlightChanged = coordinator.lastHighlightedCharacter != highlightedCharacter

        if textView.text != text {
            coordinator.isApplyingExternalText = true
            textView.text = text
            coordinator.isApplyingExternalText = false
        }

        if sourceChanged || tokensChanged {
            let oldSelection = textView.selectedRange
            coordinator.isApplyingExternalText = true
            textView.attributedText = styledText(for: text)
            let safeLocation = min(oldSelection.location, textView.attributedText.length)
            let safeLength = min(oldSelection.length, textView.attributedText.length - safeLocation)
            textView.selectedRange = NSRange(location: safeLocation, length: safeLength)
            textView.typingAttributes = Self.baseAttributes
            coordinator.isApplyingExternalText = false
            coordinator.lastStyledSource = text
            coordinator.lastTokenSignature = tokenSignature
            coordinator.lastHighlightedCharacter = highlightedCharacter
        } else if highlightChanged {
            // Trace playback can advance many times per second. Update just the two
            // affected character ranges instead of rebuilding the whole attributed editor.
            textView.textStorage.beginEditing()
            updateFocusHighlight(in: textView, source: text, index: coordinator.lastHighlightedCharacter, enabled: false)
            updateFocusHighlight(in: textView, source: text, index: highlightedCharacter, enabled: true)
            textView.textStorage.endEditing()
            coordinator.lastHighlightedCharacter = highlightedCharacter
        }
    }

    private var tokenSignature: String {
        guard scannedSource == text else { return "out-of-sync" }
        return tokens.map { "\($0.start):\($0.end):\($0.type.rawValue)" }.joined(separator: "|")
    }

    private func styledText(for source: String) -> NSAttributedString {
        let output = NSMutableAttributedString(string: source, attributes: Self.baseAttributes)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        if output.length > 0 {
            output.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: output.length))
        }

        guard source == scannedSource else { return output }
        let offsets = CharacterUTF16Map(source)

        for token in tokens {
            guard let range = offsets.nsRange(start: token.start, end: token.end), range.length > 0 else { continue }
            output.addAttribute(.foregroundColor, value: Self.color(for: token.type), range: range)
            if token.type == .comment {
                output.addAttribute(.font, value: Self.commentFont, range: range)
            }
        }

        if let highlightedCharacter,
           let range = offsets.nsRange(start: highlightedCharacter, end: highlightedCharacter + 1),
           range.length > 0 {
            output.addAttributes([
                .backgroundColor: UIColor.systemIndigo.withAlphaComponent(0.28),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: UIColor.systemIndigo
            ], range: range)
        }
        return output
    }

    private func updateFocusHighlight(in textView: UITextView, source: String, index: Int?, enabled: Bool) {
        guard let index, let range = CharacterUTF16Map(source).nsRange(start: index, end: index + 1), range.length > 0 else { return }
        if enabled {
            textView.textStorage.addAttributes([
                .backgroundColor: UIColor.systemIndigo.withAlphaComponent(0.28),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: UIColor.systemIndigo
            ], range: range)
        } else {
            textView.textStorage.removeAttribute(.backgroundColor, range: range)
            textView.textStorage.removeAttribute(.underlineStyle, range: range)
            textView.textStorage.removeAttribute(.underlineColor, range: range)
        }
    }

    private static var baseAttributes: [NSAttributedString.Key: Any] {
        let baseFont = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        let scaledFont = UIFontMetrics(forTextStyle: .body).scaledFont(for: baseFont)
        return [
            .font: scaledFont,
            .foregroundColor: UIColor.label
        ]
    }

    private static var commentFont: UIFont {
        let baseFont = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular).withTraits(.traitItalic)
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: baseFont)
    }

    private static func color(for type: TokenType) -> UIColor {
        switch type {
        case .keyword: return .systemIndigo
        case .identifier: return .label
        case .integer: return .systemPurple
        case .floatingPoint: return .systemPurple
        case .string: return .systemPink
        case .characterLiteral: return .systemPink
        case .attribute: return .systemOrange
        case .preprocessor: return .systemBrown
        case .operatorSymbol: return .systemOrange
        case .delimiter: return .systemGreen
        case .whitespace: return .secondaryLabel
        case .comment: return .systemTeal
        case .unknown: return .systemRed
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: SourceCodeEditor
        var lastStyledSource = ""
        var lastTokenSignature = ""
        var lastHighlightedCharacter: Int?
        var isApplyingExternalText = false

        init(_ parent: SourceCodeEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingExternalText else { return }
            let newText = textView.text ?? ""
            if parent.text != newText {
                parent.text = newText
            }
        }

        @objc func handleEditorTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended,
                  let textView = gesture.view as? UITextView,
                  !textView.text.isEmpty else { return }

            let tappedPoint = gesture.location(in: textView)
            let pointInTextContainer = CGPoint(
                x: tappedPoint.x - textView.textContainerInset.left + textView.contentOffset.x,
                y: tappedPoint.y - textView.textContainerInset.top + textView.contentOffset.y
            )
            let layoutManager = textView.layoutManager
            let textContainer = textView.textContainer
            var fraction: CGFloat = 0
            let glyphIndex = layoutManager.glyphIndex(
                for: pointInTextContainer,
                in: textContainer,
                fractionOfDistanceThroughGlyph: &fraction
            )
            guard glyphIndex < layoutManager.numberOfGlyphs else { return }

            let utf16Offset = layoutManager.characterIndexForGlyph(at: glyphIndex)
            let mapper = CharacterUTF16Map(textView.text)
            guard let characterIndex = mapper.characterIndex(forUTF16Offset: utf16Offset) else { return }
            parent.onSelectCharacter(characterIndex)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

private struct CharacterUTF16Map {
    private let offsets: [Int]

    init(_ source: String) {
        var result = [0]
        var currentOffset = 0
        for character in source {
            currentOffset += String(character).utf16.count
            result.append(currentOffset)
        }
        offsets = result
    }

    private var characterCount: Int { max(0, offsets.count - 1) }

    func nsRange(start: Int, end: Int) -> NSRange? {
        guard start >= 0, end > start, end <= characterCount,
              offsets.indices.contains(start), offsets.indices.contains(end) else { return nil }
        return NSRange(location: offsets[start], length: offsets[end] - offsets[start])
    }

    func characterIndex(forUTF16Offset offset: Int) -> Int? {
        guard characterCount > 0 else { return nil }
        let clamped = min(max(0, offset), offsets[offsets.count - 1])
        if clamped == offsets[offsets.count - 1] { return characterCount - 1 }

        var low = 0
        var high = characterCount - 1
        while low <= high {
            let middle = (low + high) / 2
            if clamped < offsets[middle] {
                high = middle - 1
            } else if clamped >= offsets[middle + 1] {
                low = middle + 1
            } else {
                return middle
            }
        }
        return nil
    }
}

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
