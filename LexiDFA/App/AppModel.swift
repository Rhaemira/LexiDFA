//
//  AppModel.swift
//  LexiDFA
//
//  Created by Amirali Yazdani on 10/13/26.
//

import Foundation
import SwiftUI

/// High-frequency editor changes are isolated so typing does not invalidate every tab.
@MainActor
final class SourceEditorModel: ObservableObject {
    @Published var sourceCode: String = SampleProgram.basic.source(for: .swift)
}

/// Trace playback state is isolated from app-wide state. Cursor ticks update only
/// the screens that actually depend on the trace, not the entire tab hierarchy.
@MainActor
final class TracePlaybackModel: ObservableObject {
    @Published var isPlayingTrace = false
    @Published var traceSpeed: Double = 1.0
    @Published var traceCursor = 0
    @Published private(set) var selectionVersion = 0

    private var traceTask: Task<Void, Never>?

    func resetCursor() {
        pause()
        traceCursor = 0
        selectionVersion &+= 1
    }

    func selectEvent(at index: Int, eventCount: Int) {
        guard (0..<eventCount).contains(index) else { return }
        pause()
        traceCursor = index
        selectionVersion &+= 1
    }

    func resume(eventCount: Int) {
        guard eventCount > 0, !isPlayingTrace else { return }
        if traceCursor >= eventCount - 1 { traceCursor = 0 }
        isPlayingTrace = true
        traceTask?.cancel()
        traceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.isPlayingTrace {
                if self.traceCursor >= eventCount - 1 {
                    self.isPlayingTrace = false
                    break
                }
                let milliseconds = max(24, 95.0 / self.traceSpeed)
                do { try await Task.sleep(for: .milliseconds(Int(milliseconds.rounded()))) }
                catch { break }
                guard !Task.isCancelled, self.isPlayingTrace else { break }
                self.traceCursor += 1
            }
        }
    }

    func pause() {
        isPlayingTrace = false
        traceTask?.cancel()
        traceTask = nil
    }

    func restart(eventCount: Int) {
        pause()
        guard eventCount > 0 else { traceCursor = 0; return }
        traceCursor = 0
        selectionVersion &+= 1
    }
}

@MainActor
final class AppModel: ObservableObject {
    let editor = SourceEditorModel()
    let tracePlayer = TracePlaybackModel()

    @Published private(set) var result = ScanResult.empty
    @Published private(set) var scannedSource = ""
    @Published var inspectedSourceIndex: Int?
    @Published var selectedTab: AppTab = .scanner
    @Published var selectedLanguage: SourceLanguage = .swift
    @Published var isScanning = false
    @Published var benchmark: BenchmarkResult?
    @Published var benchmarkRunning = false
    @Published var selectedSample: SampleProgram = .basic
    @Published var toastMessage: String?
    @Published var toastVersion = 0

    private var toastTask: Task<Void, Never>?

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        tracePlayer.resetCursor()

        let input = editor.sourceCode
        let language = selectedLanguage
        Task {
            let value = await Task.detached(priority: .userInitiated) {
                ScannerEngine().scan(input, language: language)
            }.value
            withAnimation(.snappy(duration: 0.28)) {
                result = value
                scannedSource = input
                inspectedSourceIndex = value.events.first?.index
                isScanning = false
                tracePlayer.resetCursor()
                selectedTab = .tokens
            }
            showToast("\(language.rawValue) scan complete · \(value.tokens.filter { $0.type != .whitespace }.count) tokens")
        }
    }

    func setLanguage(_ language: SourceLanguage) {
        guard selectedLanguage != language else { return }
        // Translate only the untouched sample; preserve hand-written code.
        let followsSample = editor.sourceCode == selectedSample.source(for: selectedLanguage)
        selectedLanguage = language
        if followsSample { editor.sourceCode = selectedSample.source(for: language) }
        result = .empty
        scannedSource = ""
        inspectedSourceIndex = nil
        tracePlayer.resetCursor()
        benchmark = nil
        showToast("Scanner mode: \(language.rawValue)")
    }

    func loadSample(_ sample: SampleProgram) {
        selectedSample = sample
        editor.sourceCode = sample.source(for: selectedLanguage)
        result = .empty
        scannedSource = ""
        inspectedSourceIndex = nil
        tracePlayer.resetCursor()
        selectedTab = .scanner
        showToast("Loaded \(sample.rawValue) sample")
    }

    func selectTraceEvent(at index: Int) {
        guard result.events.indices.contains(index) else { return }
        inspectedSourceIndex = result.events[index].index
        tracePlayer.selectEvent(at: index, eventCount: result.events.count)
    }

    /// Select a source character and synchronize the trace/DFA to its closest recorded event.
    func inspectSourceCharacter(at sourceIndex: Int) {
        let characters = Array(editor.sourceCode)
        guard characters.indices.contains(sourceIndex), scannedSource == editor.sourceCode else { return }
        inspectedSourceIndex = sourceIndex
        guard let eventIndex = result.eventIndex(forSourceIndex: sourceIndex),
              result.events.indices.contains(eventIndex) else { return }
        tracePlayer.selectEvent(at: eventIndex, eventCount: result.events.count)
    }

    func benchmarkConcurrency() {
        guard !benchmarkRunning else { return }
        benchmarkRunning = true
        benchmark = nil
        let language = selectedLanguage

        // 32 independently schedulable jobs; each uses a larger repeated source
        // unit so useful CPU work outweighs task setup/coordination costs.
        let repetitionsPerDocument = 24
        let documentsPerSample = 8
        let workload = SampleProgram.allCases.flatMap { sample -> [ScanWorkItem] in
            let unit = sample.source(for: language)
            let expandedSource = Array(repeating: unit, count: repetitionsPerDocument).joined(separator: "\n")
            return Array(repeating: ScanWorkItem(source: expandedSource, language: language), count: documentsPerSample)
        }

        Task {
            let value = await Task.detached(priority: .utility) {
                await BenchmarkEngine.run(items: workload)
            }.value
            benchmark = value
            benchmarkRunning = false
            showToast(value.verified ? "Benchmark verified" : "Benchmark outputs differ")
        }
    }

    func showToast(_ message: String) {
        toastMessage = message
        toastVersion &+= 1
        toastTask?.cancel()
        toastTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(2.3)) } catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                self?.toastMessage = nil
            }
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case scanner = "Scanner"
    case dfa = "DFA"
    case trace = "Trace"
    case tokens = "Tokens"
    case lab = "Lab"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .scanner: return "doc.text"
        case .dfa: return "circle.hexagongrid.circle"
        case .trace: return "waveform.path.ecg"
        case .tokens: return "list.bullet.rectangle.portrait"
        case .lab: return "bolt.horizontal.circle"
        }
    }

    var accent: Color {
        switch self {
        case .scanner: return .indigo
        case .dfa: return .cyan
        case .trace: return .pink
        case .tokens: return .green
        case .lab: return .orange
        }
    }
}

enum SampleProgram: String, CaseIterable, Identifiable, Sendable {
    case basic = "Basic"
    case expressions = "Expressions"
    case strings = "Strings"
    case errors = "Errors"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .basic: return "Keywords, identifiers and integers"
        case .expressions: return "Operators, numbers and grouping"
        case .strings: return "Quoted text, escapes and comments"
        case .errors: return "Deliberate unknown-symbol cases"
        }
    }

    var source: String { source(for: .swift) }

    func source(for language: SourceLanguage) -> String {
        switch (self, language) {
        case (.basic, .swift):
            return """
            // Basic lexical analysis
            let count = 42;
            if count >= 10 {
                print("count = \\(count)");
            }
            """
        case (.basic, .cpp):
            return """
            #include <iostream>
            int main() {
                int count = 42;
                if (count >= 10) {
                    std::cout << "count = " << count << '\\n';
                }
                return 0;
            }
            """
        case (.expressions, .swift):
            return """
            var result = (12.5 + 8) * 3;
            if result != 60 && result < 100 {
                result = result / 2;
            }
            """
        case (.expressions, .cpp):
            return """
            double result = (12.5 + 8) * 3;
            if (result != 60 && result < 100) {
                result /= 2;
            }
            """
        case (.strings, .swift):
            return #"""
            @MainActor
            let greeting = "Hello, DFA!"
            let marker: Character = "!"
            /* Swift supports
               /* nested block comments */
            */
            """#
        case (.strings, .cpp):
            return #"""
            #include <string>
            std::string greeting = "Hello, DFA!";
            char marker = '!';
            /* C++ block comment */
            """#
        case (.errors, .swift):
            return """
            let value = 12 @ 4;
            let weird = #token;
            let unfinished = "hello
            """
        case (.errors, .cpp):
            return """
            int value = 12 @ 4;
            char broken = 'x;
            """
        }
    }
}
