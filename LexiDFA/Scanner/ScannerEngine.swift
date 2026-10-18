//
//  ScannerEngine.swift
//  LexiDFA
//
//  Created by Amirali Yazdani on 10/13/26.
//

import Foundation

/// Source dialect supported by the teaching scanner.
enum SourceLanguage: String, CaseIterable, Identifiable, Sendable {
    case swift = "Swift"
    case cpp = "C++"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .swift: return "Swift lexical rules"
        case .cpp: return "C++ lexical rules"
        }
    }

    var keywords: Set<String> {
        switch self {
        case .swift: return Self.swiftKeywords
        case .cpp: return Self.cppKeywords
        }
    }

    // Built once; `finishToken` checks these for every identifier.
    private static let swiftKeywords: Set<String> = [
        "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func",
        "import", "init", "inout", "internal", "let", "open", "operator", "private",
        "protocol", "public", "rethrows", "static", "struct", "subscript", "typealias",
        "var", "break", "case", "continue", "default", "defer", "do", "else", "fallthrough",
        "for", "guard", "if", "in", "repeat", "return", "switch", "where", "while",
        "as", "Any", "catch", "false", "is", "nil", "super", "self", "Self", "throw",
        "throws", "true", "try", "async", "await", "actor", "some", "any", "yield",
        "mutating", "nonmutating", "consuming", "borrowing", "package", "precedencegroup"
    ]

    private static let cppKeywords: Set<String> = [
        "alignas", "alignof", "and", "and_eq", "asm", "auto", "bitand", "bitor", "bool",
        "break", "case", "catch", "char", "char8_t", "char16_t", "char32_t", "class", "compl",
        "concept", "const", "consteval", "constexpr", "constinit", "const_cast", "continue",
        "co_await", "co_return", "co_yield", "decltype", "default", "delete", "do", "double",
        "dynamic_cast", "else", "enum", "explicit", "export", "extern", "false", "float", "for",
        "friend", "goto", "if", "inline", "int", "long", "mutable", "namespace", "new", "noexcept",
        "not", "not_eq", "nullptr", "operator", "or", "or_eq", "private", "protected", "public",
        "register", "reinterpret_cast", "requires", "return", "short", "signed", "sizeof", "static",
        "static_assert", "static_cast", "struct", "switch", "template", "this", "thread_local",
        "throw", "true", "try", "typedef", "typeid", "typename", "union", "unsigned", "using",
        "virtual", "void", "volatile", "wchar_t", "while", "xor", "xor_eq"
    ]
}

/// Explicit DFA + switch-case scanner. This is a teaching lexer, not a complete
/// replacement for either language's compiler frontend.
struct ScannerEngine: Sendable {
    private let operatorSpellings: [String] = [
        "<<=", ">>=", "->*", "...", "..<", "==", "!=", "<=", ">=", "&&", "||",
        "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "++", "--", "<<", ">>",
        "->", "??", "?.", "!.", "::", ".*", "=", "+", "-", "*", "/", "%",
        "!", "<", ">", "&", "|", "^", "~", "?"
    ]

    private let delimiters: Set<Character> = [
        "(", ")", "{", "}", "[", "]", ";", ",", ":", "."
    ]

    func scan(
        _ source: String,
        language: SourceLanguage = .swift,
        recordingTrace: Bool = true,
        recordingStatePaths: Bool = true
    ) -> ScanResult {
        let clock = ContinuousClock()
        let started = clock.now
        let chars = Array(source)
        var index = 0
        var state: DFAState = .start
        var tokenStart = 0
        var lexeme = ""
        var tokenStates: [DFAState] = recordingStatePaths ? [.start] : []
        var tokens: [Token] = []
        var events: [ScannerEvent] = []

        func appendState(_ nextState: DFAState) {
            guard recordingStatePaths else { return }
            tokenStates.append(nextState)
        }

        func appendEvent(
            index: Int,
            character: Character?,
            state: DFAState,
            next: DFAState?,
            message: String,
            kind: ScannerEvent.Kind
        ) {
            guard recordingTrace else { return }
            events.append(ScannerEvent(
                index: index,
                character: character,
                state: state,
                nextState: next,
                lexeme: lexeme,
                message: message,
                kind: kind
            ))
        }

        func resetToken() {
            lexeme = ""
            tokenStates = recordingStatePaths ? [.start] : []
            state = .start
        }

        func finishToken(type: TokenType, end: Int) {
            guard !lexeme.isEmpty else { return }
            let actualType: TokenType
            if type == .identifier && language.keywords.contains(lexeme) {
                actualType = .keyword
            } else if type == .integer && (lexeme.contains(".") || lexeme.contains("e") || lexeme.contains("E")) {
                actualType = .floatingPoint
            } else {
                actualType = type
            }

            tokens.append(Token(lexeme: lexeme, type: actualType, start: tokenStart, end: end, states: tokenStates))
            appendEvent(
                index: max(tokenStart, end - 1), character: nil, state: state, next: nil,
                message: "Accepted \(actualType.rawValue.lowercased()) token", kind: .accept
            )
            resetToken()
        }

        func failToken(message: String, end: Int, eventIndex: Int, eventState: DFAState) {
            guard !lexeme.isEmpty else { return }
            if recordingStatePaths && !tokenStates.contains(.error) { appendState(.error) }
            tokens.append(Token(lexeme: lexeme, type: .unknown, start: tokenStart, end: end, states: tokenStates))
            appendEvent(
                index: max(0, eventIndex), character: nil, state: eventState, next: .error,
                message: message, kind: .error
            )
            resetToken()
        }

        while index < chars.count {
            let ch = chars[index]

            // The outer switch is the visible state machine required by the assignment.
            switch state {
            case .start:
                if ch.isWhitespace {
                    let start = index
                    var whitespace = ""
                    while index < chars.count, chars[index].isWhitespace {
                        whitespace.append(chars[index])
                        index += 1
                    }
                    tokens.append(Token(lexeme: whitespace, type: .whitespace, start: start, end: index, states: recordingStatePaths ? [.start] : []))
                    appendEvent(index: start, character: ch, state: .start, next: .start, message: "Skip whitespace", kind: .transition)
                    continue
                }

                tokenStart = index
                lexeme = ""
                tokenStates = recordingStatePaths ? [.start] : []

                switch ch {
                case "a"..."z", "A"..."Z", "_":
                    state = .identifier
                    lexeme.append(ch)
                    appendState(.identifier)
                    appendEvent(index: index, character: ch, state: .start, next: .identifier, message: "LETTER / _ → identifier", kind: .transition)
                    index += 1

                case "0"..."9":
                    state = .number
                    lexeme.append(ch)
                    appendState(.number)
                    appendEvent(index: index, character: ch, state: .start, next: .number, message: "DIGIT → number", kind: .transition)
                    index += 1

                case "\"":
                    state = .string
                    lexeme.append(ch)
                    appendState(.string)
                    appendEvent(index: index, character: ch, state: .start, next: .string, message: "Opening quote → string", kind: .transition)
                    index += 1

                case "'":
                    state = .characterLiteral
                    lexeme.append(ch)
                    appendState(.characterLiteral)
                    appendEvent(index: index, character: ch, state: .start, next: .characterLiteral, message: "Opening apostrophe → character literal", kind: .transition)
                    index += 1

                case "/":
                    if index + 1 < chars.count, chars[index + 1] == "/" {
                        state = .comment
                        lexeme = "//"
                        appendState(.comment)
                        appendEvent(index: index, character: ch, state: .start, next: .comment, message: "// → line comment", kind: .transition)
                        index += 2
                        while index < chars.count, !chars[index].isNewline {
                            let commentChar = chars[index]
                            lexeme.append(commentChar)
                            appendEvent(index: index, character: commentChar, state: .comment, next: .comment, message: "Consume comment character", kind: .transition)
                            index += 1
                        }
                        finishToken(type: .comment, end: index)
                    } else if index + 1 < chars.count, chars[index + 1] == "*" {
                        state = .blockComment
                        lexeme = "/*"
                        appendState(.blockComment)
                        appendEvent(index: index, character: ch, state: .start, next: .blockComment, message: "/* → block comment", kind: .transition)
                        index += 2
                        var depth = 1
                        var closed = false
                        while index < chars.count {
                            if index + 1 < chars.count, chars[index] == "/", chars[index + 1] == "*", language == .swift {
                                lexeme.append("/*")
                                appendEvent(index: index, character: "/", state: .blockComment, next: .blockComment, message: "Nested block comment", kind: .transition)
                                depth += 1
                                index += 2
                            } else if index + 1 < chars.count, chars[index] == "*", chars[index + 1] == "/" {
                                lexeme.append("*/")
                                appendEvent(index: index, character: "*", state: .blockComment, next: .blockComment, message: "Consume block-comment terminator", kind: .transition)
                                depth -= 1
                                index += 2
                                if depth == 0 { closed = true; break }
                            } else {
                                let commentChar = chars[index]
                                lexeme.append(commentChar)
                                appendEvent(index: index, character: commentChar, state: .blockComment, next: .blockComment, message: "Consume block-comment character", kind: .transition)
                                index += 1
                            }
                        }
                        if closed {
                            finishToken(type: .comment, end: index)
                        } else {
                            failToken(message: "Unterminated block comment", end: index, eventIndex: max(0, index - 1), eventState: .blockComment)
                        }
                    } else if let operatorText = longestOperator(in: chars, at: index, language: language) {
                        state = .operatorState
                        lexeme = operatorText
                        tokenStates = recordingStatePaths ? ([.start] + Array(repeating: .operatorState, count: operatorText.count)) : []
                        for offset in 0..<operatorText.count {
                            appendEvent(
                                index: index + offset,
                                character: chars[index + offset],
                                state: offset == 0 ? .start : .operatorState,
                                next: .operatorState,
                                message: offset == 0 ? "Enter operator state" : "Longest-match operator continuation",
                                kind: .transition
                            )
                        }
                        index += operatorText.count
                        finishToken(type: .operatorSymbol, end: index)
                    } else {
                        state = .error
                        lexeme.append(ch)
                        appendState(.error)
                        appendEvent(index: index, character: ch, state: .start, next: .error, message: "Unknown symbol", kind: .error)
                        tokens.append(Token(lexeme: lexeme, type: .unknown, start: index, end: index + 1, states: tokenStates))
                        resetToken()
                        index += 1
                    }

                case "#":
                    if isDirectivePosition(chars, at: index) {
                        state = .preprocessor
                        lexeme.append(ch)
                        appendState(.preprocessor)
                        appendEvent(index: index, character: ch, state: .start, next: .preprocessor, message: "# at line start → directive", kind: .transition)
                        index += 1
                        while index < chars.count, !chars[index].isNewline {
                            let directiveChar = chars[index]
                            lexeme.append(directiveChar)
                            appendEvent(index: index, character: directiveChar, state: .preprocessor, next: .preprocessor, message: "Consume directive", kind: .transition)
                            index += 1
                        }
                        finishToken(type: .preprocessor, end: index)
                    } else {
                        state = .error
                        lexeme.append(ch)
                        appendState(.error)
                        appendEvent(index: index, character: ch, state: .start, next: .error, message: "Unknown symbol", kind: .error)
                        tokens.append(Token(lexeme: lexeme, type: .unknown, start: index, end: index + 1, states: tokenStates))
                        resetToken()
                        index += 1
                    }

                case "@":
                    if language == .swift, index + 1 < chars.count, isIdentifierStart(chars[index + 1]) {
                        state = .attribute
                        lexeme.append(ch)
                        appendState(.attribute)
                        appendEvent(index: index, character: ch, state: .start, next: .attribute, message: "Swift attribute", kind: .transition)
                        index += 1
                        while index < chars.count, isIdentifierContinue(chars[index]) {
                            let attributeChar = chars[index]
                            lexeme.append(attributeChar)
                            appendEvent(index: index, character: attributeChar, state: .attribute, next: .attribute, message: "Consume attribute name", kind: .transition)
                            index += 1
                        }
                        finishToken(type: .attribute, end: index)
                    } else {
                        state = .error
                        lexeme.append(ch)
                        appendState(.error)
                        appendEvent(index: index, character: ch, state: .start, next: .error, message: "Unknown symbol", kind: .error)
                        tokens.append(Token(lexeme: lexeme, type: .unknown, start: index, end: index + 1, states: tokenStates))
                        resetToken()
                        index += 1
                    }

                default:
                    if let operatorText = longestOperator(in: chars, at: index, language: language) {
                        state = .operatorState
                        lexeme = operatorText
                        tokenStates = recordingStatePaths ? ([.start] + Array(repeating: .operatorState, count: operatorText.count)) : []
                        for offset in 0..<operatorText.count {
                            appendEvent(
                                index: index + offset,
                                character: chars[index + offset],
                                state: offset == 0 ? .start : .operatorState,
                                next: .operatorState,
                                message: offset == 0 ? "Enter operator state" : "Longest-match operator continuation",
                                kind: .transition
                            )
                        }
                        index += operatorText.count
                        finishToken(type: .operatorSymbol, end: index)
                    } else if delimiters.contains(ch) {
                        state = .delimiter
                        lexeme.append(ch)
                        appendState(.delimiter)
                        appendEvent(index: index, character: ch, state: .start, next: .delimiter, message: "Punctuation → delimiter", kind: .transition)
                        finishToken(type: .delimiter, end: index + 1)
                        index += 1
                    } else {
                        state = .error
                        lexeme.append(ch)
                        appendState(.error)
                        appendEvent(index: index, character: ch, state: .start, next: .error, message: "Unknown symbol", kind: .error)
                        tokens.append(Token(lexeme: lexeme, type: .unknown, start: index, end: index + 1, states: tokenStates))
                        resetToken()
                        index += 1
                    }
                }

            case .identifier:
                if isIdentifierContinue(ch) {
                    lexeme.append(ch)
                    appendState(.identifier)
                    appendEvent(index: index, character: ch, state: .identifier, next: .identifier, message: "Continue identifier", kind: .transition)
                    index += 1
                } else {
                    finishToken(type: .identifier, end: index)
                }

            case .number:
                if shouldContinueNumber(lexeme: lexeme, chars: chars, index: index) {
                    lexeme.append(ch)
                    appendState(.number)
                    appendEvent(index: index, character: ch, state: .number, next: .number, message: "Continue numeric literal", kind: .transition)
                    index += 1
                } else {
                    finishToken(type: .integer, end: index)
                }

            case .string:
                if ch == "\"" {
                    lexeme.append(ch)
                    appendState(.string)
                    appendEvent(index: index, character: ch, state: .string, next: nil, message: "Closing quote → accept", kind: .accept)
                    index += 1
                    finishToken(type: .string, end: index)
                } else if ch == "\\" {
                    if index + 1 < chars.count, !chars[index + 1].isNewline {
                        lexeme.append(chars[index])
                        lexeme.append(chars[index + 1])
                        appendState(.string)
                        appendEvent(index: index + 1, character: chars[index + 1], state: .string, next: .string, message: "Escape sequence", kind: .transition)
                        index += 2
                    } else {
                        lexeme.append(ch)
                        index += 1
                        failToken(message: "Dangling escape in string", end: index, eventIndex: index - 1, eventState: .string)
                    }
                } else if ch.isNewline {
                    failToken(message: "Unterminated string", end: index, eventIndex: max(0, index - 1), eventState: .string)
                } else {
                    lexeme.append(ch)
                    appendState(.string)
                    appendEvent(index: index, character: ch, state: .string, next: .string, message: "Consume string character", kind: .transition)
                    index += 1
                }

            case .characterLiteral:
                if ch == "'" {
                    lexeme.append(ch)
                    appendState(.characterLiteral)
                    appendEvent(index: index, character: ch, state: .characterLiteral, next: nil, message: "Closing apostrophe → accept", kind: .accept)
                    index += 1
                    finishToken(type: .characterLiteral, end: index)
                } else if ch == "\\" {
                    if index + 1 < chars.count, !chars[index + 1].isNewline {
                        lexeme.append(ch)
                        lexeme.append(chars[index + 1])
                        appendState(.characterLiteral)
                        appendEvent(index: index + 1, character: chars[index + 1], state: .characterLiteral, next: .characterLiteral, message: "Character escape", kind: .transition)
                        index += 2
                    } else {
                        lexeme.append(ch)
                        index += 1
                        failToken(message: "Dangling escape in character literal", end: index, eventIndex: index - 1, eventState: .characterLiteral)
                    }
                } else if ch.isNewline {
                    failToken(message: "Unterminated character literal", end: index, eventIndex: max(0, index - 1), eventState: .characterLiteral)
                } else {
                    lexeme.append(ch)
                    appendState(.characterLiteral)
                    appendEvent(index: index, character: ch, state: .characterLiteral, next: .characterLiteral, message: "Consume character literal", kind: .transition)
                    index += 1
                }

            case .operatorState, .delimiter, .comment, .blockComment, .preprocessor, .attribute, .error:
                // These states consume their recognized unit in the .start transition above.
                resetToken()
            }
        }

        switch state {
        case .identifier:
            finishToken(type: .identifier, end: index)
        case .number:
            finishToken(type: .integer, end: index)
        case .string:
            failToken(message: "Unterminated string", end: index, eventIndex: max(0, index - 1), eventState: .string)
        case .characterLiteral:
            failToken(message: "Unterminated character literal", end: index, eventIndex: max(0, index - 1), eventState: .characterLiteral)
        default:
            break
        }

        return ScanResult(
            tokens: tokens,
            events: events,
            characters: chars.count,
            duration: started.duration(to: clock.now)
        )
    }

    private func longestOperator(in chars: [Character], at index: Int, language: SourceLanguage) -> String? {
        // `operatorSpellings` is ordered longest-first. Return immediately on a
        // match instead of filtering every spelling and allocating temporary arrays.
        for spelling in operatorSpellings {
            if language == .swift && (spelling == "::" || spelling == ".*" || spelling == "->*" || spelling == "=>") { continue }
            if language == .cpp && (spelling == "??" || spelling == "?." || spelling == "!." || spelling == "..<") { continue }
            guard index + spelling.count <= chars.count else { continue }

            var matches = true
            for (offset, expected) in spelling.enumerated() {
                if chars[index + offset] != expected {
                    matches = false
                    break
                }
            }
            if matches { return spelling }
        }
        return nil
    }

    private func isDirectivePosition(_ chars: [Character], at index: Int) -> Bool {
        guard index > 0 else { return true }
        var cursor = index - 1
        while cursor >= 0 {
            if chars[cursor].isNewline { return true }
            if !chars[cursor].isWhitespace { return false }
            if cursor == 0 { return true }
            cursor -= 1
        }
        return true
    }

    private func isIdentifierStart(_ character: Character) -> Bool {
        character == "_" || character.isLetter
    }

    private func isIdentifierContinue(_ character: Character) -> Bool {
        character == "_" || character.isLetter || character.isNumber
    }

    private func shouldContinueNumber(lexeme: String, chars: [Character], index: Int) -> Bool {
        let ch = chars[index]
        if ch.isNumber || ch == "_" { return true }
        let hasExponent = lexeme.contains("e") || lexeme.contains("E")
        let hasDot = lexeme.contains(".")
        if ch == ".", !hasDot, !hasExponent, index + 1 < chars.count, chars[index + 1].isNumber {
            return true
        }
        if ch == "e" || ch == "E" {
            guard !hasExponent, index + 1 < chars.count else { return false }
            if chars[index + 1].isNumber { return true }
            return index + 2 < chars.count && (chars[index + 1] == "+" || chars[index + 1] == "-") && chars[index + 2].isNumber
        }
        if (ch == "+" || ch == "-"), let last = lexeme.last, (last == "e" || last == "E") {
            return index + 1 < chars.count && chars[index + 1].isNumber
        }
        return false
    }
}
