import SwiftUI
import Charts

/// HorizontalBarChartView renders categorical metrics horizontally (left to right),
/// with auto-sorting descending options, rank numbering, zoom, and interactive tooltips.
struct HorizontalBarChartView: View {
    let config: ChartConfig
    let data: ChartData
    let colors: [Color]
    let highlightedSeries: Set<String>
    
    @EnvironmentObject var crossFilterManager: CrossFilterManager
    
    @State private var animationProgress = 0.0
    @State private var hoveredPoint: ChartDataPoint? = nil
    @State private var hoverLocation: CGPoint = .zero
    @State private var selectedPointId: UUID? = nil
    
    var body: some View {
        let filteredPoints = data.points.filter { pt in
            highlightedSeries.isEmpty || highlightedSeries.contains(pt.series)
        }
        
        // Auto sort descending by value if autoSort configuration is enabled
        let sortedPoints = config.autoSort ? filteredPoints.sorted { $0.y > $1.y } : filteredPoints
        
        // Build map for ranking indices
        let rankedPoints: [(index: Int, point: ChartDataPoint)] = Array(sortedPoints.enumerated()).map { ($0.offset + 1, $0.element) }
        
        Chart {
            ForEach(rankedPoints, id: \.point.id) { item in
                let categoryLabel = config.autoSort ? "\(item.index). \(item.point.x)" : item.point.x
                
                BarMark(
                    x: .value("Value", item.point.y * animationProgress),
                    y: .value("Category", categoryLabel)
                )
                .foregroundStyle(by: .value("Series", item.point.series))
                .cornerRadius(4)
                .opacity(selectedPointId == nil || selectedPointId == item.point.id ? 1.0 : 0.3) // 30% opacity for non-matching
            }
        }
        .chartForegroundStyleScale(
            domain: data.seriesNames,
            range: colors
        )
        .chartXAxis {
            if config.showGrid {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8))
                        .foregroundStyle(Color(hex: "#2A2A4A").opacity(0.8))
                    AxisValueLabel()
                        .foregroundStyle(ColorPalette.textSecondary)
                }
            } else {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .foregroundStyle(ColorPalette.textSecondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(ColorPalette.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        // Hover and selection interaction overlays
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            self.hoverLocation = location
                            // Map hover back to y position category
                            if let categoryVal: String = proxy.value(atY: location.y) {
                                // Strip rank prefix if autoSort is active
                                var rawX = categoryVal
                                if config.autoSort, let dotIndex = categoryVal.firstIndex(of: " ") {
                                    rawX = String(categoryVal[categoryVal.index(after: dotIndex)...])
                                }
                                
                                if let item = rankedPoints.first(where: { $0.point.x == rawX }) {
                                    self.hoveredPoint = item.point
                                }
                            }
                        case .ended:
                            self.hoveredPoint = nil
                        }
                    }
                    .onTapGesture {
                        if let hovered = hoveredPoint {
                            if selectedPointId == hovered.id {
                                selectedPointId = nil
                                if let col = config.xAxisColumn {
                                    crossFilterManager.activeFilters.removeAll { $0.sourceChartId == config.id && $0.columnName == col }
                                }
                            } else {
                                selectedPointId = hovered.id
                                if let col = config.xAxisColumn {
                                    let filter = CrossFilter(
                                        sourceChartId: config.id,
                                        columnName: col,
                                        filterType: .categorical(values: [hovered.x]),
                                        label: "\(col): \(hovered.x)"
                                    )
                                    crossFilterManager.addFilter(filter)
                                }
                            }
                        }
                    }
            }
        }
        .overlay(
            Group {
                if config.showTooltips, let pt = hoveredPoint {
                    let totalVal = sortedPoints.map { $0.y }.reduce(0, +)
                    let pctString = totalVal > 0 ? String(format: "%.1f%%", (pt.y / totalVal) * 100) : nil
                    
                    TooltipView(
                        title: pt.x,
                        value: pt.y.formatted(decimals: 2),
                        percentage: pctString
                    )
                    .position(x: min(max(hoverLocation.x, 80), 600), y: min(max(hoverLocation.y - 45, 40), 300))
                }
            }
        )
        .onAppear {
            withAnimation(.easeOut(duration: config.animationDuration)) {
                animationProgress = 1.0
            }
        }
        .onChange(of: data) { _ in
            animationProgress = 0.0
            withAnimation(.easeOut(duration: config.animationDuration)) {
                animationProgress = 1.0
            }
        }
    }
}
