import SwiftUI
import Charts

/// DonutChartView renders proportional fanning sectors with a center hole.
/// Supports selection text switches, side-by-side comparison mode, and inner metrics rings.
struct DonutChartView: View {
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
                    VStack {
                        Text(config.yAxisColumn ?? "Primary Metric")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ColorPalette.textSecondary)
                        donutCanvas(for: data, isComparison: false)
                    }
                    
                    VStack {
                        Text(config.comparisonColumn ?? "Comparison Metric")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ColorPalette.textSecondary)
                        donutCanvas(for: comparisonData(), isComparison: true)
                    }
                }
            } else {
                donutCanvas(for: data, isComparison: false)
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
    
    // MARK: - Donut Canvas
    
    @ViewBuilder
    private func donutCanvas(for chartData: ChartData, isComparison: Bool) -> some View {
        let slices = PieSliceBase.buildSlices(from: chartData, config: config, colors: colors)
        let filteredSlices = slices.filter { slice in
            highlightedSeries.isEmpty || highlightedSeries.contains(slice.point.series)
        }
        
        // Optionally show secondary metric breakdown in the inner ring
        let showInnerRing = config.comparisonColumn != nil && !isComparison
        let secondarySlices = showInnerRing ? PieSliceBase.buildSlices(from: comparisonData(), config: config, colors: colors.reversed()) : []
        
        GeometryReader { geo in
            let centerSize = min(geo.size.width, geo.size.height)
            
            ZStack {
                Chart {
                    // Outer Ring: Main Metric
                    ForEach(filteredSlices) { slice in
                        let isExploded = config.explodeAll || hoveredSliceId == slice.id || clickedSliceId == slice.id
                        
                        SectorMark(
                            angle: .value("Value", slice.point.y * animationProgress),
                            innerRadius: .ratio(0.55),
                            outerRadius: .ratio(isExploded ? 0.98 : 0.90),
                            angularInset: 1.0
                        )
                        .foregroundStyle(slice.color)
                        .offset(x: isExploded ? slice.dx : 0, y: isExploded ? slice.dy : 0)
                        .annotation(position: .overlay) {
                            if slice.percentage > 0.05 && animationProgress == 1.0 {
                                Text(String(format: "%.0f%%", slice.percentage * 100))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            }
                        }
                    }
                    
                    // Inner Ring: Secondary Metric (Comparison helper)
                    if showInnerRing {
                        ForEach(secondarySlices) { secSlice in
                            SectorMark(
                                angle: .value("SecondaryValue", secSlice.point.y * animationProgress),
                                innerRadius: .ratio(0.42),
                                outerRadius: .ratio(0.48),
                                angularInset: 0.5
                            )
                            .foregroundStyle(secSlice.color.opacity(0.85))
                        }
                    }
                }
                .chartOverlay { proxy in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                self.hoverLocation = location
                                if let angle: Double = proxy.value(atAngle: location) {
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
                
                // Center Overlay Circle
                Circle()
                    .fill(Color(hex: "#0F3460")) // Cards color match
                    .frame(width: centerSize * 0.49, height: centerSize * 0.49)
                    .shadow(color: .black.opacity(0.3), radius: 3)
                
                // Center Text Content
                VStack(spacing: 4) {
                    let activeId = clickedSliceId ?? hoveredSliceId
                    if let activeId = activeId, let slice = filteredSlices.first(where: { $0.id == activeId }) {
                        // Hovered/Selected slice details
                        Text(slice.point.x)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(ColorPalette.textSecondary)
                            .lineLimit(1)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                        
                        Text(slice.point.y.formatted(decimals: 1))
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(slice.color)
                        
                        Text(String(format: "%.1f%%", slice.percentage * 100))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(ColorPalette.textSecondary)
                    } else {
                        // General Summary display
                        Text(centerTitleLabel())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(ColorPalette.textSecondary)
                        
                        Text(centerValueLabel(for: chartData))
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(ColorPalette.textPrimary)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.spring(response: 0.25, dampingFraction: 0.85), value: hoveredSliceId)
                .animation(.spring(response: 0.25, dampingFraction: 0.85), value: clickedSliceId)
                
                // Tooltip Overlay
                if config.showTooltips, let hoveredId = hoveredSliceId, let slice = filteredSlices.first(where: { $0.id == hoveredId }) {
                    let pctString = String(format: "%.1f%%", slice.percentage * 100)
                    
                    TooltipView(
                        title: slice.point.x,
                        value: slice.point.y.formatted(decimals: 2),
                        percentage: pctString
                    )
                    .position(x: min(max(hoverLocation.x, 80), geo.size.width - 80), y: min(max(hoverLocation.y - 45, 40), geo.size.height - 40))
                }
            }
        }
    }
    
    // MARK: - Center Label Handlers
    
    private func centerTitleLabel() -> String {
        switch config.donutCenterText {
        case .totalValue: return "Total Value"
        case .totalCount: return "Categories"
        case .percentage: return "Percentage"
        case .customText: return config.customCenterText.isEmpty ? "Info" : config.customCenterText
        }
    }
    
    private func centerValueLabel(for chartData: ChartData) -> String {
        switch config.donutCenterText {
        case .totalValue:
            let sum = chartData.points.map { $0.y }.reduce(0, +)
            return sum.formatted(decimals: 1)
        case .totalCount:
            return "\(chartData.points.count)"
        case .percentage:
            return "100.0%"
        case .customText:
            return config.customCenterText
        }
    }
    
    // MARK: - Utilities
    
    private func findSlice(for angle: Double, in slices: [PieSliceItem]) -> PieSliceItem? {
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
