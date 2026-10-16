//
//  BenchmarkEngineTests.swift
//  LexiDFA
//
//  Created by Amirali Yazdani on 10/13/26.
//

import XCTest
@testable import LexiDFACore

final class BenchmarkEngineTests: XCTestCase {
    func testBenchmarkVerifiesIdenticalSequentialAndConcurrentResults() async {
        let workload = [
            "let count = 42;",
            "if value >= 10 && value != 12 { value += 1; }",
            #"let greeting = "hello"; // comment"#,
            "let invalid = @;"
        ]

        let result = await BenchmarkEngine.run(workload: workload, rounds: 3)

        XCTAssertTrue(result.verified)
        XCTAssertEqual(result.inputs, workload.count)
        XCTAssertGreaterThanOrEqual(result.rounds, 3)
        XCTAssertGreaterThan(result.tokens, 0)
        XCTAssertGreaterThan(result.totalCharacters, 0)
        XCTAssertGreaterThan(result.workers, 0)
        XCTAssertGreaterThan(BenchmarkEngine.durationSeconds(result.sequential), 0)
        XCTAssertGreaterThan(BenchmarkEngine.durationSeconds(result.concurrent), 0)
        XCTAssertTrue(result.speedup.isFinite)
        XCTAssertGreaterThan(result.speedup, 0)
    }

    func testExplicitConcurrentBatchScannerMatchesAcrossLanguages() async {
        let items = [
            ScanWorkItem(source: "let value = 3.14", language: .swift),
            ScanWorkItem(source: "int main() { return 0; }", language: .cpp),
            ScanWorkItem(source: "@MainActor let title = \"Lexi\"", language: .swift)
        ]
        let sequential = SequentialBatchScanner.scan(items)
        let concurrent = await ConcurrentBatchScanner.scan(items)
        XCTAssertEqual(sequential.count, concurrent.count)
        XCTAssertEqual(sequential.map { $0.tokens.map(\.lexeme) }, concurrent.map { $0.tokens.map(\.lexeme) })
        let benchmark = await BenchmarkEngine.run(items: items, rounds: 3)
        XCTAssertTrue(benchmark.verified)
    }

    func testEmptyWorkloadIsHandledSafely() async {
        let result = await BenchmarkEngine.run(workload: [])

        XCTAssertTrue(result.verified)
        XCTAssertEqual(result.inputs, 0)
        XCTAssertEqual(result.rounds, 0)
        XCTAssertEqual(result.tokens, 0)
        XCTAssertEqual(result.totalCharacters, 0)
        XCTAssertEqual(result.workers, 0)
        XCTAssertEqual(BenchmarkEngine.durationSeconds(result.sequential), 0)
        XCTAssertEqual(BenchmarkEngine.durationSeconds(result.concurrent), 0)
    }
}
