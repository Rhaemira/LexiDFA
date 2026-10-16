//
//  ScannerView.swift
//  LexiDFA
//
//  Created by Amirali Yazdani on 10/13/26.
//

import SwiftUI

struct ScannerView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenTitle(
                        eyebrow: "Lexical Analysis Laboratory",
                        title: "Scan. Visualize. Understand.",
                        subtitle: "A DFA scanner implemented with explicit switch-case transitions, live state tracking and token emission."
                    )

                    SourceInputCard()

                    if !model.result.tokens.isEmpty {
                        SummaryStrip(result: model.result)
                        SourceDFADebuggerCard()
                    }

                    ScanInsightsCard()
                }
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 100)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AppearanceMenu()
                }
            }
        }
    }
}

/// The editor is isolated so keystrokes do not republish the full app model.
private struct SourceInputCard: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var editor: SourceEditorModel
    @EnvironmentObject private var tracePlayer: TracePlaybackModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("lexiDFA.cppGrudgeMode") private var cppGrudgeMode = true
    @State private var showScannerTip = false
    @State private var showCppPrank = false
    @State private var characterTapFeedback = 0

    private var scannerButton: some View {
        Button {
            model.scan()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: model.isScanning ? "hourglass" : "play.fill")
                    .imageScale(.medium)
                Text(model.isScanning ? "Scanning…" : "Run Scanner")
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity, minHeight: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .disabled(model.isScanning || editor.sourceCode.isEmpty)
    }

    private var highlightedCharacterIndex: Int? {
        guard model.scannedSource == editor.sourceCode else { return nil }
        if tracePlayer.isPlayingTrace,
           model.result.events.indices.contains(tracePlayer.traceCursor) {
            return model.result.events[tracePlayer.traceCursor].index
        }
        if let inspected = model.inspectedSourceIndex { return inspected }
        guard model.result.events.indices.contains(tracePlayer.traceCursor) else { return nil }
        return model.result.events[tracePlayer.traceCursor].index
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    SectionHeader(
                        title: "Source code",
                        subtitle: "Enter code or choose a teaching sample.",
                        symbol: "curlybraces.square.fill"
                    )

                    Menu {
                        ForEach(SampleProgram.allCases) { sample in
                            Button {
                                model.loadSample(sample)
                            } label: {
                                Label(sample.rawValue, systemImage: sample.symbol)
                            }
                        }
                    } label: {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.headline)
                            .frame(width: 40, height: 40)
                            .background(Color.indigo.opacity(0.10), in: Circle())
                    }
                    .accessibilityLabel("Choose sample")
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Language mode", systemImage: "chevron.left.forwardslash.chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            showScannerTip.toggle()
                        } label: {
                            Image(systemName: "sparkles")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.orange)
                                .frame(width: 32, height: 32)
                                .background(Color.orange.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showScannerTip, arrowEdge: .top) {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 11) {
                                    Label("Lexical magic", systemImage: "wand.and.stars")
                                        .font(.headline)
                                    Text("The scanner groups characters into tokens. The DFA tab shows the state machine, Trace shows each decision, and Tokens lists the output.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("This is a teaching lexer, not a full compiler frontend.")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.orange)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(18)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(width: 290, height: 300)
                            .presentationCompactAdaptation(.popover)
                        }
                        .accessibilityLabel("Scanner tips")
                    }

                    Picker("Source language", selection: Binding(
                        get: { model.selectedLanguage },
                        set: { selectLanguage($0) }
                    )) {
                        ForEach(SourceLanguage.allCases) { language in
                            Text(language.rawValue).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(model.selectedLanguage == .swift ? .orange : .blue)
                    .accessibilityLabel("Choose source language")

                    Text(model.selectedLanguage == .swift
                         ? "Swift keywords · attributes · nested block comments"
                         : "C++ keywords · character literals · preprocessor directives")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle(isOn: $cppGrudgeMode) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("C++ Grudge Mode", systemImage: "face.smiling.inverse")
                                .font(.caption.weight(.bold))
                            Text("Opt-in compiler drama when switching languages.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.orange)
                    .padding(11)
                    .background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.13), lineWidth: 1)
                    }

                }

                SourceCodeEditor(
                    text: $editor.sourceCode,
                    tokens: model.result.tokens,
                    scannedSource: model.scannedSource,
                    highlightedCharacter: highlightedCharacterIndex
                ) { sourceIndex in
                    characterTapFeedback &+= 1
                    model.inspectSourceCharacter(at: sourceIndex)
                }
                .frame(minHeight: 190, maxHeight: 300)
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.indigo.opacity(0.55), Color.cyan.opacity(0.35), Color.purple.opacity(0.38)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.15
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.055), lineWidth: 0.8)
                        .padding(2)
                        .allowsHitTesting(false)
                }
                .compositingGroup()
                .shadow(color: Color.indigo.opacity(0.06), radius: 12, y: 5)
                .sensoryFeedback(.selection, trigger: characterTapFeedback)

                if horizontalSizeClass == .compact {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            PillBadge(
                                text: "\(editor.sourceCode.count) chars",
                                color: .secondary,
                                symbol: "character.cursor.ibeam"
                            )
                            PillBadge(
                                text: "DFA + switch",
                                color: .indigo,
                                symbol: "point.3.connected.trianglepath.dotted"
                            )
                        }
                        scannerButton.frame(maxWidth: .infinity)
                    }
                } else {
                    HStack(alignment: .center, spacing: 10) {
                        PillBadge(
                            text: "\(editor.sourceCode.count) chars",
                            color: .secondary,
                            symbol: "character.cursor.ibeam"
                        )
                        PillBadge(
                            text: "DFA + switch",
                            color: .indigo,
                            symbol: "point.3.connected.trianglepath.dotted"
                        )
                        Spacer(minLength: 0)
                        scannerButton.frame(minWidth: 148)
                    }
                }
            }
        }
        .sheet(isPresented: $showCppPrank) {
            CppGrudgePrankSheet(
                onContinue: { showCppPrank = false },
                onReturnToSwift: {
                    model.setLanguage(.swift)
                    showCppPrank = false
                },
                onDisablePrank: {
                    cppGrudgeMode = false
                    showCppPrank = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func selectLanguage(_ language: SourceLanguage) {
        let previous = model.selectedLanguage
        model.setLanguage(language)
        if previous == .swift, language == .cpp, cppGrudgeMode {
            showCppPrank = true
        }
    }
}


private struct ScanInsightsCard: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var editor: SourceEditorModel

    private var visibleTokens: [Token] { model.result.tokens.filter { $0.type != .whitespace } }
    private var unknownTokens: [Token] { visibleTokens.filter { $0.type == .unknown } }
    private var lineCount: Int { max(1, editor.sourceCode.split(separator: "\n", omittingEmptySubsequences: false).count) }
    private var categoryCount: Int { Set(visibleTokens.map(\.type.rawValue)).count }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top, spacing: 10) {
                    SectionHeader(
                        title: "Scan insights",
                        subtitle: "Source health and shortcuts to the detailed views.",
                        symbol: "sparkles.rectangle.stack.fill"
                    )
                    Spacer(minLength: 0)
                    Image(systemName: model.result.tokens.isEmpty ? "wand.and.stars" : "checkmark.seal.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(model.result.tokens.isEmpty ? .orange : .green)
                }

                HStack(spacing: 9) {
                    MetricPill(title: "Lines", value: "\(lineCount)", symbol: "text.alignleft", color: .cyan)
                    MetricPill(
                        title: "Unknown",
                        value: model.result.tokens.isEmpty ? "—" : "\(unknownTokens.count)",
                        symbol: "exclamationmark.triangle",
                        color: model.result.tokens.isEmpty ? .secondary : (unknownTokens.isEmpty ? .green : .red)
                    )
                    MetricPill(title: "Token kinds", value: model.result.tokens.isEmpty ? "—" : "\(categoryCount)", symbol: "square.grid.2x2", color: .orange)
                }

                if model.result.tokens.isEmpty {
                    Label("Ready when you are", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.indigo)
                    Text("Run the scanner to get a token summary and lexical diagnostics. Then jump directly to the token stream, execution trace, or full state graph.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: unknownTokens.isEmpty ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(unknownTokens.isEmpty ? .green : .red)
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(unknownTokens.isEmpty ? "No unknown tokens detected" : "\(unknownTokens.count) unknown token(s) detected")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(unknownTokens.isEmpty ? .green : .red)
                            Text(unknownTokens.isEmpty
                                 ? "Lexical recognition completed. This does not mean the program is syntactically valid."
                                 : "Inspect the highlighted lexemes in Tokens. Syntax errors require a parser and grammar.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background((unknownTokens.isEmpty ? Color.green : Color.red).opacity(0.08), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                    HStack(spacing: 8) {
                        insightAction("Tokens", symbol: "list.bullet.rectangle.portrait.fill", color: .green) { model.selectedTab = .tokens }
                        insightAction("Trace", symbol: "waveform.path.ecg", color: .pink) { model.selectedTab = .trace }
                        insightAction("DFA", symbol: "circle.hexagongrid.circle.fill", color: .cyan) { model.selectedTab = .dfa }
                    }
                }
            }
        }
    }

    private func insightAction(_ title: String, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.bordered)
        .tint(color)
        .controlSize(.regular)
    }
}

struct SummaryStrip: View {
    let result: ScanResult

    var body: some View {
        HStack(spacing: 10) {
            MetricPill(
                title: "Tokens",
                value: "\(result.tokens.filter { $0.type != .whitespace }.count)",
                symbol: "text.word.spacing",
                color: .indigo
            )
            MetricPill(
                title: "Characters",
                value: "\(result.characters)",
                symbol: "character.cursor.ibeam",
                color: .cyan
            )
            MetricPill(
                title: "Scan",
                value: result.duration.millisecondsText,
                symbol: "timer",
                color: .purple
            )
        }
    }
}

struct MetricPill: View {
    let title: String
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.22), value: value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(color.opacity(0.13), lineWidth: 1)
        }
    }
}

extension SampleProgram {
    var symbol: String {
        switch self {
        case .basic: return "number"
        case .expressions: return "function"
        case .strings: return "quote.bubble.fill"
        case .errors: return "exclamationmark.triangle.fill"
        }
    }
}


/// A deliberately silly, entirely local C++ switching ritual.
/// It never opens external apps, requests permissions, places calls, or contacts a service.
private struct CppGrudgePrankSheet: View {
    let onContinue: () -> Void
    let onReturnToSwift: () -> Void
    let onDisablePrank: () -> Void

    @State private var step = 0
    @State private var wrongCaptcha = false
    @State private var captchaAttempts = 0
    @State private var fakeHotlinePresented = false

    private let totalSteps = 5

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: currentIcon)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(currentAccent)
                            .frame(width: 62, height: 62)
                            .background(
                                currentAccent.opacity(0.13),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("SWIFT SUPPORT DESK")
                                .font(.caption2.weight(.black))
                                .tracking(1.5)
                                .foregroundStyle(.secondary)
                            Text("C++ access review")
                                .font(.headline.weight(.bold))
                        }
                        Spacer(minLength: 0)
                    }

                    ProgressView(value: Double(step + 1), total: Double(totalSteps))
                        .tint(currentAccent)
                        .accessibilityLabel("Prank step \(step + 1) of \(totalSteps)")

                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentTitle)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(currentMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Group {
                        switch step {
                        case 0:
                            VStack(spacing: 10) {
                                prankButton("Yes. I choose chaos.", symbol: "flame.fill") {
                                    advance()
                                }

                                Button {
                                    onReturnToSwift()
                                } label: {
                                    Label("Actually, take me back to Swift", systemImage: "arrow.uturn.backward")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 42)
                                }
                                .buttonStyle(.bordered)
                            }

                        case 1:
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 9) {
                                    captchaChoice("{}", isCorrect: false)
                                    captchaChoice(";", isCorrect: true)
                                    captchaChoice(";;;", isCorrect: false)
                                }

                                if wrongCaptcha {
                                    Label(captchaFailureMessage, systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.orange)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(11)
                                        .background(
                                            Color.orange.opacity(0.10),
                                            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        )
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }

                                Text("A real CAPTCHA would verify nothing about your programming choices. This one verifies even less.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                        case 2:
                            VStack(spacing: 9) {
                                prankButton("Yes, I remember punch cards.", symbol: "hourglass") {
                                    advance()
                                }
                                prankButton("No, I'm just making questionable choices.", symbol: "person.fill") {
                                    advance()
                                }
                            }

                        case 3:
                            VStack(spacing: 9) {
                                prankButton("I'm okay. The compiler is the problem.", symbol: "checkmark.circle.fill") {
                                    advance()
                                }
                                prankButton("I need a semicolon break.", symbol: "cup.and.saucer.fill") {
                                    advance()
                                }
                            }

                        default:
                            VStack(spacing: 10) {
                                HStack(alignment: .top, spacing: 9) {
                                    Image(systemName: "phone.fill")
                                        .foregroundStyle(.orange)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Imaginary hotline: 1-800-NO-CPP")
                                            .font(.subheadline.weight(.bold))
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text("Totally fake. No Phone app will open and no call will be placed.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    Color.orange.opacity(0.09),
                                    in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                                )

                                Button {
                                    fakeHotlinePresented = true
                                } label: {
                                    Label("Call the imaginary hotline", systemImage: "phone.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 42)
                                }
                                .buttonStyle(.bordered)
                                .alert("Line busy: Swift is judging you", isPresented: $fakeHotlinePresented) {
                                    Button("Fair enough", role: .cancel) { }
                                } message: {
                                    Text("No call happened. Please carry on with your questionable language choice.")
                                }

                                prankButton("Fine, let me use C++", symbol: "chevron.right") {
                                    onContinue()
                                }
                            }
                        }
                    }

                    Text("A harmless local joke. It doesn't affect scanning or compiler results.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Button(role: .destructive) {
                        onDisablePrank()
                    } label: {
                        Label("I've suffered enough — disable Grudge Mode", systemImage: "hand.raised.fill")
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .frame(maxWidth: 560, alignment: .leading)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .background {
                LinearGradient(
                    colors: [currentAccent.opacity(0.10), Color.clear, Color.purple.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Skip this ritual", systemImage: "forward.fill") {
                            onContinue()
                        }
                        Button("Return to Swift", systemImage: "arrow.uturn.backward", role: .cancel) {
                            onReturnToSwift()
                        }
                        Button("Disable Grudge Mode", systemImage: "hand.raised.fill", role: .destructive) {
                            onDisablePrank()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title3.weight(.semibold))
                    }
                    .accessibilityLabel("Grudge Mode options")
                }
            }
        }
        .sensoryFeedback(.error, trigger: captchaAttempts)
        .sensoryFeedback(.selection, trigger: step)
    }

    private var currentIcon: String {
        switch step {
        case 0: return "exclamationmark.bubble.fill"
        case 1: return "checkmark.seal.fill"
        case 2: return "calendar.badge.clock"
        case 3: return "heart.text.square.fill"
        default: return "phone.fill"
        }
    }

    private var currentAccent: Color {
        switch step {
        case 0: return .orange
        case 1: return .purple
        case 2: return .indigo
        case 3: return .pink
        default: return .red
        }
    }

    private var currentTitle: String {
        switch step {
        case 0: return "Switching to C++? Bold."
        case 1: return "Human verification"
        case 2: return "A highly relevant question"
        case 3: return "Quick wellbeing check"
        default: return "C++ mode approved (begrudgingly)"
        }
    }

    private var currentMessage: String {
        switch step {
        case 0:
            return "A Swift engineer has sensed a disturbance in the type system. This brief ritual is entirely optional."
        case 1:
            return "Please identify the semicolon. This CAPTCHA protects absolutely nothing."
        case 2:
            return "Are you over 90 years old? Your answer will be treated with the scientific rigor it deserves: none."
        case 3:
            return "Are you okay? You have every right to use C++. We will, however, be disappointed."
        default:
            return "You passed our very fake checks. Remember: this is a joke, not a compiler diagnostic."
        }
    }

    private var captchaFailureMessage: String {
        switch captchaAttempts % 4 {
        case 1: return "Incorrect. The semicolon union has been notified."
        case 2: return "Suspicious punctuation. A committee is reviewing your keystrokes."
        case 3: return "You may be human, but your syntax remains under investigation."
        default: return "Verification denied. The semicolon has requested a second opinion."
        }
    }

    private func prankButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                Text(title)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } icon: {
                Image(systemName: symbol)
                    .frame(width: 22)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 42)
            .padding(.vertical, 3)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 15))
        .tint(currentAccent)
    }

    private func captchaChoice(_ title: String, isCorrect: Bool) -> some View {
        Button {
            if isCorrect {
                wrongCaptcha = false
                advance()
            } else {
                captchaAttempts += 1
                withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                    wrongCaptcha = true
                }
            }
        } label: {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 13))
        .tint(.purple)
        .accessibilityHint(isCorrect ? "Advances the prank" : "Shows a fake verification error")
    }

    private func advance() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            step = min(step + 1, totalSteps - 1)
        }
    }
}



// MARK: - Source-to-DFA character inspector

private struct SourceDFADebuggerCard: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var editor: SourceEditorModel
    @EnvironmentObject private var tracePlayer: TracePlaybackModel

    private var isInSync: Bool { model.scannedSource == editor.sourceCode }

    private var currentEvent: ScannerEvent? {
        guard model.result.events.indices.contains(tracePlayer.traceCursor) else { return nil }
        return model.result.events[tracePlayer.traceCursor]
    }

    private var focusedIndex: Int? {
        if tracePlayer.isPlayingTrace { return currentEvent?.index }
        return model.inspectedSourceIndex ?? currentEvent?.index
    }

    private var selectedToken: Token? {
        guard let focusedIndex else { return nil }
        return model.result.tokens.first { $0.start <= focusedIndex && focusedIndex < $0.end }
    }

    private var focusedCharacter: String {
        guard let focusedIndex else { return "—" }
        let characters = Array(editor.sourceCode)
        guard characters.indices.contains(focusedIndex) else { return "—" }
        switch characters[focusedIndex] {
        case " ": return "space"
        case "\n": return "newline"
        case "\t": return "tab"
        default: return String(characters[focusedIndex])
        }
    }

    private var location: (line: Int, column: Int) {
        guard let focusedIndex else { return (1, 1) }
        var line = 1
        var column = 1
        for character in Array(editor.sourceCode.prefix(focusedIndex)) {
            if character == "\n" { line += 1; column = 1 }
            else { column += 1 }
        }
        return (line, column)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 13) {
                SectionHeader(
                    title: "Source → DFA",
                    subtitle: "Tap a character directly in the editor to inspect its token and transition.",
                    symbol: "point.topleft.down.to.point.bottomright.curvepath"
                )

                if !isInSync {
                    Label("Source changed — run the scanner again to synchronize its trace.", systemImage: "arrow.clockwise.circle")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        model.scan()
                    } label: {
                        Label("Rescan source", systemImage: "play.fill")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                    .tint(.indigo)
                } else if let event = currentEvent {
                    HStack(spacing: 9) {
                        detailMetric(title: "CHARACTER", value: focusedCharacter, symbol: "character.cursor.ibeam", color: .indigo)
                        detailMetric(title: "TOKEN", value: selectedToken?.type.rawValue ?? "—", symbol: "tag.fill", color: .purple)
                        detailMetric(title: "POSITION", value: "L\(location.line) · C\(location.column)", symbol: "scope", color: .cyan)
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Label("Transition explanation", systemImage: "wand.and.stars")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.indigo)
                        Text(event.message)
                            .font(.subheadline.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            stateChip(event.state.title, color: .blue)
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                            stateChip((event.nextState ?? event.state).title, color: event.kind == .error ? .red : .cyan)
                            Spacer(minLength: 0)
                        }
                        if let selectedToken {
                            HStack(alignment: .top, spacing: 7) {
                                Image(systemName: "tag.fill")
                                    .foregroundStyle(tint(for: selectedToken.type))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Emits \(selectedToken.type.rawValue)")
                                        .fontWeight(.semibold)
                                    Text("‘\(selectedToken.lexeme)’")
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .font(.caption)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(tint(for: selectedToken.type).opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    HStack(spacing: 8) {
                        Button {
                            model.selectedTab = .trace
                        } label: {
                            Label("Open Trace", systemImage: "waveform.path.ecg")
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.bordered)
                        .tint(.pink)

                        Button {
                            model.selectedTab = .dfa
                        } label: {
                            Label("Open DFA", systemImage: "circle.hexagongrid.circle")
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.bordered)
                        .tint(.cyan)
                    }
                    .font(.caption.weight(.bold))
                } else {
                    Label("Run the scanner to enable character-by-character DFA inspection.", systemImage: "play.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func detailMetric(title: String, value: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption2.weight(.heavy))
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.caption.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.085), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(color.opacity(0.15), lineWidth: 0.8)
        }
    }

    private func stateChip(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }

    private func tint(for type: TokenType) -> Color {
        switch type {
        case .keyword: return .indigo
        case .identifier: return .blue
        case .integer, .floatingPoint: return .purple
        case .string, .characterLiteral: return .pink
        case .attribute: return .orange
        case .preprocessor: return .brown
        case .operatorSymbol: return .orange
        case .delimiter: return .green
        case .whitespace: return .secondary
        case .comment: return .teal
        case .unknown: return .red
        }
    }
}
