//
//  BenchmarkEngine.swift
//  LexiDFA
//
//  Created by Amirali Yazdani on 10/13/26.
//

import Foundation

struct ScanWorkItem: Sendable {
    let source: String
    let language: SourceLanguage
}

struct BenchmarkResult: Sendable {
    let sequential: Duration
    let concurrent: Duration
    let speedup: Double
    let inputs: Int
    let rounds: Int
    let tokens: Int
    let totalCharacters: Int
    let workers: Int
    let verified: Bool
}

private struct IndexedScanResult: Sendable {
    let index: Int
    let result: ScanResult
}

/// Baseline implementation: scans independent documents one after another.
enum SequentialBatchScanner {
    static func scan(
        _ items: [ScanWorkItem],
        recordingTrace: Bool = true,
        recordingStatePaths: Bool = true
    ) -> [ScanResult] {
        items.map {
            ScannerEngine().scan(
                $0.source,
                language: $0.language,
                recordingTrace: recordingTrace,
                recordingStatePaths: recordingStatePaths
            )
        }
    }
}

/// Concurrent implementation: runs a bounded number of CPU-heavy workers.
/// Each worker scans a strided set of independent documents sequentially. This
/// avoids creating one task per tiny file while still allowing real multi-core
/// execution when the Swift runtime schedules workers on different cores.
enum ConcurrentBatchScanner {
    static func recommendedWorkerCount(for itemCount: Int) -> Int {
        guard itemCount > 0 else { return 0 }
        return min(itemCount, min(8, max(1, ProcessInfo.processInfo.activeProcessorCount)))
    }

    static func scan(
        _ items: [ScanWorkItem],
        recordingTrace: Bool = true,
        recordingStatePaths: Bool = true
    ) async -> [ScanResult] {
        guard !items.isEmpty else { return [] }
        let workerCount = recommendedWorkerCount(for: items.count)
        var orderedResults = Array<ScanResult?>(repeating: nil, count: items.count)

        await withTaskGroup(of: [IndexedScanResult].self) { group in
            for workerIndex in 0..<workerCount {
                group.addTask {
                    var partial: [IndexedScanResult] = []
                    partial.reserveCapacity((items.count + workerCount - 1) / workerCount)
                    var itemIndex = workerIndex
                    while itemIndex < items.count {
                        let item = items[itemIndex]
                        let result = ScannerEngine().scan(
                            item.source,
                            language: item.language,
                            recordingTrace: recordingTrace,
                            recordingStatePaths: recordingStatePaths
                        )
                        partial.append(IndexedScanResult(index: itemIndex, result: result))
                        itemIndex += workerCount
                    }
                    return partial
                }
            }

            for await partial in group {
                for item in partial {
                    orderedResults[item.index] = item.result
                }
            }
        }

        // Every index is written once. The compactMap preserves ascending slot order.
        return orderedResults.compactMap { $0 }
    }
}

enum BenchmarkEngine {
    static let defaultRounds = 5

    /// Compatibility overload used by simple Swift-only tests and examples.
    static func run(workload: [String], rounds: Int = defaultRounds) async -> BenchmarkResult {
        await run(items: workload.map { ScanWorkItem(source: $0, language: .swift) }, rounds: rounds)
    }

    static func run(items: [ScanWorkItem], rounds: Int = defaultRounds) async -> BenchmarkResult {
        guard !items.isEmpty else {
            return BenchmarkResult(
                sequential: .zero, concurrent: .zero, speedup: 0,
                inputs: 0, rounds: 0, tokens: 0, totalCharacters: 0,
                workers: 0, verified: true
            )
        }

        let measuredRounds = max(3, rounds)
        let workerCount = ConcurrentBatchScanner.recommendedWorkerCount(for: items.count)
        let warmup = Array(items.prefix(min(items.count, workerCount * 2)))

        // Benchmark lexical work, not visualization instrumentation. The visible
        // scanner still records full trace events/state paths; only timed runs omit them.
        _ = SequentialBatchScanner.scan(warmup, recordingTrace: false, recordingStatePaths: false)
        _ = await ConcurrentBatchScanner.scan(warmup, recordingTrace: false, recordingStatePaths: false)

        var sequentialSamples: [Double] = []
        var concurrentSamples: [Double] = []
        var verified = true
        var tokenCount = 0

        for round in 0..<measuredRounds {
            let sequentialMeasurement: ([ScanResult], Double)
            let concurrentMeasurement: ([ScanResult], Double)

            // Alternate order to reduce systematic bias from always running the
            // same strategy first (thermal state, cache and OS scheduling effects).
            if round.isMultiple(of: 2) {
                sequentialMeasurement = measureSequential(items)
                concurrentMeasurement = await measureConcurrent(items)
            } else {
                concurrentMeasurement = await measureConcurrent(items)
                sequentialMeasurement = measureSequential(items)
            }

            sequentialSamples.append(sequentialMeasurement.1)
            concurrentSamples.append(concurrentMeasurement.1)
            verified = verified && resultsMatch(sequentialMeasurement.0, concurrentMeasurement.0)
            if round == 0 {
                tokenCount = sequentialMeasurement.0.reduce(0) {
                    $0 + $1.tokens.filter { $0.type != .whitespace }.count
                }
            }
        }

        let sequentialSeconds = median(sequentialSamples)
        let concurrentSeconds = max(median(concurrentSamples), 0.000001)
        return BenchmarkResult(
            sequential: duration(fromSeconds: sequentialSeconds),
            concurrent: duration(fromSeconds: concurrentSeconds),
            speedup: sequentialSeconds / concurrentSeconds,
            inputs: items.count,
            rounds: measuredRounds,
            tokens: tokenCount,
            totalCharacters: items.reduce(0) { $0 + $1.source.count },
            workers: workerCount,
            verified: verified
        )
    }

    static func durationSeconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    private static func measureSequential(_ items: [ScanWorkItem]) -> ([ScanResult], Double) {
        let start = ContinuousClock.now
        let results = SequentialBatchScanner.scan(items, recordingTrace: false, recordingStatePaths: false)
        return (results, durationSeconds(start.duration(to: .now)))
    }

    private static func measureConcurrent(_ items: [ScanWorkItem]) async -> ([ScanResult], Double) {
        let start = ContinuousClock.now
        let results = await ConcurrentBatchScanner.scan(items, recordingTrace: false, recordingStatePaths: false)
        return (results, durationSeconds(start.duration(to: .now)))
    }

    private static func duration(fromSeconds seconds: Double) -> Duration {
        .nanoseconds(max(1, Int64((seconds * 1_000_000_000).rounded())))
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    private static func resultsMatch(_ lhs: [ScanResult], _ rhs: [ScanResult]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { left, right in
            left.characters == right.characters
                && left.tokens.count == right.tokens.count
                && zip(left.tokens, right.tokens).allSatisfy(tokensMatch)
                && left.events.count == right.events.count
                && zip(left.events, right.events).allSatisfy(eventsMatch)
        }
    }

    private static func tokensMatch(_ left: Token, _ right: Token) -> Bool {
        left.lexeme == right.lexeme && left.type == right.type && left.start == right.start
            && left.end == right.end && left.states == right.states
    }

    private static func eventsMatch(_ left: ScannerEvent, _ right: ScannerEvent) -> Bool {
        left.index == right.index && left.character == right.character && left.state == right.state
            && left.nextState == right.nextState && left.lexeme == right.lexeme
            && left.message == right.message && left.kind == right.kind
    }
}
