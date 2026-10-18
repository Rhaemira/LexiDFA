//
//  ScannerEngineTests.swift
//  LexiDFA
//
//  Created by Amirali Yazdani on 10/13/26.
//

import XCTest
@testable import LexiDFACore

final class ScannerEngineTests: XCTestCase {
    private let scanner = ScannerEngine()

    private func significantTokens(_ source: String) -> [Token] {
        scanner.scan(source).tokens.filter { $0.type != .whitespace }
    }

    func testRecognizesKeywordsIdentifiersIntegersAndDelimiters() {
        let tokens = significantTokens("let total = 42;")

        XCTAssertEqual(tokens.map(\.lexeme), ["let", "total", "=", "42", ";"])
        XCTAssertEqual(tokens.map(\.type), [.keyword, .identifier, .operatorSymbol, .integer, .delimiter])
    }

    func testRecognizesSupportedCompoundOperatorsAsSingleTokens() {
        let operators = ["==", "!=", "<=", ">=", "&&", "||", "+=", "-=", "*=", "/=", "%="]
        let source = operators.joined(separator: " ")
        let tokens = significantTokens(source)

        XCTAssertEqual(tokens.map(\.lexeme), operators)
        XCTAssertTrue(tokens.allSatisfy { $0.type == .operatorSymbol })
    }

    func testSeparatesAdjacentOperatorsUsingMaximalMunch() {
        let tokens = significantTokens("a!==b")

        XCTAssertEqual(tokens.map(\.lexeme), ["a", "!=", "=", "b"])
        XCTAssertEqual(tokens.map(\.type), [.identifier, .operatorSymbol, .operatorSymbol, .identifier])
    }

    func testRecognizesLineCommentsAndContinuesAfterNewline() {
        let result = scanner.scan("// note\nlet value = 7")
        let tokens = result.tokens.filter { $0.type != .whitespace }

        XCTAssertEqual(tokens.map(\.lexeme), ["// note", "let", "value", "=", "7"])
        XCTAssertEqual(tokens.first?.type, .comment)
        XCTAssertEqual(tokens[1].type, .keyword)
    }

    func testCRLFLineEndingsTerminateLineComments() {
        // "\r\n" is a single Character in Swift, so it must not be compared against "\n".
        let tokens = significantTokens("// note\r\nlet value = 7")

        XCTAssertEqual(tokens.map(\.lexeme), ["// note", "let", "value", "=", "7"])
        XCTAssertEqual(tokens.first?.type, .comment)
    }

    func testCRLFLineEndingsTerminateDirectivesAndAllowDirectiveOnNextLine() {
        let source = "#include <string>\r\nint x;\r\n#define LIMIT 10\r\nint y;"
        let tokens = scanner.scan(source, language: .cpp).tokens.filter { $0.type != .whitespace }

        XCTAssertEqual(tokens.filter { $0.type == .preprocessor }.map(\.lexeme), ["#include <string>", "#define LIMIT 10"])
        XCTAssertTrue(tokens.contains { $0.lexeme == "y" && $0.type == .identifier })
        XCTAssertFalse(tokens.contains { $0.type == .unknown })
    }

    func testCRLFLineEndingsTerminateUnfinishedStringsAndCharacterLiterals() {
        let stringResult = scanner.scan("let s = \"open\r\nlet t = 1")
        XCTAssertTrue(stringResult.tokens.contains { $0.type == .unknown && $0.lexeme == "\"open" })
        XCTAssertTrue(stringResult.tokens.contains { $0.lexeme == "t" && $0.type == .identifier })

        let charResult = scanner.scan("char c = 'x\r\nint d;", language: .cpp)
        XCTAssertTrue(charResult.tokens.contains { $0.type == .unknown && $0.lexeme == "'x" })
        XCTAssertTrue(charResult.tokens.contains { $0.lexeme == "d" && $0.type == .identifier })
    }

    func testRecognizesQuotedStringsAndEscapedQuotes() {
        let result = scanner.scan(#"let message = "say \"hi\"";"#)
        let stringToken = tryUnwrap(result.tokens.first { $0.type == .string })

        XCTAssertEqual(stringToken.lexeme, #""say \"hi\"""#)
        XCTAssertFalse(result.events.contains { $0.kind == .error })
    }

    func testUnterminatedStringProducesUnknownTokenAndErrorEvent() {
        let result = scanner.scan(#"let message = "unfinished"#)

        XCTAssertTrue(result.tokens.contains { $0.type == .unknown && $0.lexeme.hasPrefix("\"") })
        XCTAssertTrue(result.events.contains { $0.kind == .error && $0.message.contains("Unterminated string") })
    }

    func testUnknownSymbolsAreReportedWithoutDiscardingFollowingInput() {
        let result = scanner.scan("let value = 12 @ 4;")
        let tokens = result.tokens.filter { $0.type != .whitespace }

        XCTAssertTrue(tokens.contains { $0.lexeme == "@" && $0.type == .unknown })
        XCTAssertTrue(tokens.contains { $0.lexeme == "4" && $0.type == .integer })
        XCTAssertTrue(result.events.contains { $0.kind == .error && $0.message == "Unknown symbol" })
    }

    func testSourceRangesAreHalfOpenCharacterOffsets() {
        let tokens = significantTokens("let x = 12;")

        XCTAssertEqual(tokens.map { ($0.start, $0.end) }.map { "\($0.0):\($0.1)" }, ["0:3", "4:5", "6:7", "8:10", "10:11"])
    }

    func testEmptySourceReturnsNoTokensAndNoEvents() {
        let result = scanner.scan("")

        XCTAssertTrue(result.tokens.isEmpty)
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertEqual(result.characters, 0)
    }

    func testScannerEmitsTraceEventsAndStatePaths() {
        let result = scanner.scan("name = 12")
        let identifier = tryUnwrap(result.tokens.first { $0.lexeme == "name" })

        XCTAssertEqual(identifier.states.first, .start)
        XCTAssertTrue(identifier.states.contains(.identifier))
        XCTAssertFalse(result.events.isEmpty)
        XCTAssertTrue(result.events.contains { $0.kind == .accept })
    }

    func testBenchmarkScanModeSkipsVisualizationDataButPreservesTokens() {
        let source = #"let answer = 42 >= 40 && "ok\n" != "no""#
        let full = scanner.scan(source)
        let benchmark = scanner.scan(source, recordingTrace: false, recordingStatePaths: false)

        XCTAssertEqual(full.tokens.map(\.lexeme), benchmark.tokens.map(\.lexeme))
        XCTAssertEqual(full.tokens.map(\.type), benchmark.tokens.map(\.type))
        XCTAssertEqual(full.tokens.map { "\($0.start):\($0.end)" }, benchmark.tokens.map { "\($0.start):\($0.end)" })
        XCTAssertFalse(full.events.isEmpty)
        XCTAssertTrue(benchmark.events.isEmpty)
        XCTAssertTrue(benchmark.tokens.allSatisfy { $0.states.isEmpty })
    }


    func testCPlusPlusKeywordsScopeOperatorCharacterLiteralAndDirective() {
        let source = "#include <iostream>\nint main() { char marker = '!'; std::cout << marker; }"
        let result = scanner.scan(source, language: .cpp)
        let tokens = result.tokens.filter { $0.type != .whitespace }

        XCTAssertTrue(tokens.contains { $0.type == .preprocessor && $0.lexeme == "#include <iostream>" })
        XCTAssertTrue(tokens.contains { $0.lexeme == "int" && $0.type == .keyword })
        XCTAssertTrue(tokens.contains { $0.lexeme == "::" && $0.type == .operatorSymbol })
        XCTAssertTrue(tokens.contains { $0.lexeme == "<<" && $0.type == .operatorSymbol })
        XCTAssertTrue(tokens.contains { $0.lexeme == "'!'" && $0.type == .characterLiteral })
        XCTAssertFalse(tokens.contains { $0.type == .unknown })
    }

    func testSwiftAttributesFloatingPointAndNestedBlockComments() {
        let source = "@MainActor\nlet ratio = 12.5e-2 /* outer /* inner */ done */"
        let result = scanner.scan(source, language: .swift)
        let tokens = result.tokens.filter { $0.type != .whitespace }

        XCTAssertTrue(tokens.contains { $0.lexeme == "@MainActor" && $0.type == .attribute })
        XCTAssertTrue(tokens.contains { $0.lexeme == "12.5e-2" && $0.type == .floatingPoint })
        XCTAssertTrue(tokens.contains { $0.lexeme.contains("outer /* inner */") && $0.type == .comment })
        XCTAssertFalse(tokens.contains { $0.type == .unknown })
    }

    func testCppBlockCommentDoesNotTreatNestedOpeningAsNesting() {
        let result = scanner.scan("/* outer /* text */ int value;", language: .cpp)
        XCTAssertTrue(result.tokens.contains { $0.type == .comment && $0.lexeme == "/* outer /* text */" })
        XCTAssertTrue(result.tokens.contains { $0.lexeme == "int" && $0.type == .keyword })
    }

    private func tryUnwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) -> T {
        guard let value else {
            XCTFail("Expected a value", file: file, line: line)
            fatalError("Expected a value")
        }
        return value
    }

    func testSourceIndexMapsToRelevantTraceEvent() {
        let source = "let value = 42;"
        let result = ScannerEngine().scan(source, language: .swift)
        let valueIndex = Array(source).firstIndex(of: "v")!
        let eventIndex = result.eventIndex(forSourceIndex: valueIndex)
        XCTAssertNotNil(eventIndex)
        XCTAssertEqual(result.events[eventIndex!].index, valueIndex)
        XCTAssertEqual(result.events[eventIndex!].character, "v")

        let spaceIndex = Array(source).firstIndex(of: " ")!
        XCTAssertNotNil(result.eventIndex(forSourceIndex: spaceIndex))

        let coalescedWhitespace = "let     value = 1"
        let whitespaceResult = ScannerEngine().scan(coalescedWhitespace, language: .swift)
        for index in Array(coalescedWhitespace).indices {
            XCTAssertNotNil(whitespaceResult.eventIndex(forSourceIndex: index), "Expected an event mapping for source offset \(index)")
        }
        XCTAssertNil(ScanResult.empty.eventIndex(forSourceIndex: 0))
    }
}
