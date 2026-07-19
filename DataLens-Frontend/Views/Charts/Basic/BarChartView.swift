import SwiftUI
import Charts

/// BarChartView renders categorical metrics vertically with custom top rounded corners,
/// zoom/pan sliders, click selectors, and hover tooltips.
struct BarChartView: View {
    let config: ChartConfig
    let data: ChartData
    let colors: [Color]
    let highlightedSeries: Set<String>
    
    @State private var animationProgress = 0.0
    @State private var hoveredPoint: ChartDataPoint? = nil
    @State private var hoverLocation: CGPoint = .zero
    @State private var selectedPointId: UUID? = nil
    
    // Zoom/Pan Sliding window parameters
    @State private var zoomValue: Double = 1.0 // 1.0 = fully zoomed out, 0.1 = zoomed in (10% visible)
    @State private var scrollOffset: Double = 0.0 // 0.0 = start, 1.0 = end of pan
    
    var body: some View {
        let filteredPoints = data.points.filter { pt in
            highlightedSeries.isEmpty || highlightedSeries.contains(pt.series)
        }
        
        // Window calculations for Zoom & Pan
        let totalItems = filteredPoints.count
        let visibleCount = max(5, Int(Double(totalItems) * zoomValue))
        let maxStart = max(0, totalItems - visibleCount)
        let startIndex = min(maxStart, Int(Double(maxStart) * scrollOffset))
        let endIndex = min(totalItems, startIndex + visibleCount)
        
        let visiblePoints = Array(filteredPoints[startIndex..<endIndex])
        
        VStack(spacing: 12) {
            // Zoom & Pan Toolbar
            if totalItems > 10 {
                HStack(spacing: 20) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass.circle")
                            .foregroundColor(ColorPalette.textSecondary)
                        Slider(value: $zoomValue, in: 0.1...1.0)
                            .frame(width: 120)
                            .help("Scroll to zoom category density")
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left.and.right.square")
                            .foregroundColor(ColorPalette.textSecondary)
                        Slider(value: $scrollOffset, in: 0.0...1.0)
                            .frame(width: 120)
                            .help("Pan across categories")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(ColorPalette.cards.opacity(0.4))
                .cornerRadius(8)
            }
            
            // Primary Chart Canvas
            ZStack {
                Chart {
                    ForEach(visiblePoints) { point in
                        BarMark(
                            x: .value("Category", point.x),
                            y: .value("Value", point.y * animationProgress)
                        )
                        .foregroundStyle(by: .value("Series", point.series))
                        .cornerRadius(4)
                        .opacity(selectedPointId == nil || selectedPointId == point.id ? 1.0 : 0.4)
                    }
                }
                .chartForegroundStyleScale(
                    domain: data.seriesNames,
                    range: colors
                )
                .chartYAxis {
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
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel(anchor: .topTrailing) {
                            if let categoryName = value.as(String.self) {
                                Text(categoryName)
                                    .rotationEffect(.degrees(-45))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(ColorPalette.textSecondary)
                            }
                        }
                    }
                }
                // Interactive hover tracking and click detection
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    self.hoverLocation = location
                                    if let xVal: String = proxy.value(atX: location.x) {
                                        // Locate closest matching data point
                                        if let pt = visiblePoints.first(where: { $0.x == xVal }) {
                                            self.hoveredPoint = pt
                                        }
                                    }
                                case .ended:
                                    self.hoveredPoint = nil
                                }
                            }
                            .onTapGesture {
                                // Tap to toggle highlighting a specific bar
                                if let hovered = hoveredPoint {
                                    if selectedPointId == hovered.id {
                                        selectedPointId = nil
                                    } else {
                                        selectedPointId = hovered.id
                                    }
                                }
                            }
                    }
                }
                
                // Show tooltip view at current hover point
                if config.showTooltips, let pt = hoveredPoint {
                    let totalVal = visiblePoints.map { $0.y }.reduce(0, +)
                    let pctString = totalVal > 0 ? String(format: "%.1f%%", (pt.y / totalVal) * 100) : nil
                    
                    TooltipView(
                        title: pt.x,
                        value: pt.y.formatted(decimals: 2),
                        percentage: pctString
                    )
                    .position(x: min(max(hoverLocation.x, 80), 600), y: min(max(hoverLocation.y - 45, 40), 300))
                }
            }
        }
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
