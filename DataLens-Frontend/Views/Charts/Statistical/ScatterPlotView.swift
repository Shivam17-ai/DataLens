import SwiftUI
import Charts

/// ScatterPlotView renders points using PointMark, and features polynomial/linear trend line fits,
/// mean-based quadrant bounds, coordinate overlays, and multi-point drag selector rectangle.
struct ScatterPlotView: View {
    let config: ChartConfig
    let data: ChartData
    let colors: [Color]
    let highlightedSeries: Set<String>
    @ObservedObject var chartViewModel: ChartViewModel
    
    @State private var hoverPoint: ChartDataPoint? = nil
    @State private var hoverLocation: CGPoint = .zero
    @State private var dragStart: CGPoint? = nil
    @State private var dragEnd: CGPoint? = nil
    
    var body: some View {
        let filteredPoints = data.points.filter { pt in
            highlightedSeries.isEmpty || highlightedSeries.contains(pt.series)
        }
        
        let minMaxX = numericXBounds(for: filteredPoints)
        let minMaxY = numericYBounds(for: filteredPoints)
        
        VStack(spacing: 8) {
            // Selection stats bar
            if !chartViewModel.selectedScatterPoints.isEmpty {
                HStack {
                    Image(systemName: "hand.tap.fill")
                        .foregroundColor(ColorPalette.success)
                    Text("\(chartViewModel.selectedScatterPoints.count) points selected")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ColorPalette.textPrimary)
                    Spacer()
                    Button("Clear Selection") {
                        chartViewModel.selectedScatterPoints.removeAll()
                    }
                    .font(.system(size: 11, weight: .bold))
                    .buttonStyle(.plain)
                    .foregroundColor(Color(hex: "#EF4444"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(ColorPalette.cards.opacity(0.4))
                .cornerRadius(6)
            }
            
            ZStack(alignment: .topLeading) {
                // Quadrant background colors (underlaid)
                if config.showQuadrantLines && !filteredPoints.isEmpty {
                    quadrantBackgrounds(minX: minMaxX.min, maxX: minMaxX.max, minY: minMaxY.min, maxY: minMaxY.max)
                }
                
                Chart {
                    // Scatter Points
                    ForEach(filteredPoints) { pt in
                        if let dx = Double(pt.x) {
                            let isSelected = chartViewModel.selectedScatterPoints.contains(pt.id)
                            let scaleRatio = (hoverPoint?.id == pt.id) ? 14.0 : 8.0
                            
                            PointMark(
                                x: .value("X", dx),
                                y: .value("Y", pt.y)
                            )
                            .symbolSize(pow(scaleRatio, 2))
                            .foregroundStyle(isSelected ? Color(hex: "#00B4D8") : seriesColor(for: pt.series))
                            // Outlined border effect
                            .symbol(Circle().stroke(lineWidth: 1.0))
                        }
                    }
                    
                    // Regression/Trend Line
                    if config.showTrendLine && config.trendLineType != .none {
                        ForEach(chartViewModel.trendLineData.points) { tPt in
                            if let dx = Double(tPt.x) {
                                LineMark(
                                    x: .value("X", dx),
                                    y: .value("Y", tPt.y)
                                )
                                .foregroundStyle(Color(hex: "#F59E0B"))
                                .lineStyle(StrokeStyle(lineWidth: 2.0, dash: [4, 3]))
                            }
                        }
                    }
                    
                    // Mean Quadrant lines
                    if config.showQuadrantLines && !filteredPoints.isEmpty {
                        let avgX = filteredPoints.compactMap { Double($0.x) }.reduce(0.0, +) / Double(max(1, filteredPoints.count))
                        let avgY = filteredPoints.map { $0.y }.reduce(0.0, +) / Double(max(1, filteredPoints.count))
                        
                        RuleMark(x: .value("Mean X", avgX))
                            .foregroundStyle(ColorPalette.textSecondary.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1.0, dash: [6, 4]))
                        
                        RuleMark(y: .value("Mean Y", avgY))
                            .foregroundStyle(ColorPalette.textSecondary.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1.0, dash: [6, 4]))
                    }
                }
                .chartXScale(domain: config.zeroOrigin ? 0...minMaxX.max : minMaxX.min...minMaxX.max)
                .chartYScale(domain: config.zeroOrigin ? 0...minMaxY.max : minMaxY.min...minMaxY.max)
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        if config.showGrid {
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7))
                                .foregroundStyle(ColorPalette.border.opacity(0.5))
                        }
                        AxisValueLabel()
                            .foregroundStyle(ColorPalette.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { value in
                        if config.showGrid {
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7))
                                .foregroundStyle(ColorPalette.border.opacity(0.5))
                        }
                        AxisValueLabel()
                            .foregroundStyle(ColorPalette.textSecondary)
                    }
                }
                // Interactive hover tracking and drag bounds selector
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 4)
                                        .onChanged { value in
                                            if dragStart == nil {
                                                dragStart = value.startLocation
                                            }
                                            dragEnd = value.location
                                            updateDragSelection(proxy: proxy, bounds: geo.size, points: filteredPoints)
                                        }
                                        .onEnded { _ in
                                            dragStart = nil
                                            dragEnd = nil
                                        }
                                )
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active(let location):
                                        self.hoverLocation = location
                                        if let xDouble: Double = proxy.value(atX: location.x),
                                           let yDouble: Double = proxy.value(atY: location.y) {
                                            self.hoverPoint = findClosestPoint(x: xDouble, y: yDouble, in: filteredPoints)
                                        }
                                    case .ended:
                                        self.hoverPoint = nil
                                    }
                                }
                            
                            // Visual drag selection box
                            if let start = dragStart, let end = dragEnd {
                                Rectangle()
                                    .fill(ColorPalette.success.opacity(0.12))
                                    .overlay(Rectangle().stroke(ColorPalette.success, lineWidth: 1.5))
                                    .frame(width: abs(start.x - end.x), height: abs(start.y - end.y))
                                    .offset(x: min(start.x, end.x), y: min(start.y, end.y))
                            }
                        }
                    }
                }
                
                // Trend Line formula overlay in bottom left
                if config.showTrendLine && config.trendLineType != .none {
                    VStack {
                        Spacer()
                        HStack {
                            Text(String(format: "R² = %.4f", chartViewModel.trendLineData.rSquared))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(ColorPalette.textSecondary)
                                .padding(8)
                                .background(ColorPalette.cards.opacity(0.85))
                                .cornerRadius(5)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(ColorPalette.border, lineWidth: 1))
                                .padding(12)
                            Spacer()
                        }
                    }
                    .allowsHitTesting(false)
                }
                
                // Hover point tooltip representation
                if config.showTooltips, let pt = hoverPoint {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Row \(pt.rawIndex ?? 0)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(ColorPalette.textSecondary)
                        
                        Text("\(config.xAxisColumn ?? "X"): \(Double(pt.x)?.formatted(decimals: 2) ?? pt.x)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ColorPalette.textPrimary)
                        
                        Text("\(config.yAxisColumn ?? "Y"): \(pt.y.formatted(decimals: 2))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ColorPalette.textPrimary)
                        
                        if config.seriesColumn != nil {
                            Text("Category: \(pt.series)")
                                .font(.system(size: 10))
                                .foregroundColor(seriesColor(for: pt.series))
                        }
                    }
                    .padding(8)
                    .background(ColorPalette.cards)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorPalette.border, lineWidth: 1))
                    .shadow(radius: 4)
                    .position(x: min(max(hoverLocation.x, 80), 550), y: min(max(hoverLocation.y - 60, 45), 320))
                    .allowsHitTesting(false)
                }
            }
        }
    }
    
    // MARK: - Quadrants Background Layout
    
    @ViewBuilder
    private func quadrantBackgrounds(minX: Double, maxX: Double, minY: Double, maxY: Double) -> some View {
        // Subtle background division representing quadrants
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Quadrant II (top-left)
                ZStack {
                    Color.purple.opacity(0.015)
                    Text("II").font(.system(size: 18, weight: .black)).foregroundColor(ColorPalette.textSecondary.opacity(0.12))
                }
                // Quadrant I (top-right)
                ZStack {
                    Color.blue.opacity(0.02)
                    Text("I").font(.system(size: 18, weight: .black)).foregroundColor(ColorPalette.textSecondary.opacity(0.12))
                }
            }
            HStack(spacing: 0) {
                // Quadrant III (bottom-left)
                ZStack {
                    Color.red.opacity(0.01)
                    Text("III").font(.system(size: 18, weight: .black)).foregroundColor(ColorPalette.textSecondary.opacity(0.12))
                }
                // Quadrant IV (bottom-right)
                ZStack {
                    Color.green.opacity(0.015)
                    Text("IV").font(.system(size: 18, weight: .black)).foregroundColor(ColorPalette.textSecondary.opacity(0.12))
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Interactive Helpers
    
    private func seriesColor(for series: String) -> Color {
        if let idx = data.seriesNames.firstIndex(of: series) {
            return colors[idx % colors.count]
        }
        return colors.first ?? ColorPalette.accent
    }
    
    private func numericXBounds(for pts: [ChartDataPoint]) -> (min: Double, max: Double) {
        let values = pts.compactMap { Double($0.x) }
        let minVal = values.min() ?? 0.0
        let maxVal = values.max() ?? 10.0
        let padding = max(0.5, (maxVal - minVal) * 0.08)
        return (minVal - padding, maxVal + padding)
    }
    
    private func numericYBounds(for pts: [ChartDataPoint]) -> (min: Double, max: Double) {
        let values = pts.map { $0.y }
        let minVal = values.min() ?? 0.0
        let maxVal = values.max() ?? 10.0
        let padding = max(0.5, (maxVal - minVal) * 0.08)
        return (minVal - padding, maxVal + padding)
    }
    
    private func findClosestPoint(x: Double, y: Double, in pts: [ChartDataPoint]) -> ChartDataPoint? {
        guard !pts.isEmpty else { return nil }
        // Find point that minimizes euclidean distance in numeric space
        return pts.min { a, b in
            let ax = Double(a.x) ?? 0.0
            let bx = Double(b.x) ?? 0.0
            let distA = pow(ax - x, 2) + pow(a.y - y, 2)
            let distB = pow(bx - x, 2) + pow(b.y - y, 2)
            return distA < distB
        }
    }
    
    private func updateDragSelection(proxy: ChartProxy, bounds: CGSize, points: [ChartDataPoint]) {
        guard let start = dragStart, let end = dragEnd else { return }
        
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(start.x - end.x),
            height: abs(start.y - end.y)
        )
        
        var selected = Set<UUID>()
        for pt in points {
            if let dx = Double(pt.x),
               let pos = proxy.position(for: (x: dx, y: pt.y)) {
                if rect.contains(pos) {
                    selected.insert(pt.id)
                }
            }
        }
        
        chartViewModel.selectedScatterPoints = selected
    }
}
