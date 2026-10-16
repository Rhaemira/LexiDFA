//
//  ScanResult.swift
//  LexiDFA
//
//  Created by Amirali Yazdani on 10/13/26.
//

import Foundation

struct ScannerEvent: Identifiable, Sendable, Hashable {
    enum Kind: Sendable, Hashable {
        case character
        case transition
        case accept
        case error
    }

    let id = UUID()
    let index: Int
    let character: Character?
    let state: DFAState
    let nextState: DFAState?
    let lexeme: String
    let message: String
    let kind: Kind
}

struct ScanResult: Sendable {
    let tokens: [Token]
    let events: [ScannerEvent]
    let characters: Int
    let duration: Duration

    static let empty = ScanResult(tokens: [], events: [], characters: 0, duration: .zero)
}


extension ScanResult {
    /// Finds the trace event that best explains a source character. Exact recorded
    /// character events win; characters without their own event (such as interior
    /// whitespace) map to the nearest event within their token, then globally.
    func eventIndex(forSourceIndex sourceIndex: Int) -> Int? {
        guard !events.isEmpty else { return nil }

        if let exact = events.indices.first(where: {
            events[$0].index == sourceIndex && events[$0].character != nil
        }) {
            return exact
        }

        if let token = tokens.first(where: { $0.start <= sourceIndex && sourceIndex < $0.end }) {
            let withinToken = events.indices.filter {
                events[$0].index >= token.start && events[$0].index < token.end
            }
            if let nearest = withinToken.min(by: {
                abs(events[$0].index - sourceIndex) < abs(events[$1].index - sourceIndex)
            }) {
                return nearest
            }
        }

        return events.indices.min {
            abs(events[$0].index - sourceIndex) < abs(events[$1].index - sourceIndex)
        }
    }
}
