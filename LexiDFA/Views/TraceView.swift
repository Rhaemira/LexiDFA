//
//  TraceView.swift
//  LexiDFA
//
//  Created by Amirali Yazdani on 10/13/26.
//

import SwiftUI

struct TraceView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var tracePlayer: TracePlaybackModel

    var currentEvent: ScannerEvent? {
        model.result.events.indices.contains(tracePlayer.traceCursor) ? model.result.events[tracePlayer.traceCursor] : nil
    }

    var currentState: DFAState {
        guard let currentEvent else { return .start }
        return currentEvent.nextState ?? currentEvent.state
    }

    private let speeds: [Double] = [0.5, 1.0, 1.5, 2.0]

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenTitle(
                        eyebrow: "Execution Trace",
                        title: "Watch the DFA think",
                        subtitle: "Pause, resume, restart, and control playback speed while following each switch-case transition."
                    )

                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top, spacing: 20) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Current character")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(currentEvent?.character.map(String.init) ?? "—")
                                        .font(.system(size: 46, weight: .bold, design: .monospaced))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                }

                                Spacer(minLength: 10)

                                VStack(alignment: .trailing, spacing: 5) {
                                    Text("Current state")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(currentState.rawValue)
                                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                                        .foregroundStyle(stateColor(currentState))
                                }
                            }

                            if let event = currentEvent {
                                HStack(spacing: 8) {
                                    PillBadge(text: event.state.rawValue, color: stateColor(event.state))
                                    Image(systemName: "arrow.right")
                                        .foregroundStyle(.secondary)
                                    PillBadge(text: event.nextState?.rawValue ?? "accept", color: event.nextState.map { stateColor($0) } ?? .green)
                                }

                                Text(event.message)
                                    .font(.headline)
                                    .contentTransition(.opacity)

                                ProgressView(value: Double(tracePlayer.traceCursor + 1), total: Double(max(model.result.events.count, 1)))
                                    .tint(stateColor(currentState))
                            } else {
                                Text("Run the scanner to populate the execution trace.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            playbackControls
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(
                                title: "Event stream",
                                subtitle: "Tap any event to jump to that point.",
                                symbol: "list.bullet.rectangle.fill"
                            )

                            if model.result.events.isEmpty {
                                EmptyStateCard(title: "No trace yet", message: "Go to Scanner and run an input first.", symbol: "waveform.path.ecg")
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(model.result.events.indices, id: \.self) { index in
                                        let event = model.result.events[index]
                                        TraceRow(index: index, event: event, active: index == tracePlayer.traceCursor)
                                            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                                            .onTapGesture {
                                                withAnimation(.easeInOut(duration: 0.16)) {
                                                    model.selectTraceEvent(at: index)
                                                }
                                            }
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
                    TraceQuickActionsMenu()
                }
            }
        }
    }

    private var playbackControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    tracePlayer.resume(eventCount: model.result.events.count)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.caption.weight(.bold))
                        Text("Resume")
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .allowsTightening(true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 24)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .disabled(model.result.events.isEmpty || tracePlayer.isPlayingTrace)

                Button {
                    tracePlayer.pause()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pause.fill")
                            .font(.caption.weight(.bold))
                        Text("Pause")
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .allowsTightening(true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 24)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .disabled(model.result.events.isEmpty || !tracePlayer.isPlayingTrace)

                Button {
                    tracePlayer.restart(eventCount: model.result.events.count)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.headline.weight(.bold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .accessibilityLabel("Restart trace")
                .disabled(model.result.events.isEmpty)
            }

            HStack(spacing: 8) {
                Image(systemName: "speedometer")
                    .foregroundStyle(.purple)
                Text("Play speed")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 0)

                Picker("Play speed", selection: $tracePlayer.traceSpeed) {
                    ForEach(speeds, id: \.self) { speed in
                        Text(String(format: "%.1fx", speed)).tag(speed)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            HStack {
                Text("Playback")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(tracePlayer.isPlayingTrace ? "Playing" : "Paused")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tracePlayer.isPlayingTrace ? .green : .secondary)
                Spacer(minLength: 0)
                Text("\(min(tracePlayer.traceCursor + 1, model.result.events.count)) / \(model.result.events.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
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
        case .attribute: return .yellow
        case .error: return .red
        }
    }
}

struct TraceRow: View {
    let index: Int
    let event: ScannerEvent
    let active: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .trailing)

            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.message)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(event.state.rawValue) → \(event.nextState?.rawValue ?? "accept")")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(11)
        .background(
            active ? iconColor.opacity(0.11) : Color.primary.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(active ? iconColor.opacity(0.32) : Color.primary.opacity(0.05), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.16), value: active)
    }

    private var icon: String {
        switch event.kind {
        case .character: return "character.cursor.ibeam"
        case .transition: return "arrow.right.circle.fill"
        case .accept: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch event.kind {
        case .character: return .secondary
        case .transition: return .indigo
        case .accept: return .green
        case .error: return .red
        }
    }
}
