//
//  DFAView.swift
//  LexiDFA
//
//  Created by Amirali Yazdani on 10/13/26.
//

import SwiftUI

struct DFAView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showAllTransitionLabels = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenTitle(
                        eyebrow: "Finite Automaton",
                        title: "The Scanner's DFA",
                        subtitle: "Explore every state and transition. Pinch to zoom, drag in any direction, and inspect the token categories recognized in Swift or C++."
                    )

                    DFAVisualizationCard(showAllTransitionLabels: $showAllTransitionLabels)
                    DFAStateReferenceCard()
                    TokenCatalogueCard()
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
                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            showAllTransitionLabels.toggle()
                        }
                        model.showToast(showAllTransitionLabels ? "Full transition labels enabled" : "Focused DFA view")
                    } label: {
                        Image(systemName: showAllTransitionLabels ? "text.bubble.fill" : "text.bubble")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(showAllTransitionLabels ? .cyan : .primary)
                            .frame(width: 36, height: 36)
                            .background(showAllTransitionLabels ? Color.cyan.opacity(0.14) : Color.primary.opacity(0.05), in: Circle())
                    }
                    .accessibilityLabel(showAllTransitionLabels ? "Hide transition labels" : "Show all transition labels")
                    .accessibilityHint("Switch between a clean focused graph and all transition labels.")
                }
            }
        }
    }
}

/// Keeps rapidly changing trace highlights inside the graph card instead of
/// invalidating the entire DFA page and its static token catalogue.
private struct DFAVisualizationCard: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var tracePlayer: TracePlaybackModel
    @Binding var showAllTransitionLabels: Bool

    private var currentEvent: ScannerEvent? {
        model.result.events.indices.contains(tracePlayer.traceCursor) ? model.result.events[tracePlayer.traceCursor] : nil
    }

    private var activeState: DFAState {
        guard let event = currentEvent else { return .start }
        return event.nextState ?? event.state
    }

    private var activeTransition: (DFAState, DFAState)? {
        guard let event = currentEvent, let next = event.nextState else { return nil }
        return (event.state, next)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(
                        title: "State graph",
                        subtitle: "Pinch/drag to explore · top-right speech bubble reveals every edge label.",
                        symbol: "circle.hexagongrid.circle.fill"
                    )
                    Spacer(minLength: 0)
                    PillBadge(text: activeState.title, color: stateColor(activeState), symbol: activeState.accepting ? "checkmark" : "play.fill")
                }
                DFAFlowView(
                    activeState: activeState,
                    activeTransition: activeTransition,
                    showAllTransitionLabels: $showAllTransitionLabels
                )
            }
        }
    }

    private func stateColor(_ state: DFAState) -> Color {
        switch state {
        case .start: return .indigo
        case .identifier: return .blue
        case .number: return .purple
        case .string: return .pink
        case .operatorState: return .orange
        case .delimiter: return .green
        case .comment: return .teal
        case .characterLiteral: return .mint
        case .blockComment: return .cyan
        case .preprocessor: return .brown
        case .attribute: return Color(red: 0.69, green: 0.47, blue: 0.05)
        case .error: return .red
        }
    }
}

/// Only this reference list responds to trace cursor movement; the rest of the
/// DFA page remains stable while the trace plays.
private struct DFAStateReferenceCard: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var tracePlayer: TracePlaybackModel

    private var activeState: DFAState {
        guard model.result.events.indices.contains(tracePlayer.traceCursor),
              let event = model.result.events[safe: tracePlayer.traceCursor] else { return .start }
        return event.nextState ?? event.state
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("State reference")
                    .font(.headline)

                ForEach(DFAState.allCases) { state in
                    HStack(spacing: 12) {
                        StateBadge(state: state, active: state == activeState)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(state.rawValue) · \(state.title)")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(stateDescription(state))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        if state.accepting {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }

    private func stateDescription(_ state: DFAState) -> String {
        switch state {
        case .start: return "Initial state. Classifies the next character."
        case .identifier: return "Letters, digits and underscores continue the identifier."
        case .number: return "Consumes integer and basic floating-point forms."
        case .string: return "Consumes double-quoted text and escapes."
        case .operatorState: return "Recognizes operators using longest-match rules."
        case .delimiter: return "Accepts punctuation and grouping delimiters."
        case .comment: return "Consumes a // comment up to the next newline."
        case .characterLiteral: return "Consumes single-quoted character literals."
        case .blockComment: return "Consumes /* ... */ comments; nested comments in Swift mode."
        case .preprocessor: return "Consumes a # directive from the start of a line."
        case .attribute: return "Consumes a Swift @attribute name."
        case .error: return "Represents an unknown symbol or unterminated literal/comment."
        }
    }
}

private struct TokenCatalogueCard: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "Token catalogue",
                    subtitle: "Every token category the teaching scanner can emit.",
                    symbol: "square.grid.2x2.fill"
                )
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 9)], spacing: 9) {
                    ForEach(TokenType.allCases, id: \.rawValue) { type in
                        HStack(spacing: 8) {
                            Text(type.symbol)
                                .font(.system(.caption, design: .monospaced).weight(.bold))
                                .frame(minWidth: 34, minHeight: 30)
                                .foregroundStyle(tokenColor(type))
                                .background(tokenColor(type).opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            Text(type.rawValue)
                                .font(.caption.weight(.semibold))
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                            Spacer(minLength: 0)
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                }
            }
        }
    }

    private func tokenColor(_ type: TokenType) -> Color {
        switch type {
        case .keyword: return .indigo
        case .identifier: return .blue
        case .integer: return .purple
        case .floatingPoint: return Color(red: 0.52, green: 0.32, blue: 0.92)
        case .string: return .pink
        case .characterLiteral: return .mint
        case .attribute: return Color(red: 0.69, green: 0.47, blue: 0.05)
        case .preprocessor: return .brown
        case .operatorSymbol: return .orange
        case .delimiter: return .green
        case .whitespace: return .gray
        case .comment: return .teal
        case .unknown: return .red
        }
    }
}

struct StateBadge: View {
    let state: DFAState
    let active: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(stateColor.opacity(active ? 0.18 : 0.08))
            Text(state.rawValue)
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundStyle(stateColor)
        }
        .frame(width: 46, height: 46)
        .overlay {
            Circle().strokeBorder(stateColor.opacity(active ? 0.60 : 0.16), lineWidth: active ? 2 : 1)
        }
        .scaleEffect(active ? 1.05 : 1)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: active)
    }

    private var stateColor: Color {
        switch state {
        case .start: return .indigo
        case .identifier: return .blue
        case .number: return .purple
        case .string: return .pink
        case .operatorState: return .orange
        case .delimiter: return .green
        case .comment: return .teal
        case .characterLiteral: return .mint
        case .blockComment: return .cyan
        case .preprocessor: return .brown
        case .attribute: return Color(red: 0.69, green: 0.47, blue: 0.05)
        case .error: return .red
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
