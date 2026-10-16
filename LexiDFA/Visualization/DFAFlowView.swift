//
//  DFAFlowView.swift
//  LexiDFA
//
//  Created by Amirali Yazdani on 10/13/26.
//

import SwiftUI

struct DFAFlowView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var tracePlayer: TracePlaybackModel

    let activeState: DFAState
    var activeTransition: (DFAState, DFAState)? = nil
    @Binding var showAllTransitionLabels: Bool

    private let workspaceWidth: CGFloat = 1180
    private let workspaceHeight: CGFloat = 650
    private let nodeRadius: CGFloat = 37

    @State private var selectedState: DFAState?
    @State private var selectedTransitionID: UUID?
    @State private var zoom: CGFloat = 0.34
    @State private var fitZoom: CGFloat = 0.34
    @State private var pan = CGSize.zero
    @State private var zoomGestureStart: CGFloat?
    @State private var dragGestureStart: CGSize?
    @State private var didInitialFit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Pinch · drag to explore", systemImage: "hand.draw")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Button { zoom = max(minimumZoom, zoom / 1.22) } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .accessibilityLabel("Zoom out")
                Button { zoom = min(2.0, zoom * 1.22) } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .accessibilityLabel("Zoom in")
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        zoom = fitZoom
                        pan = .zero
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .accessibilityLabel("Reset DFA zoom and position")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        }

                    graphWorkspace
                        .frame(width: workspaceWidth, height: workspaceHeight)
                        .scaleEffect(zoom, anchor: .center)
                        .offset(pan)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            if zoomGestureStart == nil { zoomGestureStart = zoom }
                            let startingZoom = zoomGestureStart ?? zoom
                            zoom = min(max(startingZoom * value.magnification, minimumZoom), 2.0)
                        }
                        .onEnded { _ in zoomGestureStart = nil }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 7)
                        .onChanged { value in
                            if dragGestureStart == nil { dragGestureStart = pan }
                            let start = dragGestureStart ?? pan
                            pan = CGSize(
                                width: start.width + value.translation.width,
                                height: start.height + value.translation.height
                            )
                        }
                        .onEnded { _ in dragGestureStart = nil }
                )
                .onAppear {
                    guard !didInitialFit else { return }
                    didInitialFit = true
                    fitZoom = fittedZoom(for: proxy.size)
                    zoom = fitZoom
                }
                .overlay(alignment: .bottomLeading) {
                    Text("\(Int((zoom * 100).rounded()))%")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                        .padding(10)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 410)

            if let state = selectedState {
                SelectionInfoCard(
                    title: "Inspected state",
                    primary: "\(state.rawValue) · \(state.title)",
                    detail: stateDescription(state),
                    color: stateColor(state),
                    symbol: state.accepting ? "checkmark.circle.fill" : (state == .error ? "xmark.octagon.fill" : "circle.fill")
                )
            } else if let transition = selectedTransition {
                SelectionInfoCard(
                    title: "Inspected transition",
                    primary: "\(transition.from.rawValue) → \(transition.to.rawValue)",
                    detail: "Input: \(transition.label)",
                    color: stateColor(transition.to),
                    symbol: "arrow.right.circle.fill"
                )
            } else if let event = currentEvent {
                let eventState = event.nextState ?? event.state
                SelectionInfoCard(
                    title: event.nextState == nil ? "Current trace state" : "Current trace transition",
                    primary: event.nextState.map { "\(event.state.rawValue) → \($0.rawValue)" }
                        ?? "\(eventState.rawValue) · \(eventState.title)",
                    detail: event.message,
                    color: stateColor(eventState),
                    symbol: event.nextState == nil
                        ? (eventState.accepting ? "checkmark.circle.fill" : "circle.fill")
                        : "arrow.right.circle.fill"
                )
            } else {
                Label("Tap a state or transition to inspect it.", systemImage: "hand.tap.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 3)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: selectedState)
        .animation(.easeInOut(duration: 0.18), value: selectedTransitionID)
        .onChange(of: tracePlayer.traceCursor) { _, _ in clearManualSelection() }
        .onChange(of: tracePlayer.selectionVersion) { _, _ in clearManualSelection() }
        .onChange(of: model.result.events.count) { _, _ in clearManualSelection() }
    }

    private var minimumZoom: CGFloat { max(0.16, fitZoom * 0.68) }

    private func fittedZoom(for size: CGSize) -> CGFloat {
        let widthScale = max(size.width - 18, 1) / workspaceWidth
        let heightScale = max(size.height - 18, 1) / workspaceHeight
        return min(max(min(widthScale, heightScale) * 0.97, 0.20), 0.50)
    }

    private var graphWorkspace: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                let positions = makePositions()
                for transition in DFAState.transitions {
                    guard let from = positions[transition.from], let to = positions[transition.to] else { continue }
                    let active = isActive(transition.from, transition.to) || selectedTransitionID == transition.id
                    drawTransition(&context, transition: transition, from: from, to: to, active: active)
                }
            }
            .allowsHitTesting(false)

            let positions = makePositions()
            ForEach(DFAState.transitions) { transition in
                let active = isActive(transition.from, transition.to)
                let selected = selectedTransitionID == transition.id
                if showAllTransitionLabels || active || selected {
                    if let point = labelPosition(for: transition, positions: positions) {
                        TransitionButton(
                            transition: transition,
                            active: active,
                            selected: selected,
                            color: stateColor(transition.to)
                        ) {
                            withAnimation(.snappy(duration: 0.22)) {
                                selectedTransitionID = transition.id
                                selectedState = nil
                            }
                        }
                        .position(point)
                    }
                }
            }

            ForEach(DFAState.allCases) { state in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        selectedState = state
                        selectedTransitionID = nil
                    }
                } label: {
                    StateNode(
                        state: state,
                        active: state == activeState,
                        selected: selectedState == state,
                        color: stateColor(state)
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel("State \(state.rawValue), \(state.title)")
                .position(positions[state] ?? .zero)
            }
        }
        .frame(width: workspaceWidth, height: workspaceHeight)
    }

    private func clearManualSelection() {
        guard selectedState != nil || selectedTransitionID != nil else { return }
        withAnimation(.snappy(duration: 0.18)) {
            selectedState = nil
            selectedTransitionID = nil
        }
    }

    private var currentEvent: ScannerEvent? {
        model.result.events.indices.contains(tracePlayer.traceCursor) ? model.result.events[tracePlayer.traceCursor] : nil
    }

    private var selectedTransition: DFATransition? {
        guard let selectedTransitionID else { return nil }
        return DFAState.transitions.first(where: { $0.id == selectedTransitionID })
    }

    private func makePositions() -> [DFAState: CGPoint] {
        [
            .start: CGPoint(x: 72, y: 320),
            .identifier: CGPoint(x: 270, y: 145),
            .number: CGPoint(x: 270, y: 330),
            .string: CGPoint(x: 485, y: 105),
            .characterLiteral: CGPoint(x: 485, y: 265),
            .operatorState: CGPoint(x: 485, y: 440),
            .delimiter: CGPoint(x: 705, y: 145),
            .comment: CGPoint(x: 705, y: 315),
            .blockComment: CGPoint(x: 705, y: 485),
            .preprocessor: CGPoint(x: 935, y: 205),
            .attribute: CGPoint(x: 935, y: 420),
            .error: CGPoint(x: 1110, y: 320)
        ]
    }

    private func isActive(_ from: DFAState, _ to: DFAState) -> Bool {
        guard let activeTransition else { return false }
        return activeTransition.0 == from && activeTransition.1 == to
    }

    private func curveAmount(for state: DFAState) -> CGFloat {
        switch state {
        case .identifier: return -28
        case .number: return 28
        case .string: return -105
        case .characterLiteral: return -55
        case .operatorState: return 95
        case .delimiter: return -185
        case .comment: return 145
        case .blockComment: return 235
        case .preprocessor: return -280
        case .attribute: return 270
        case .error: return 0
        case .start: return 0
        }
    }

    private func loopIsTop(for state: DFAState) -> Bool {
        switch state {
        case .identifier, .string, .delimiter, .preprocessor:
            return true
        case .number, .characterLiteral, .operatorState, .comment, .blockComment, .attribute:
            return false
        case .start, .error:
            return true
        }
    }

    private func drawTransition(_ context: inout GraphicsContext, transition: DFATransition, from: CGPoint, to: CGPoint, active: Bool) {
        let color = stateColor(transition.to)
        let strokeColor = active ? color : Color.secondary.opacity(0.10)
        if from == to {
            drawLoop(&context, center: from, color: strokeColor, active: active, top: loopIsTop(for: transition.from))
            return
        }

        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = max(sqrt(dx * dx + dy * dy), 1)
        let ux = dx / length
        let uy = dy / length
        let start = CGPoint(x: from.x + ux * (nodeRadius + 4), y: from.y + uy * (nodeRadius + 4))
        let end = CGPoint(x: to.x - ux * (nodeRadius + 6), y: to.y - uy * (nodeRadius + 6))
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let control = CGPoint(x: mid.x - uy * curveAmount(for: transition.to), y: mid.y + ux * curveAmount(for: transition.to))

        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: active ? 3.4 : 1.5, lineCap: .round, lineJoin: .round))
        drawArrowHead(&context, at: end, direction: CGPoint(x: end.x - control.x, y: end.y - control.y), color: strokeColor, active: active)
    }

    private func drawLoop(_ context: inout GraphicsContext, center: CGPoint, color: Color, active: Bool, top: Bool) {
        let start = CGPoint(x: center.x + 20, y: center.y + (top ? -30 : 30))
        let end = CGPoint(x: center.x - 20, y: center.y + (top ? -30 : 30))
        let controlY = center.y + (top ? -82 : 82)
        var path = Path()
        path.move(to: start)
        path.addCurve(to: end, control1: CGPoint(x: center.x + 84, y: controlY), control2: CGPoint(x: center.x - 84, y: controlY))
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: active ? 3.4 : 1.5, lineCap: .round))
        drawArrowHead(&context, at: end, direction: CGPoint(x: end.x - (center.x - 84), y: end.y - controlY), color: color, active: active)
    }

    private func drawArrowHead(_ context: inout GraphicsContext, at point: CGPoint, direction: CGPoint, color: Color, active: Bool) {
        let angle = atan2(direction.y, direction.x)
        let length: CGFloat = 11
        let left = CGPoint(x: point.x - length * cos(angle - .pi / 6), y: point.y - length * sin(angle - .pi / 6))
        let right = CGPoint(x: point.x - length * cos(angle + .pi / 6), y: point.y - length * sin(angle + .pi / 6))
        var arrow = Path()
        arrow.move(to: point); arrow.addLine(to: left)
        arrow.move(to: point); arrow.addLine(to: right)
        context.stroke(arrow, with: .color(color), style: StrokeStyle(lineWidth: active ? 2.8 : 1.4, lineCap: .round))
    }

    private func labelPosition(for transition: DFATransition, positions: [DFAState: CGPoint]) -> CGPoint? {
        guard let from = positions[transition.from], let to = positions[transition.to] else { return nil }
        if from == to {
            // Alternate loop lanes by column/row so loop labels don't sit on top
            // of a neighboring state's label when full-label mode is enabled.
            let top = loopIsTop(for: transition.from)
            return CGPoint(x: from.x, y: from.y + (top ? -76 : 76))
        }
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = max(sqrt(dx * dx + dy * dy), 1)
        let ux = dx / length
        let uy = dy / length
        let start = CGPoint(x: from.x + ux * (nodeRadius + 4), y: from.y + uy * (nodeRadius + 4))
        let end = CGPoint(x: to.x - ux * (nodeRadius + 6), y: to.y - uy * (nodeRadius + 6))
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let curve = curveAmount(for: transition.to) * 0.72
        let control = CGPoint(x: mid.x - uy * curve, y: mid.y + ux * curve)
        return CGPoint(x: (start.x + 2 * control.x + end.x) / 4, y: (start.y + 2 * control.y + end.y) / 4)
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

    private func stateDescription(_ state: DFAState) -> String {
        switch state {
        case .start: return "Initial state. Classifies the next input character."
        case .identifier: return "Consumes letters, digits and underscores; known words are classified as keywords."
        case .number: return "Consumes integer and basic floating-point forms, including decimal points and exponents."
        case .string: return "Consumes double-quoted text and escaped characters."
        case .operatorState: return "Recognizes operators using longest-match rules."
        case .delimiter: return "Accepts punctuation and grouping delimiters."
        case .comment: return "Consumes a // comment until the next newline."
        case .characterLiteral: return "Consumes a single-quoted character literal and escapes."
        case .blockComment: return "Consumes /* ... */ comments; nested block comments are supported for Swift mode."
        case .preprocessor: return "Consumes a # directive from the start of a line."
        case .attribute: return "Consumes a Swift @attribute name."
        case .error: return "Represents an unknown symbol or an unterminated literal/comment."
        }
    }
}

struct TransitionButton: View {
    let transition: DFATransition
    let active: Bool
    let selected: Bool
    let color: Color
    let action: () -> Void

    private var displayLabel: String {
        switch transition.label {
        case "letter / _": return "A–Z / _"
        case "digit": return "0–9"
        case "double quote": return "\""
        case "apostrophe": return "'"
        case "operator char": return "operator"
        case "punctuation": return "punctuation"
        case "unknown char": return "unknown"
        case "# at line start": return "# line start"
        case "@name (Swift)": return "@name"
        case "letter / digit / _": return "A–Z / 0–9 / _"
        case "digit / decimal / exponent": return "digits / . / exp"
        case "character / escape / quote": return "chars / escapes"
        case "character / escape / apostrophe": return "chars / escapes"
        case "longest operator match": return "longest match"
        case "until newline": return "to newline"
        case "until */ (nested in Swift)": return "until */"
        case "attribute name": return "attribute name"
        default: return transition.label
        }
    }

    var body: some View {
        Button(action: action) {
            Text(displayLabel)
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 128)
                .foregroundStyle(active || selected ? color : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selected ? color.opacity(0.19) : Color(uiColor: .secondarySystemBackground), in: Capsule())
                .overlay { Capsule().strokeBorder(selected ? color.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: selected ? 1.5 : 1) }
                .shadow(color: selected ? color.opacity(0.18) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityLabel("Transition from \(transition.from.rawValue) to \(transition.to.rawValue): \(transition.label)")
        .scaleEffect(selected ? 1.03 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: selected)
        .animation(.easeInOut(duration: 0.18), value: active)
    }
}

struct SelectionInfoCard: View {
    let title: String
    let primary: String
    let detail: String
    let color: Color
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Text(primary)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        .padding(11)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(color.opacity(0.14), lineWidth: 1) }
    }
}

struct StateNode: View {
    let state: DFAState
    let active: Bool
    let selected: Bool
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [color.opacity(active || selected ? 0.30 : 0.12), color.opacity(active || selected ? 0.13 : 0.035)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 76, height: 76)
                    .overlay { Circle().strokeBorder(color.opacity(active || selected ? 0.92 : 0.24), lineWidth: active || selected ? 3 : 1.2) }
                    .overlay {
                        if state.accepting {
                            Circle().strokeBorder(color.opacity(active || selected ? 0.72 : 0.20), lineWidth: 4).frame(width: 64, height: 64)
                        }
                    }
                    .shadow(color: active ? color.opacity(0.28) : .clear, radius: 15)
                VStack(spacing: 1) {
                    Text(state.rawValue)
                        .font(.system(.headline, design: .monospaced).weight(.bold))
                        .foregroundStyle(.primary)
                    Image(systemName: state.accepting ? "checkmark" : (state == .error ? "xmark" : "play.fill"))
                        .font(.caption2.weight(.black))
                        .foregroundStyle(color)
                }
            }
            Text(state.title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: 98)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 108, height: 114)
        .contentShape(Rectangle())
        .scaleEffect(active ? 1.06 : (selected ? 1.03 : 1))
        .animation(.spring(response: 0.32, dampingFraction: 0.75), value: active)
        .animation(.spring(response: 0.30, dampingFraction: 0.78), value: selected)
    }
}
