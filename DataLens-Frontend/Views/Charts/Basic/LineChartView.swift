import SwiftUI
import Charts

// MARK: - Line Chart View

/// LineChartView renders a multi-series line chart with Swift Charts LineMark.
/// Features: curved/straight interpolation, data-point circles, hover crosshair,
/// reference lines, zoom/pan sliders, data labels, and pinned annotations.
struct LineChartView: View {
    let config: ChartConfig
    let data: ChartData
    let colors: [Color]
    let highlightedSeries: Set<String>
    @ObservedObject var chartViewModel: ChartViewModel

    // MARK: Animation
    @State private var animationProgress: Double = 0.0
    @State private var pointsVisible: Bool = false

    // MARK: Hover / Crosshair
    @State private var hoverX: String? = nil
    @State private var hoverLocation: CGPoint = .zero

    // MARK: Zoom / Pan
    @State private var zoomValue: Double = 1.0
    @State private var scrollOffset: Double = 0.0

    // MARK: Annotation State
    @State private var pendingAnnotationPoint: ChartDataPoint? = nil
    @State private var annotationDraft: String = ""
    @State private var showAnnotationInput: Bool = false

    var body: some View {
        let filteredPoints = visiblePoints()
        let seriesColors = colorMapping()
        let averageY = data.averageY

        VStack(spacing: 8) {
            // MARK: Zoom & Pan controls (only if dataset is large)
            if data.points.count > 20 {
                ZoomPanControls(zoomValue: $zoomValue, scrollOffset: $scrollOffset)
            }

            // MARK: Chart Canvas
            ZStack(alignment: .topLeading) {
                Chart {
                    // ── Line marks per series ──────────────────────────────
                    ForEach(data.seriesNames, id: \.self) { series in
                        let seriesPoints = filteredPoints.filter { $0.series == series }
                        let isMuted = !highlightedSeries.isEmpty && !highlightedSeries.contains(series)

                        ForEach(seriesPoints) { pt in
                            // Line path
                            LineMark(
                                x: .value("X", pt.x),
                                y: .value("Y", pt.y * animationProgress)
                            )
                            .interpolationMethod(config.interpolationMode == .curved ? .catmullRom : .linear)
                            .foregroundStyle(seriesColors[series] ?? colors.first ?? .blue)
                            .opacity(isMuted ? 0.2 : 1.0)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))

                            // Data point circles
                            if pointsVisible {
                                PointMark(
                                    x: .value("X", pt.x),
                                    y: .value("Y", pt.y * animationProgress)
                                )
                                .symbolSize(hoverX == pt.x ? 80 : 28)   // hover: 10pt (√80≈9pt), normal: 6pt (√28≈5pt)
                                .foregroundStyle(seriesColors[series] ?? colors.first ?? .blue)
                                .opacity(isMuted ? 0.2 : 1.0)
                            }

                            // Optional data labels above each point
                            if config.showDataLabels && pointsVisible {
                                PointMark(
                                    x: .value("X", pt.x),
                                    y: .value("Y", pt.y * animationProgress)
                                )
                                .opacity(0)
                                .annotation(position: .top) {
                                    Text(pt.y.formatted(decimals: 1))
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(ColorPalette.textSecondary)
                                        .opacity(isMuted ? 0.2 : 1.0)
                                }
                            }
                        }
                    }

                    // ── Average reference line ────────────────────────────
                    if config.showReferenceLines {
                        RuleMark(y: .value("Average", averageY))
                            .foregroundStyle(Color(hex: "#A0A0B0").opacity(0.8))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .annotation(position: .leading) {
                                Text("Avg: \(averageY.formatted(decimals: 1))")
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

                    // ── Vertical crosshair at hover X ────────────────────
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
                        AxisValueLabel()
                            .foregroundStyle(ColorPalette.textSecondary)
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
                // Scale Y axis to override if set
                .chartYScale(
                    domain: yDomain()
                )
                // ── Hover & Click interaction overlay ─────────────────────
                .chartOverlay { proxy in
                    GeometryReader { geo in
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
                                // Detect nearest data point to tap for annotation
                                if let xStr: String = proxy.value(atX: location.x) {
                                    if let point = filteredPoints.first(where: { $0.x == xStr }) {
                                        pendingAnnotationPoint = point
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

                // ── Pinned annotation markers ──────────────────────────────
                ForEach(chartViewModel.annotations) { ann in
                    AnnotationPinView(annotation: ann) {
                        chartViewModel.removeAnnotation(id: ann.id)
                    }
                }
            }
        }
        // ── Annotation text input sheet ────────────────────────────────────
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

    // MARK: - Helpers

    /// Returns the visible window of data points respecting zoom/pan sliders.
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

    /// Builds a color map: seriesName → Color from the theme palette.
    private func colorMapping() -> [String: Color] {
        var map: [String: Color] = [:]
        for (i, series) in data.seriesNames.enumerated() {
            map[series] = colors[i % colors.count]
        }
        return map
    }

    /// Returns the Y domain range, respecting optional min/max overrides.
    private func yDomain() -> ClosedRange<Double> {
        let lower = config.yAxisMinOverride ?? (data.yRange.lowerBound - abs(data.yRange.lowerBound) * 0.05)
        let upper = config.yAxisMaxOverride ?? (data.yRange.upperBound + abs(data.yRange.upperBound) * 0.05)
        guard lower < upper else { return 0...1 }
        return lower...upper
    }

    /// Starts the draw-left-to-right animation, then fades in points.
    private func startAnimation() {
        animationProgress = 0
        pointsVisible = false
        withAnimation(.easeInOut(duration: config.animationDuration)) {
            animationProgress = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + config.animationDuration) {
            withAnimation(.easeIn(duration: 0.3)) {
                pointsVisible = true
            }
        }
    }

    private func restartAnimation() {
        animationProgress = 0
        pointsVisible = false
        startAnimation()
    }
}

// MARK: - Zoom/Pan Controls

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
                    .help("Zoom: adjust visible range of X axis")
            }
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 11))
                    .foregroundColor(ColorPalette.textSecondary)
                Slider(value: $scrollOffset, in: 0.0...1.0)
                    .frame(width: 110)
                    .help("Pan across X axis")
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
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(ColorPalette.border, lineWidth: 1)
        )
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
                // Annotation card
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
            // Amber pin
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
