//
//  ContentView.swift
//  LexiDFA
//
//  Created by Amirali Yazdani on 10/13/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()

            TabView(selection: $model.selectedTab) {
                ScannerView()
                    .tabItem { Label("Scanner", systemImage: "doc.text.fill") }
                    .tag(AppTab.scanner)

                DFAView()
                    .tabItem { Label("DFA", systemImage: "circle.hexagongrid.circle.fill") }
                    .tag(AppTab.dfa)

                TraceView()
                    .tabItem { Label("Trace", systemImage: "waveform.path.ecg") }
                    .tag(AppTab.trace)

                TokensView()
                    .tabItem { Label("Tokens", systemImage: "list.bullet.rectangle.portrait.fill") }
                    .tag(AppTab.tokens)

                PerformanceView()
                    .tabItem { Label("Lab", systemImage: "bolt.horizontal.circle.fill") }
                    .tag(AppTab.lab)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tint(model.selectedTab.accent)

            if let message = model.toastMessage {
                ToastBanner(message: message, color: model.selectedTab.accent)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82), value: model.toastMessage)
        .sensoryFeedback(.success, trigger: model.toastVersion)
    }
}


struct ToastBanner: View {
    let message: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.13), in: Circle())
            Text(message)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(color.opacity(0.24), lineWidth: 1) }
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
        .accessibilityElement(children: .combine)
    }
}

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.indigo.opacity(0.26), Color.purple.opacity(0.15), Color.cyan.opacity(0.09)]
                    : [Color.indigo.opacity(0.10), Color.purple.opacity(0.07), Color.cyan.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.cyan.opacity(colorScheme == .dark ? 0.07 : 0.05))
                .frame(width: 240, height: 240)
                .blur(radius: 36)
                .offset(x: 150, y: -300)

            Circle()
                .fill(Color.purple.opacity(colorScheme == .dark ? 0.08 : 0.05))
                .frame(width: 280, height: 280)
                .blur(radius: 48)
                .offset(x: -160, y: 320)
        }
    }
}

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.07), radius: 18, y: 8)
    }
}

struct ScreenTitle: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(.indigo)

            Text(title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AppearanceMenu: View {
    @AppStorage("lexiDFA.appearanceMode") private var appearanceMode = 0

    var body: some View {
        Menu {
            Button {
                appearanceMode = 0
            } label: {
                Label("System", systemImage: "iphone")
            }

            Button {
                appearanceMode = 1
            } label: {
                Label("Light", systemImage: "sun.max.fill")
            }

            Button {
                appearanceMode = 2
            } label: {
                Label("Dark", systemImage: "moon.fill")
            }
        } label: {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                }
        }
        .accessibilityLabel("Appearance")
    }

    private var icon: String {
        switch appearanceMode {
        case 1: return "sun.max.fill"
        case 2: return "moon.fill"
        default: return "circle.lefthalf.filled"
        }
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String?
    let symbol: String

    init(title: String, subtitle: String? = nil, symbol: String) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.headline)
                .frame(width: 40, height: 40)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [.indigo, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

struct PillBadge: View {
    let text: String
    let color: Color
    let symbol: String?

    init(text: String, color: Color, symbol: String? = nil) {
        self.text = text
        self.color = color
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol)
            }
            Text(text)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.11), in: Capsule())
    }
}

struct EmptyStateCard: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        GlassCard {
            VStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.indigo)
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
    }
}

extension Duration {
    var millisecondsText: String {
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        return String(format: "%.2f ms", seconds * 1_000)
    }
}


/// Contextual toolbar actions replace duplicated appearance controls on non-Scanner tabs.
struct TraceQuickActionsMenu: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var tracePlayer: TracePlaybackModel

    var body: some View {
        Menu {
            Button {
                model.selectTraceEvent(at: 0)
            } label: {
                Label("Jump to first event", systemImage: "backward.end.fill")
            }
            .disabled(model.result.events.isEmpty)

            Button {
                model.selectTraceEvent(at: max(model.result.events.count - 1, 0))
            } label: {
                Label("Jump to latest event", systemImage: "forward.end.fill")
            }
            .disabled(model.result.events.isEmpty)

            Divider()

            Button {
                tracePlayer.pause()
                model.showToast("Trace paused. The DFA is holding its breath.")
            } label: {
                Label("Pause trace", systemImage: "pause.fill")
            }
            .disabled(!tracePlayer.isPlayingTrace)
        } label: {
            Image(systemName: "scope")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.pink)
                .frame(width: 36, height: 36)
                .background(Color.pink.opacity(0.12), in: Circle())
        }
        .accessibilityLabel("Trace actions")
    }
}

struct TokenQuickActionsMenu: View {
    @Binding var includeWhitespace: Bool
    @Binding var search: String

    var body: some View {
        Menu {
            Toggle(isOn: $includeWhitespace) {
                Label("Show whitespace", systemImage: "space")
            }
            Button {
                search = ""
            } label: {
                Label("Clear token filter", systemImage: "xmark.circle")
            }
            .disabled(search.isEmpty)
        } label: {
            Image(systemName: includeWhitespace ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.green)
                .frame(width: 36, height: 36)
                .background(Color.green.opacity(0.12), in: Circle())
        }
        .accessibilityLabel("Token filters")
    }
}

struct LabQuickGuideButton: View {
    @State private var showGuide = false

    var body: some View {
        Button {
            showGuide = true
        } label: {
            Image(systemName: "sparkles")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.orange)
                .frame(width: 36, height: 36)
                .background(Color.orange.opacity(0.13), in: Circle())
        }
        .accessibilityLabel("Lab field notes")
        .popover(isPresented: $showGuide, arrowEdge: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Tiny lab coat, big claims", systemImage: "flask.fill")
                        .font(.headline)
                    Text("The benchmark compares independent source files, not characters inside one file. Both paths use the same switch-case scanner.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label("Read the whole experiment", systemImage: "chart.bar.fill")
                        .font(.subheadline.weight(.bold))
                    Text("Warm-ups and repeated medians reduce noise. The verified badge matters more than a flattering speedup. Concurrent tasks may overlap, but the runtime does not promise one thread per task.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("If the concurrent number is slower, congratulations: you discovered overhead, which is also computer science.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 300, height: 320)
            .presentationCompactAdaptation(.popover)
        }
    }
}
