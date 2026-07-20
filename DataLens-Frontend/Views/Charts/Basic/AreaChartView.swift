import SwiftUI
import Charts

// MARK: - Area Chart View

/// AreaChartView renders a filled area chart using Swift Charts AreaMark.
/// Extends line chart logic with:
/// - Gradient / flat fill modes
/// - Zero / Minimum / Custom baseline options
/// - Stacked and 100%-normalized stacked area layouts
/// - Zoom, pan, crosshair, and annotation support
struct AreaChartView: View {
    let config: ChartConfig
    let data: ChartData
    let colors: [Color]
    let highlightedSeries: Set<String>
    @ObservedObject var chartViewModel: ChartViewModel

    // MARK: Animation
    @State private var animationProgress: Double = 0.0
    @State private var lineVisible: Bool = false

    // MARK: Hover / Crosshair
    @State private var hoverX: String? = nil
    @State private var hoverLocation: CGPoint = .zero

    // MARK: Zoom / Pan
    @State private var zoomValue: Double = 1.0
    @State private var scrollOffset: Double = 0.0

    // MARK: Annotation state
    @State private var pendingAnnotationPoint: ChartDataPoint? = nil
    @State private var annotationDraft: String = ""
    @State private var showAnnotationInput: Bool = false

    var body: some View {
        let filteredPoints = visiblePoints()
        let seriesColors = colorMapping()

        // Pre-compute stacked values when in stacked modes
        let stackedData = computeStackedData(from: filteredPoints)

        VStack(spacing: 8) {
            // MARK: Zoom & Pan controls
            if data.points.count > 20 {
                ZoomPanControls(zoomValue: $zoomValue, scrollOffset: $scrollOffset)
            }

            // MARK: Chart Canvas
            ZStack(alignment: .topLeading) {
                Chart {
                    switch config.stackMode {
                    case .none:
                        // ── Standard area (one fill per series) ────────────
                        ForEach(data.seriesNames, id: \.self) { series in
                            let seriesPoints = filteredPoints.filter { $0.series == series }
                            let isMuted = !highlightedSeries.isEmpty && !highlightedSeries.contains(series)
                            let seriesColor = seriesColors[series] ?? colors.first ?? .blue

                            ForEach(seriesPoints) { pt in
                                let yBaseline = baseline(for: pt.y)
                                // Filled area
                                AreaMark(
                                    x: .value("X", pt.x),
                                    yStart: .value("Baseline", yBaseline),
                                    yEnd: .value("Y", pt.y * animationProgress)
                                )
                                .interpolationMethod(config.interpolationMode == .curved ? .catmullRom : .linear)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [seriesColor.opacity(0.40), seriesColor.opacity(0.0)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .opacity(isMuted ? 0.1 : 1.0)

                                // Line on top of fill
                                if lineVisible {
                                    LineMark(
                                        x: .value("X", pt.x),
                                        y: .value("Y", pt.y * animationProgress)
                                    )
                                    .interpolationMethod(config.interpolationMode == .curved ? .catmullRom : .linear)
                                    .foregroundStyle(seriesColor)
                                    .lineStyle(StrokeStyle(lineWidth: 2.0))
                                    .opacity(isMuted ? 0.2 : 1.0)
                                }
                            }
                        }

                    case .stacked, .normalized:
                        // ── Stacked area (each series sits on previous) ────
                        ForEach(data.seriesNames, id: \.self) { series in
                            let isMuted = !highlightedSeries.isEmpty && !highlightedSeries.contains(series)
                            let seriesColor = seriesColors[series] ?? colors.first ?? .blue
                            let seriesPoints = stackedData[series] ?? []

                            ForEach(seriesPoints) { sp in
                                AreaMark(
                                    x: .value("X", sp.x),
                                    yStart: .value("YStart", sp.yStart * animationProgress),
                                    yEnd: .value("YEnd", sp.yEnd * animationProgress)
                                )
                                .interpolationMethod(config.interpolationMode == .curved ? .catmullRom : .linear)
                                .foregroundStyle(seriesColor.opacity(0.7))
                                .opacity(isMuted ? 0.2 : 1.0)

                                if lineVisible {
                                    LineMark(
                                        x: .value("X", sp.x),
                                        y: .value("Y", sp.yEnd * animationProgress)
                                    )
                                    .interpolationMethod(config.interpolationMode == .curved ? .catmullRom : .linear)
                                    .foregroundStyle(seriesColor)
                                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                                    .opacity(isMuted ? 0.2 : 1.0)
                                }
                            }
                        }
                    }

                    // ── Average reference line ────────────────────────────
                    if config.showReferenceLines {
                        RuleMark(y: .value("Average", data.averageY))
                            .foregroundStyle(Color(hex: "#A0A0B0").opacity(0.8))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .annotation(position: .leading) {
                                Text("Avg: \(data.averageY.formatted(decimals: 1))")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Color(hex: "#A0A0B0"))
                            }
                    }

                    // ── Custom reference line ─────────────────────────────
                    if config.showReferenceLines, let customY = config.customReferenceLineValue {
                        RuleMark(y: .value("Custom", customY))
                            .foregroundStyle(Color(hex: "#F59E0B").opacity(0.75))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .annotation(position: .trailing) {
                                Text(config.customReferenceLineLabel ?? String(format: "%.1f", customY))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Color(hex: "#F59E0B"))
                            }
                    }

                    // ── Vertical crosshair ────────────────────────────────
                    if let hX = hoverX {
                        RuleMark(x: .value("Hover", hX))
                            .foregroundStyle(Color(hex: "#533483").opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { value in
                        if config.showGrid {
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7))
                                .foregroundStyle(Color(hex: "#2A2A4A").opacity(0.7))
                        }
                        AxisValueLabel {
                            if let d = value.as(Double.self) {
                                // Show percentage labels for 100% stacked mode
                                Text(config.stackMode == .normalized ? "\(Int(d))%" : d.formatted(decimals: 0))
                                    .font(.system(size: 10))
                                    .foregroundColor(ColorPalette.textSecondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel(anchor: .topTrailing) {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .rotationEffect(.degrees(-40))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(ColorPalette.textSecondary)
                            }
                        }
                    }
                }
                // ── Hover & click interaction ───────────────────────────
                .chartOverlay { proxy in
                    GeometryReader { _ in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let loc):
                                    hoverLocation = loc
                                    if let xStr: String = proxy.value(atX: loc.x) {
                                        hoverX = xStr
                                    }
                                case .ended:
                                    hoverX = nil
                                }
                            }
                            .onTapGesture { location in
                                if let xStr: String = proxy.value(atX: location.x) {
                                    if let pt = filteredPoints.first(where: { $0.x == xStr }) {
                                        pendingAnnotationPoint = pt
                                        annotationDraft = ""
                                        showAnnotationInput = true
                                    }
                                }
                            }
                    }
                }

                // ── Crosshair multi-series tooltip ────────────────────────
                if config.showTooltips, let hX = hoverX {
                    CrosshairTooltipView(
                        xLabel: hX,
                        points: filteredPoints.filter { $0.x == hX },
                        colors: seriesColors
                    )
                    .position(
                        x: min(max(hoverLocation.x + 12, 80), 650),
                        y: max(hoverLocation.y - 40, 40)
                    )
                    .allowsHitTesting(false)
                }

                // ── Annotation markers ──────────────────────────────────
                ForEach(chartViewModel.annotations) { ann in
                    AnnotationPinView(annotation: ann) {
                        chartViewModel.removeAnnotation(id: ann.id)
                    }
                }
            }
        }
        .sheet(isPresented: $showAnnotationInput) {
            AnnotationInputSheet(
                point: pendingAnnotationPoint,
                draft: $annotationDraft,
                onSave: { text in
                    if let pt = pendingAnnotationPoint {
                        chartViewModel.addAnnotation(at: pt, text: text)
                    }
                    showAnnotationInput = false
                },
                onCancel: { showAnnotationInput = false }
            )
        }
        .onAppear { startAnimation() }
        .onChange(of: data) { _ in restartAnimation() }
    }

    // MARK: - Stacked Point Model

    /// Helper struct for stacked area segments — provides yStart and yEnd for each X.
    private struct StackedPoint: Identifiable {
        let id = UUID()
        let x: String
        var yStart: Double
        var yEnd: Double
    }

    // MARK: - Stack Computation

    /// Builds stacked or normalized data from raw points.
    private func computeStackedData(from points: [ChartDataPoint]) -> [String: [StackedPoint]] {
        guard config.stackMode != .none else { return [:] }

        // Collect all unique X values in order
        let allX = Array(Set(points.map { $0.x })).sorted {
            if let da = Double($0), let db = Double($1) { return da < db }
            return $0 < $1
        }

        // Build cumulative Y per X across series in order
        var result: [String: [StackedPoint]] = [:]
        var cumulativeY: [String: Double] = [:] // X → running total

        // Compute total Y per X for 100% normalization
        var totalYPerX: [String: Double] = [:]
        if config.stackMode == .normalized {
            for pt in points {
                totalYPerX[pt.x, default: 0] += pt.y
            }
        }

        for series in data.seriesNames {
            let seriesMap: [String: Double] = Dictionary(
                points.filter { $0.series == series }.map { ($0.x, $0.y) },
                uniquingKeysWith: { first, _ in first }
            )
            var seriesStack: [StackedPoint] = []

            for xLabel in allX {
                let rawY = seriesMap[xLabel] ?? 0.0
                let normalizedY: Double
                if config.stackMode == .normalized, let total = totalYPerX[xLabel], total > 0 {
                    normalizedY = (rawY / total) * 100.0
                } else {
                    normalizedY = rawY
                }

                let yStart = cumulativeY[xLabel] ?? 0.0
                let yEnd = yStart + normalizedY
                cumulativeY[xLabel] = yEnd
                seriesStack.append(StackedPoint(x: xLabel, yStart: yStart, yEnd: yEnd))
            }

            result[series] = seriesStack
        }
        return result
    }

    // MARK: - Baseline

    /// Computes the yStart value for AreaMark based on baseline config.
    private func baseline(for yValue: Double) -> Double {
        switch config.baselineMode {
        case .zero: return 0.0
        case .minimum: return data.yRange.lowerBound
        case .custom: return config.customBaselineValue
        }
    }

    // MARK: - Zoom / Pan

    private func visiblePoints() -> [ChartDataPoint] {
        guard !data.points.isEmpty else { return [] }
        let allXLabels = Array(Set(data.points.map { $0.x }))
            .sorted { a, b in
                if let da = Double(a), let db = Double(b) { return da < db }
                return a < b
            }
        let total = allXLabels.count
        let visible = max(5, Int(Double(total) * zoomValue))
        let maxStart = max(0, total - visible)
        let start = min(maxStart, Int(Double(maxStart) * scrollOffset))
        let end = min(total, start + visible)
        let visibleLabels = Set(allXLabels[start..<end])
        return data.points.filter { visibleLabels.contains($0.x) }
    }

    private func colorMapping() -> [String: Color] {
        var map: [String: Color] = [:]
        for (i, series) in data.seriesNames.enumerated() {
            map[series] = colors[i % colors.count]
        }
        return map
    }

    // MARK: - Animation

    private func startAnimation() {
        animationProgress = 0
        lineVisible = false
        withAnimation(.easeInOut(duration: config.animationDuration)) {
            animationProgress = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + config.animationDuration) {
            withAnimation(.easeIn(duration: 0.25)) {
                lineVisible = true
            }
        }
    }

    private func restartAnimation() {
        animationProgress = 0
        lineVisible = false
        startAnimation()
    }
}

// MARK: - Zoom / Pan Sub-View (shared UI component)

private struct ZoomPanControls: View {
    @Binding var zoomValue: Double
    @Binding var scrollOffset: Double

    var body: some View {
        HStack(spacing: 20) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(ColorPalette.textSecondary)
                Slider(value: $zoomValue, in: 0.1...1.0)
                    .frame(width: 110)
            }
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 11))
                    .foregroundColor(ColorPalette.textSecondary)
                Slider(value: $scrollOffset, in: 0.0...1.0)
                    .frame(width: 110)
            }
            Button("Reset") {
                withAnimation { zoomValue = 1.0; scrollOffset = 0.0 }
            }
            .font(.system(size: 11, weight: .semibold))
            .buttonStyle(.plain)
            .foregroundColor(ColorPalette.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(ColorPalette.cards.opacity(0.4))
        .cornerRadius(8)
    }
}

// MARK: - Crosshair Multi-Series Tooltip

private struct CrosshairTooltipView: View {
    let xLabel: String
    let points: [ChartDataPoint]
    let colors: [String: Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(xLabel)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(ColorPalette.textSecondary)
                .padding(.bottom, 2)
            ForEach(points) { pt in
                HStack(spacing: 6) {
                    Circle()
                        .fill(colors[pt.series] ?? .white)
                        .frame(width: 6, height: 6)
                    Text(pt.series)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(ColorPalette.textSecondary)
                    Spacer()
                    Text(pt.y.formatted(decimals: 2))
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(ColorPalette.textPrimary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(ColorPalette.cards)
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorPalette.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
        .frame(minWidth: 120)
    }
}

// MARK: - Annotation Pin Marker

private struct AnnotationPinView: View {
    let annotation: ChartAnnotation
    let onDelete: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 2) {
            if isExpanded {
                HStack(spacing: 6) {
                    Text(annotation.text)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(ColorPalette.textPrimary)
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#0F3460"))
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(ColorPalette.border, lineWidth: 1))
            }
            Circle()
                .fill(Color(hex: "#F59E0B"))
                .frame(width: 8, height: 8)
                .onTapGesture { withAnimation { isExpanded.toggle() } }
        }
    }
}

// MARK: - Annotation Input Sheet

private struct AnnotationInputSheet: View {
    let point: ChartDataPoint?
    @Binding var draft: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Annotation")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ColorPalette.textPrimary)
            if let pt = point {
                HStack(spacing: 8) {
                    Text("Point:")
                        .foregroundColor(ColorPalette.textSecondary)
                    Text("\(pt.x)  →  \(pt.y.formatted(decimals: 2))")
                        .foregroundColor(ColorPalette.textPrimary)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            TextField("Enter annotation text…", text: $draft)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .secondaryStyle()
                Button("Save Annotation") {
                    guard !draft.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    onSave(draft)
                }
                .primaryStyle()
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(32)
        .background(ColorPalette.background)
        .frame(width: 360, height: 220)
    }
}
