//
//  PerformanceView.swift
//  LexiDFA
//
//  Created by Amirali Yazdani on 10/13/26.
//

import SwiftUI

struct PerformanceView: View {
    @EnvironmentObject private var model: AppModel

    private let defaultJobCount = SampleProgram.allCases.count * 8

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenTitle(
                        eyebrow: "Concurrency Lab",
                        title: "Sequential vs concurrent",
                        subtitle: "Compare the switch-case DFA in a one-by-one batch with the concurrent TaskGroup batch scanner, using the selected language."
                    )

                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeader(
                                title: "Benchmark setup",
                                subtitle: "\(model.selectedLanguage.rawValue) samples · warm-up + median of repeated rounds.",
                                symbol: "bolt.horizontal.circle.fill"
                            )

                            HStack(spacing: 10) {
                                LabStat(title: "Jobs", value: "\(defaultJobCount)", color: .indigo)
                                LabStat(title: "Rounds", value: "\(BenchmarkEngine.defaultRounds)", color: .purple)
                                LabStat(title: "Workers", value: "\(ConcurrentBatchScanner.recommendedWorkerCount(for: defaultJobCount))", color: .cyan)
                            }

                            Text("Both strategies use the same switch-case DFA. The benchmark uses 32 independent jobs with a larger repeated source unit per job, and a bounded worker pool instead of creating one task for every tiny file. Trace-event and per-character state-path recording are disabled only during timed runs so the result focuses on lexical scanning rather than visualization allocations. The regular scanner still records the full trace.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Button {
                                model.benchmarkConcurrency()
                            } label: {
                                HStack {
                                    Image(systemName: model.benchmarkRunning ? "hourglass" : "play.fill")
                                    Text(model.benchmarkRunning ? "Benchmarking…" : "Run CPU Benchmark")
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                }
                                .fontWeight(.bold)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .buttonBorderShape(.roundedRectangle(radius: 15))
                            .disabled(model.benchmarkRunning)
                        }
                    }

                    if model.benchmarkRunning {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 12) {
                                    ProgressView()
                                        .controlSize(.large)
                                        .tint(.orange)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Benchmark in progress")
                                            .font(.headline)
                                        Text("Warming up workers, measuring both paths, and verifying output.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                VStack(spacing: 8) {
                                    Capsule().fill(Color.indigo.opacity(0.14)).frame(height: 12)
                                    Capsule().fill(Color.cyan.opacity(0.12)).frame(height: 12)
                                    Capsule().fill(Color.purple.opacity(0.10)).frame(height: 12)
                                }
                                .redacted(reason: .placeholder)
                                .accessibilityHidden(true)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if let benchmark = model.benchmark {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    SectionHeader(
                                        title: "Results",
                                        subtitle: "Median measured time",
                                        symbol: "chart.bar.fill"
                                    )
                                    Spacer(minLength: 0)
                                    PillBadge(
                                        text: benchmark.verified ? "Verified" : "Mismatch",
                                        color: benchmark.verified ? .green : .red,
                                        symbol: benchmark.verified ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                                    )
                                }

                                BenchmarkRow(title: "SequentialBatchScanner", duration: benchmark.sequential, color: .indigo)
                                BenchmarkRow(title: "ConcurrentBatchScanner", duration: benchmark.concurrent, color: .cyan)

                                Divider()

                                HStack(alignment: .bottom) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Relative speed")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(String(format: "%.2f×", benchmark.speedup))
                                            .font(.system(size: 38, weight: .bold, design: .rounded))
                                            .foregroundStyle(benchmark.speedup >= 1 ? .indigo : .orange)
                                    }

                                    Spacer(minLength: 12)

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Tokens processed")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("\(benchmark.tokens)")
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                    }
                                }

                                Text("\(benchmark.inputs) independent jobs · \(benchmark.totalCharacters.formatted()) source characters per round · \(benchmark.workers) bounded workers · \(benchmark.rounds) measured rounds")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(benchmark.verified ? "Verified: ordered token outputs match." : "Mismatch: the strategies produced different token output.")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(benchmark.verified ? .green : .red)

                                Text(benchmark.speedup >= 1.0
                                     ? String(format: "The concurrent pool was %.0f%% faster for this workload. Concurrency can use multiple cores, but the scheduler does not guarantee parallel execution.", (1 - (1 / max(benchmark.speedup, 0.000001))) * 100)
                                     : String(format: "The concurrent pool was %.0f%% slower for this workload; worker coordination still cost more than it saved. That's a valid result, not a failure.", (1 / max(benchmark.speedup, 0.000001) - 1) * 100))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Relative time")
                                    .font(.headline)
                                TimingBar(title: "Sequential", duration: benchmark.sequential, maximum: max(benchmark.sequential, benchmark.concurrent), color: .indigo)
                                TimingBar(title: "Concurrent", duration: benchmark.concurrent, maximum: max(benchmark.sequential, benchmark.concurrent), color: .cyan)
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(
                                title: "What is actually measured?",
                                subtitle: "Same workload, two execution strategies",
                                symbol: "arrow.triangle.branch"
                            )
                            Text("Current dialect: \(model.selectedLanguage.rawValue). SequentialBatchScanner uses a normal loop. ConcurrentBatchScanner uses a bounded Swift TaskGroup worker pool to scan independent source files concurrently and stores each result at its original index. Both paths call the same switch-case ScannerEngine. Timed scans skip only trace-event/state-path recording; token output is still compared in order. This measures batch lexer throughput, not parallel characters within one file.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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
                    LabQuickGuideButton()
                }
            }
        }
    }
}

struct LabStat: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(color.opacity(0.12), lineWidth: 1)
        }
    }
}

struct BenchmarkRow: View {
    let title: String
    let duration: Duration
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Spacer(minLength: 8)
            Text(duration.millisecondsText)
                .font(.system(.headline, design: .monospaced).weight(.semibold))
        }
    }
}

struct TimingBar: View {
    let title: String
    let duration: Duration
    let maximum: Duration
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(duration.millisecondsText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                let maxValue = BenchmarkEngine.durationSeconds(maximum)
                let current = BenchmarkEngine.durationSeconds(duration)
                let ratio = maxValue <= 0 ? 0 : min(max(current / maxValue, 0), 1)

                Capsule()
                    .fill(color.opacity(0.13))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.62)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: proxy.size.width * ratio)
                    }
                    .clipShape(Capsule())
            }
            .frame(height: 10)
        }
    }
}
