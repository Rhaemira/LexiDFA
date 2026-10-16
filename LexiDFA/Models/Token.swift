//
//  Token.swift
//  LexiDFA
//
//  Created by Amirali Yazdani on 10/13/26.
//

import Foundation

enum TokenType: String, CaseIterable, Sendable {
    case keyword = "Keyword"
    case identifier = "Identifier"
    case integer = "Integer"
    case floatingPoint = "Floating-point"
    case string = "String"
    case characterLiteral = "Character literal"
    case attribute = "Attribute"
    case preprocessor = "Directive"
    case operatorSymbol = "Operator"
    case delimiter = "Delimiter"
    case whitespace = "Whitespace"
    case comment = "Comment"
    case unknown = "Unknown"

    var symbol: String {
        switch self {
        case .keyword: return "key"
        case .identifier: return "id"
        case .integer: return "123"
        case .floatingPoint: return "3.14"
        case .string: return "\"A\""
        case .characterLiteral: return "'a'"
        case .attribute: return "@"
        case .preprocessor: return "#"
        case .operatorSymbol: return "op"
        case .delimiter: return "{}"
        case .whitespace: return "·"
        case .comment: return "//"
        case .unknown: return "?"
        }
    }
}

struct Token: Identifiable, Hashable, Sendable {
    let id: UUID
    let lexeme: String
    let type: TokenType
    let start: Int
    let end: Int
    let states: [DFAState]

    init(id: UUID = UUID(), lexeme: String, type: TokenType, start: Int, end: Int, states: [DFAState] = []) {
        self.id = id
        self.lexeme = lexeme
        self.type = type
        self.start = start
        self.end = end
        self.states = states
    }
}
