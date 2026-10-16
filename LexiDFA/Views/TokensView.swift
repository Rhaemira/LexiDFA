//
//  TokensView.swift
//  LexiDFA
//
//  Created by Amirali Yazdani on 10/13/26.
//

import SwiftUI

struct TokensView: View {
    @EnvironmentObject private var model: AppModel
    @State private var includeWhitespace = false
    @State private var search = ""

    var filtered: [Token] {
        model.result.tokens.filter { token in
            (includeWhitespace || token.type != .whitespace) &&
            (search.isEmpty || token.lexeme.localizedCaseInsensitiveContains(search) || token.type.rawValue.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenTitle(
                        eyebrow: "Token Stream",
                        title: "What did the DFA recognize?",
                        subtitle: "Inspect each lexeme, category, source range and DFA state path."
                    )

                    if model.result.tokens.isEmpty {
                        EmptyStateCard(
                            title: "No tokens yet",
                            message: "Run the scanner first, then return here to inspect the emitted token stream.",
                            symbol: "text.word.spacing"
                        )
                    } else {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(.secondary)
                                    TextField("Filter by lexeme or type", text: $search)
                                        .textFieldStyle(.plain)
                                }
                                .padding(12)
                                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                                Toggle(isOn: $includeWhitespace) {
                                    Label("Show whitespace", systemImage: "space")
                                }
                                .font(.subheadline.weight(.medium))
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Lexeme")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("Type")
                                        .frame(width: 96, alignment: .leading)
                                    Text("States")
                                        .frame(width: 105, alignment: .leading)
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)

                                Divider()

                                if filtered.isEmpty {
                                    Text("No tokens match your filter.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .padding(.vertical, 18)
                                } else {
                                    ForEach(filtered) { token in
                                        TokenRow(token: token)
                                    }
                                }
                            }
                        }
                    }
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
                    TokenQuickActionsMenu(includeWhitespace: $includeWhitespace, search: $search)
                }
            }
        }
    }
}

struct TokenRow: View {
    let token: Token

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(token.lexeme.replacingOccurrences(of: "\n", with: "↵"))
                    .font(.system(.subheadline, design: .monospaced).weight(.medium))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text("\(token.start)–\(token.end)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(token.type.rawValue)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(typeColor.opacity(0.11), in: Capsule())
                .foregroundStyle(typeColor)
                .frame(width: 96, alignment: .leading)

            Text(token.states.map(\.rawValue).joined(separator: "→"))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(width: 105, alignment: .leading)
        }
        .padding(.vertical, 6)
    }

    private var typeColor: Color {
        switch token.type {
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
