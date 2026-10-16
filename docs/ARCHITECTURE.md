# Architecture

LexiDFA is an educational iOS app with a SwiftUI presentation layer and a small, testable scanner core.

## High-level flow

```text
Source editor
    │
    ▼
ScannerEngine.scan(_:language:)
    │
    ├── [Token] ───────► Tokens screen
    │
    ├── [ScannerEvent] ► Trace playback ─► DFA highlighting
    │         ▲                  ▲
    │         └── Source → DFA character inspector
    │
    └── Scan metadata ─► Scanner summary

Independent source inputs ─► BenchmarkEngine
                                  ├── sequential run
                                  ├── TaskGroup run
                                  └── ordered result verification
```

## Main components

- `Scanner/ScannerEngine.swift` — character-by-character lexical analysis for the Swift and C++ teaching subsets. State transitions are written with explicit `switch` / `case` branches to make the DFA visible for coursework; `SourceLanguage` defines each dialect's keyword set.
- `Models/DFA.swift` — DFA states, accepting-state metadata, and transition definitions consumed by the visualization.
- `Models/Token.swift` — token categories, lexemes, half-open source ranges, and the state path associated with each token.
- `Models/ScanResult.swift` — emitted tokens, trace events, character count, and elapsed duration.
- `Concurrency/BenchmarkEngine.swift` — `SequentialBatchScanner` and `ConcurrentBatchScanner` are separate batch strategies. The latter uses `TaskGroup` for independent input units; `BenchmarkEngine` warms them up, times repeated rounds, computes median durations and verifies ordered results.
- `App/AppModel.swift` — UI-facing state, scan/benchmark task orchestration, and trace playback controls.
- `Visualization/DFAFlowView.swift` and `Views/` — interactive DFA and SwiftUI screens.

## Design principles

1. Keep the scanner small enough to explain at a whiteboard.
2. Keep view state and scanner logic separated.
3. Treat benchmark correctness as a requirement, not an optional performance detail.
4. Explain the limitations of the toy language instead of implying that it implements all of Swift or another production language.

## Current language scope

The source-language picker selects a Swift or C++ teaching dialect. The DFA reference graph intentionally shows the union of states and transition types so students can compare both dialects. Swift-specific attribute state (`@name`) and nested block comments are marked in the graph; line-start `#` directives and character literals are shared examples of lexical units.

The implementation handles ASCII letter / underscore identifier starts in this teaching subset, digits/underscores in identifiers, basic decimal/exponent numeric forms, escaped double-quoted strings, single-quoted character literals, common maximal-munch operators, punctuation, `//` comments, `/* ... */` comments, line-start directives, whitespace, and unknown-symbol/unterminated-unit diagnostics. It is deliberately not a complete implementation of either language standard and does not parse statements or expressions.


## UI responsiveness

`SourceEditorModel` owns the high-frequency source text binding so keystrokes do not publish through the app-wide `AppModel`. `TracePlaybackModel` owns playback cursor/speed state so animation ticks only invalidate views that directly depend on the trace. Scanning and benchmark execution run away from the main actor; the benchmark task uses utility priority so it is less likely to contend with user interactions.


## UI organization and interaction

The Scanner screen is the home for source editing, dialect selection, the single appearance menu, and scan insights. The state graph is shown only on the dedicated DFA tab to avoid presenting the same graph twice. The DFA graph defaults to a focused rendering that highlights the active trace transition; a contextual toolbar action toggles all compact edge labels. The other tab toolbars expose context actions: trace navigation, token filters, and benchmark notes.

The C++ Grudge Mode is a local joke, not a security control. It uses a deliberately silly semicolon choice, an irrelevant age question, a mock wellbeing check, and an imaginary hotline. The user can skip, return to Swift, or disable Grudge Mode at any point. It has no audio, image downloads, external calls, or network activity.


## Source-to-DFA inspection

`SourceCodeEditor` wraps `UITextView` so a tap can be converted into a glyph offset. UIKit exposes positions in UTF-16 code units, while the teaching scanner records source ranges as Swift `Character` offsets; `CharacterUTF16Map` converts between those coordinate systems, including characters represented by multiple UTF-16 units. The editor applies token colors and a focused-character background only while its current source exactly matches the last scanned source.

`ScanResult.eventIndex(forSourceIndex:)` maps a tapped character offset to the most relevant trace event. It prefers an exact recorded character event; if the scanner coalesces characters (for example, a run of whitespace), it selects the nearest event within the containing token, falling back to the nearest event in the scan. `AppModel.inspectSourceCharacter(at:)` updates the inspected source offset and the isolated `TracePlaybackModel` cursor. The DFA graph already observes that cursor, so it highlights the transition without maintaining a second, competing source-selection model. If the text editor diverges from `scannedSource`, the inspector reports that the displayed trace is stale and asks for a rescan rather than presenting incorrect character offsets.

The UI uses native SwiftUI animation, symbol effects, layered gradient borders, numeric content transitions, and sensory feedback for visual-first teaching cues. These interaction effects are implemented within LexiDFA using standard SwiftUI APIs. The Swift source files carry the author header for Amirali Yazdani.


## Grudge Mode

Grudge Mode stays intentionally lightweight: a short multi-step SwiftUI sheet with text-only jokes, a semicolon choice, haptic feedback, and easy escape/disable actions. It does not use audio assets, photo challenges, external services, or the Phone app. The “hotline” is fictional and only presents an in-app alert.
