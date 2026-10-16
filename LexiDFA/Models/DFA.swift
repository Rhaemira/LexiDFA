//
//  DFA.swift
//  LexiDFA
//
//  Created by Amirali Yazdani on 10/13/26.
//

import Foundation

/// States in the shared visualization model. Some transitions are dialect-specific
/// (for example Swift attributes and C++ scope resolution / preprocessor directives).
enum DFAState: String, CaseIterable, Identifiable, Sendable, Hashable {
    case start = "q0"
    case identifier = "q1"
    case number = "q2"
    case string = "q3"
    case operatorState = "q4"
    case delimiter = "q5"
    case comment = "q6"
    case characterLiteral = "q7"
    case blockComment = "q8"
    case preprocessor = "q9"
    case attribute = "qA"
    case error = "qX"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .start: return "START"
        case .identifier: return "IDENTIFIER"
        case .number: return "NUMBER"
        case .string: return "STRING"
        case .operatorState: return "OPERATOR"
        case .delimiter: return "DELIMITER"
        case .comment: return "LINE COMMENT"
        case .characterLiteral: return "CHARACTER"
        case .blockComment: return "BLOCK COMMENT"
        case .preprocessor: return "DIRECTIVE"
        case .attribute: return "ATTRIBUTE"
        case .error: return "ERROR"
        }
    }

    var accepting: Bool {
        switch self {
        case .identifier, .number, .string, .operatorState, .delimiter,
             .comment, .characterLiteral, .blockComment, .preprocessor, .attribute:
            return true
        case .start, .error:
            return false
        }
    }
}

struct DFATransition: Identifiable, Hashable, Sendable {
    let id = UUID()
    let from: DFAState
    let to: DFAState
    let label: String
}

extension DFAState {
    /// This table is the visual reference for the switch-case scanner. Token
    /// boundaries use maximal munch/lookahead, then return to q0 for the next token.
    static let transitions: [DFATransition] = [
        DFATransition(from: .start, to: .identifier, label: "letter / _"),
        DFATransition(from: .start, to: .number, label: "digit"),
        DFATransition(from: .start, to: .string, label: "double quote"),
        DFATransition(from: .start, to: .characterLiteral, label: "apostrophe"),
        DFATransition(from: .start, to: .operatorState, label: "operator char"),
        DFATransition(from: .start, to: .delimiter, label: "punctuation"),
        DFATransition(from: .start, to: .comment, label: "//"),
        DFATransition(from: .start, to: .blockComment, label: "/*"),
        DFATransition(from: .start, to: .preprocessor, label: "# at line start"),
        DFATransition(from: .start, to: .attribute, label: "@name (Swift)"),
        DFATransition(from: .start, to: .error, label: "unknown char"),

        DFATransition(from: .identifier, to: .identifier, label: "letter / digit / _"),
        DFATransition(from: .number, to: .number, label: "digit / decimal / exponent"),
        DFATransition(from: .string, to: .string, label: "character / escape / quote"),
        DFATransition(from: .characterLiteral, to: .characterLiteral, label: "character / escape / apostrophe"),
        DFATransition(from: .operatorState, to: .operatorState, label: "longest operator match"),
        DFATransition(from: .comment, to: .comment, label: "until newline"),
        DFATransition(from: .blockComment, to: .blockComment, label: "until */ (nested in Swift)"),
        DFATransition(from: .preprocessor, to: .preprocessor, label: "until newline"),
        DFATransition(from: .attribute, to: .attribute, label: "attribute name")
    ]
}
