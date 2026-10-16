# LexiDFA

**An interactive DFA-based lexical analysis lab for iOS.**

LexiDFA makes the first stage of a compiler visible. Write a small Swift or C++ example, run the scanner, inspect the emitted tokens, and follow the character-by-character path through a deterministic finite automaton (DFA). A separate lab compares sequential and task-group-based scans over independent source inputs.

The project is maintained by **Amirali Yazdani** as an educational compiler-design project. The main scanner intentionally uses explicit `switch` / `case` transitions so its behavior can be explained and reviewed in a classroom.

## Features

- **Swift and C++ teaching dialects** with a language selector and built-in examples.
- **Explicit switch/case scanner** for identifiers, keywords, numeric literals, strings, character literals, comments, attributes, directives, operators, delimiters, whitespace, and lexical-error tokens.
- **Interactive DFA view** with state selection, transition inspection, pinch-to-zoom, pan, and trace-linked highlighting.
- **Trace playback** with pause, resume, restart, and adjustable playback speed.
- **Token explorer** with categories, lexemes, source ranges, and state paths.
- **Source-to-DFA inspection** by selecting a character in the source editor and following its associated trace event.
- **Sequential vs. concurrent benchmark lab** that verifies ordered token output before reporting timing.
- **Light and dark appearance**, responsive SwiftUI screens, and isolated observable state for editor and trace updates.
- **Opt-in C++ Grudge Mode**, a text-only in-app joke that can be skipped or disabled at any time.
- **No third-party runtime dependencies, networking, analytics, audio, or external services.** Appearance and Grudge Mode preferences are stored locally.

## Screens and workflow

1. Open **Scanner**, choose Swift or C++, and load a sample or enter source code.
2. Run the scanner and review token counts and any unknown/error tokens.
3. Open **Tokens** to inspect lexemes, token types, and source ranges.
4. Select a character in the source editor to inspect the corresponding scan event.
5. Open **Trace** to pause playback or adjust its speed.
6. Open **DFA** to select states, inspect transitions, and zoom or pan around the graph.
7. Open **Lab** to compare sequential and concurrent batch scanning, then confirm that the output verification passed before interpreting timing.

## Language scope

LexiDFA is a **lexer teaching tool, not a complete Swift or C++ compiler frontend**. It tokenizes a documented subset of each language; it does not parse statements, validate expression grammar, perform type checking, or compile programs.

Supported areas include:

| Area | Scope |
| --- | --- |
| Identifiers | ASCII letters and `_` at the start; letters, digits, and `_` afterward |
| Keywords | Separate keyword sets for the Swift and C++ teaching dialects |
| Numbers | Integers and basic decimal/exponent forms, such as `42`, `12.5`, and `1e-3` |
| Literals | Double-quoted strings with escapes and single-quoted character literals |
| Swift-specific tokens | `@` attributes and nested block comments |
| Directives | `#` directive lines beginning at a line's directive position |
| Operators | Common single and compound operators using maximal munch |
| Comments | `//` line comments and `/* ... */` block comments; nesting follows the selected dialect's rules |
| Diagnostics | Unknown symbols and unterminated supported literals/comments are represented in scan output |

The teaching subset does not yet cover all Swift multiline, raw, or interpolated strings; all C++ raw-string forms; every numeric suffix or literal form; full Unicode identifier rules; or the complete lexical edge cases defined by either language standard. Directive lines are emitted as a single token. Syntax errors such as missing semicolons or unmatched braces are parser concerns and are outside this scanner's scope.

## Concurrency and benchmark interpretation

A single lexical scan remains sequential: the next DFA state depends on the current state and character. The benchmark instead distributes **independent source inputs** across a bounded Swift `TaskGroup` worker pool. Both paths use the same `ScannerEngine` and compare ordered token output, including token kind, lexeme, source range, and character count.

`TaskGroup` provides structured concurrency; it does not promise that every task runs simultaneously on a separate CPU core. Task creation and coordination have costs, so the concurrent path can be slower for some workloads. A speedup below `1.0×` means that the concurrent run was slower in that measurement. Treat the Lab as an educational experiment, not a universal performance claim. See [Benchmark methodology](docs/BENCHMARKING.md).

## Requirements

- macOS with **Xcode 26 or newer** to build and run the iOS app target.
- iOS 17 or newer for a physical iPhone or iPad.
- Swift 6.0 or newer to run the core package tests.
- No third-party package dependencies.

## Run the app

1. Clone the repository or download its source archive.
2. Open `LexiDFA.xcodeproj` in Xcode.
3. Select the `LexiDFA` scheme and an iPhone or iPad Simulator.
4. Build and launch with **Product → Run** or **⌘R**.

For a physical device, choose a development team under **Signing & Capabilities**. The project currently uses `com.amiraliyazdani.lexidfa` as its bundle identifier; change it if a different identifier is registered to the publishing account.

## Run the core tests

The scanner and benchmark core is also exposed as the `LexiDFACore` Swift package target. From the repository root, run:

```bash
swift test
```

To run the optimized configuration:

```bash
swift test -c release
```

The Swift package tests cover scanner tokenization, operators, literals, comments, source ranges, trace events, and benchmark result verification. They do not replace a build and smoke test of the SwiftUI app in Xcode.

## Architecture

```text
Source editor
    │
    ▼
ScannerEngine (switch/case DFA)
    ├── Tokens ─────────────► Tokens screen
    ├── Trace events ───────► Trace player ───► DFA highlighting
    └── Scan summary ───────► Scanner insights

Independent source inputs
    ├── SequentialBatchScanner
    └── ConcurrentBatchScanner (TaskGroup)
                   │
                   ▼
          Ordered result verification
```

See [Architecture](docs/ARCHITECTURE.md), [Benchmark methodology](docs/BENCHMARKING.md), and [Roadmap](ROADMAP.md).

## Privacy

Source text is processed locally by the scanner. The app contains no network client, analytics SDK, advertising SDK, audio playback, or external-service integration. Appearance and Grudge Mode preferences are saved locally using `AppStorage` / `UserDefaults`. Because the app has no account system or server, it does not upload code to a service. The Xcode target includes a `PrivacyInfo.xcprivacy` manifest declaring the app-only UserDefaults use. See [Privacy Policy](PRIVACY.md).

## Contributing

Bug reports and focused pull requests are welcome. Include a small reproducing source sample for scanner issues and add a regression test when behavior changes. See [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a change.

Before tagging a public version, complete the [Release Checklist](RELEASING.md), including an Xcode archive, signing, device testing, screenshots, and review of the App Store privacy disclosures.

## License

LexiDFA is distributed under the MIT License. See [LICENSE](LICENSE).
