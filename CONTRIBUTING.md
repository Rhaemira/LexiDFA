# Contributing

LexiDFA is an educational compiler-design project. Changes should improve scanner correctness, make the DFA easier to understand, or improve the reliability and accessibility of the app.

## Reporting a bug

Use the GitHub issue templates when available. Include:

- The Xcode version and the iOS Simulator or device model for app/UI issues.
- The smallest source snippet that reproduces a scanner problem.
- The tokens or behavior observed and the expected result.
- Device, build configuration (Debug or Release), workload size, and verification status for benchmark reports.

Do not attach signing certificates, provisioning profiles, passwords, private keys, or personal data.

## Development workflow

1. Create a focused branch for the change.
2. Keep scanner transitions explicit and easy to trace through `switch` / `case` branches.
3. Add a regression test for each behavior change in the scanner or benchmark core.
4. Run `swift test` and, for a performance-sensitive change, `swift test -c release`.
5. Open `LexiDFA.xcodeproj` in Xcode 26 or newer and smoke-test affected screens on an iPhone Simulator in light and dark appearance.
6. Update the README or documentation when the supported language subset, benchmark methodology, or user-facing behavior changes.

## Pull request expectations

- The change has a clear scope and rationale.
- Tests pass locally, or any failure is described with evidence.
- The sequential and concurrent paths still produce matching ordered token output.
- UI changes remain usable on narrow screens and at larger text sizes.
- No machine-specific Xcode state, build output, signing material, or generated simulator files are added.

## Coding style

Prefer descriptive names, small focused methods, and comments that explain the reason for a non-obvious decision. Avoid presenting the scanner as a complete Swift or C++ compiler frontend; its documented language subsets are deliberate.
