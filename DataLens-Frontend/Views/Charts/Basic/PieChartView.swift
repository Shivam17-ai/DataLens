import SwiftUI
import Charts

/// PieChartView renders categories as proportional fanning slices.
/// Supports sequential fanning, hover & click explosion offsets, leader annotations,
/// and side-by-side comparison mode.
struct PieChartView: View {
    let config: ChartConfig
    let data: ChartData
    let colors: [Color]
    let highlightedSeries: Set<String>
    @ObservedObject var chartViewModel: ChartViewModel
    @EnvironmentObject var dataViewModel: DataViewModel
    
    @State private var animationProgress = 0.0
    @State private var hoveredSliceId: UUID? = nil
    @State private var clickedSliceId: UUID? = nil
    @State private var hoverLocation: CGPoint = .zero
    
    var body: some View {
        let hasComparison = config.comparisonColumn != nil && !(config.comparisonColumn?.isEmpty ?? true)
        
        VStack(spacing: 12) {
            if hasComparison {
                HStack(spacing: 32) {
                    // Primary Metric Donut/Pie
                    VStack {
                        Text(config.yAxisColumn ?? "Primary Metric")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ColorPalette.textSecondary)
                        
                        pieCanvas(for: data)
                    }
                    
                    // Comparison Metric Donut/Pie
                    VStack {
                        Text(config.comparisonColumn ?? "Comparison Metric")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ColorPalette.textSecondary)
                        
                        pieCanvas(for: comparisonData())
                    }
                }
            } else {
                pieCanvas(for: data)
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
    
    // MARK: - Single Pie Canvas
    
    @ViewBuilder
    private func pieCanvas(for chartData: ChartData) -> some View {
        let slices = PieSliceBase.buildSlices(from: chartData, config: config, colors: colors)
        let filteredSlices = slices.filter { slice in
            highlightedSeries.isEmpty || highlightedSeries.contains(slice.point.series)
        }
        
        ZStack {
            Chart {
                ForEach(filteredSlices) { slice in
                    let isExploded = config.explodeAll || hoveredSliceId == slice.id || clickedSliceId == slice.id
                    
                    SectorMark(
                        angle: .value("Value", slice.point.y * animationProgress),
                        innerRadius: .ratio(0.0),
                        outerRadius: .ratio(isExploded ? 0.98 : 0.90),
                        angularInset: 1.0
                    )
                    .foregroundStyle(slice.color)
                    .offset(x: isExploded ? slice.dx : 0, y: isExploded ? slice.dy : 0)
                    // Inside label (only if >5% share)
                    .annotation(position: .overlay) {
                        if slice.percentage > 0.05 && animationProgress == 1.0 {
                            Text(String(format: "%.0f%%", slice.percentage * 100))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                self.hoverLocation = location
                                if let angle: Double = proxy.value(atAngle: location) {
                                    // Match angle to calculated slices
                                    // Sector angle in Swift Charts maps from 0 to 360 degrees
                                    let normalizedAngle = angle.truncatingRemainder(dividingBy: 360.0)
                                    if let match = findSlice(for: normalizedAngle, in: filteredSlices) {
                                        self.hoveredSliceId = match.id
                                        chartViewModel.selectedSlice = match.point
                                    }
                                }
                            case .ended:
                                self.hoveredSliceId = nil
                            }
                        }
                        .onTapGesture {
                            if let hoveredId = hoveredSliceId {
                                if clickedSliceId == hoveredId {
                                    clickedSliceId = nil
                                } else {
                                    clickedSliceId = hoveredId
                                }
                            }
                        }
                }
            }
            
            // Custom leaders / tooltip rendering when slice is hovered
            if config.showTooltips, let hoveredId = hoveredSliceId, let slice = filteredSlices.first(where: { $0.id == hoveredId }) {
                let totalVal = chartData.points.map { $0.y }.reduce(0, +)
                let pctString = String(format: "%.1f%%", slice.percentage * 100)
                
                TooltipView(
                    title: slice.point.x,
                    value: slice.point.y.formatted(decimals: 2),
                    percentage: pctString
                )
                .position(x: min(max(hoverLocation.x, 80), 550), y: min(max(hoverLocation.y - 45, 40), 320))
            }
            
            // Outer Leader labels for clicked or highlighted slices
            ForEach(filteredSlices) { slice in
                if clickedSliceId == slice.id || config.explodeAll {
                    let rad = slice.midAngle * .pi / 180.0
                    // Outer radius offset for label positioning
                    let labelRadius = 140.0
                    let labelX = cos(rad) * labelRadius
                    let labelY = sin(rad) * labelRadius
                    
                    VStack(alignment: .center, spacing: 2) {
                        Text(slice.point.x)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(ColorPalette.textPrimary)
                        Text(slice.point.y.formatted(decimals: 1))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(ColorPalette.success)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(ColorPalette.cards)
                    .cornerRadius(5)
                    .shadow(radius: 2)
                    .offset(x: CGFloat(labelX), y: CGFloat(labelY))
                }
            }
        }
    }
    
    // MARK: - Utilities
    
    private func findSlice(for angle: Double, in slices: [PieSliceItem]) -> PieSliceItem? {
        // Handle startAngle offset shifts
        var targetAngle = angle
        if targetAngle < 0 { targetAngle += 360 }
        
        return slices.first { slice in
            var start = slice.startAngle.truncatingRemainder(dividingBy: 360.0)
            if start < 0 { start += 360 }
            var end = slice.endAngle.truncatingRemainder(dividingBy: 360.0)
            if end < 0 { end += 360 }
            
            if start <= end {
                return targetAngle >= start && targetAngle <= end
            } else {
                // Crosses 360 wrap line
                return targetAngle >= start || targetAngle <= end
            }
        }
    }
    
    private func comparisonData() -> ChartData {
        guard let dataset = dataViewModel.currentDataSet, let compCol = config.comparisonColumn else {
            return ChartData()
        }
        var tempConfig = config
        tempConfig.yAxisColumn = compCol
        return chartViewModel.preparePieData(dataset: dataset, config: tempConfig)
    }
}
