import SwiftUI
import Charts

/// BubbleChartView extends ScatterPlotView with a third size-mapping dimension,
/// optional fourth color-gradient scale, density grids, and sorting overlays.
struct BubbleChartView: View {
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
        let minMaxSize = numericSizeBounds(for: filteredPoints)
        let minMaxColor = numericColorBounds(for: filteredPoints)
        
        // Sorting: larger bubbles first so smaller bubbles render on top of them
        let sortedPoints = filteredPoints.sorted { a, b in
            let sa = a.sizeValue ?? 0.0
            let sb = b.sizeValue ?? 0.0
            return sa > sb
        }
        
        VStack(spacing: 8) {
            // Selection feedback
            if !chartViewModel.selectedScatterPoints.isEmpty {
                HStack {
                    Image(systemName: "bubbles.and.sparkles.fill")
                        .foregroundColor(ColorPalette.success)
                    Text("\(chartViewModel.selectedScatterPoints.count) bubbles selected")
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
                Chart {
                    ForEach(sortedPoints) { pt in
                        if let dx = Double(pt.x) {
                            let sizeVal = pt.sizeValue ?? 0.0
                            let diam = diameter(for: sizeVal, minSize: minMaxSize.min, maxSize: minMaxSize.max)
                            let isSelected = chartViewModel.selectedScatterPoints.contains(pt.id)
                            let hoverFactor = (hoverPoint?.id == pt.id) ? 1.5 : 1.0
                            
                            // Map Y value, size, and optional gradient color
                            PointMark(
                                x: .value("X", dx),
                                y: .value("Y", pt.y)
                            )
                            .symbolSize(pow(diam * hoverFactor, 2))
                            .foregroundStyle(bubbleStyle(for: pt, isSelected: isSelected, minVal: minMaxColor.min, maxVal: minMaxColor.max))
                            .opacity(0.70) // Semi-transparent overlap
                            
                            // Text labels inside bubble if diameter is large enough (> 20pt)
                            if config.showDataLabels && diam > 20.0 {
                                PointMark(
                                    x: .value("X", dx),
                                    y: .value("Y", pt.y)
                                )
                                .annotation(position: .center) {
                                    Text(pt.series)
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
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
                                            updateDragSelection(proxy: proxy, bounds: geo.size, points: sortedPoints)
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
                                            self.hoverPoint = findClosestPoint(x: xDouble, y: yDouble, in: sortedPoints)
                                        }
                                    case .ended:
                                        self.hoverPoint = nil
                                    }
                                }
                            
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
                
                // Tooltip displays bubble values
                if config.showTooltips, let pt = hoverPoint {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Row \(pt.rawIndex ?? 0) — \(pt.series)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(ColorPalette.textSecondary)
                        Text("\(config.xAxisColumn ?? "X"): \(Double(pt.x)?.formatted(decimals: 2) ?? pt.x)")
                        Text("\(config.yAxisColumn ?? "Y"): \(pt.y.formatted(decimals: 2))")
                        if let sVal = pt.sizeValue {
                            Text("\(config.bubbleSizeColumn ?? "Size"): \(sVal.formatted(decimals: 2))")
                        }
                        if let cVal = pt.colorValue {
                            Text("\(config.bubbleColorColumn ?? "Color"): \(cVal.formatted(decimals: 2))")
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
            
            // Size and Color scale legends
            HStack(spacing: 40) {
                // Size scale legend
                HStack(spacing: 12) {
                    Text("Bubble Size:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    HStack(spacing: 8) {
                        Circle().stroke(ColorPalette.textSecondary, lineWidth: 1.5).frame(width: 8, height: 8)
                        Text(minMaxSize.min.formatted(decimals: 1)).font(.system(size: 10))
                        Circle().stroke(ColorPalette.textSecondary, lineWidth: 1.5).frame(width: 18, height: 18)
                        Text(((minMaxSize.min + minMaxSize.max)/2).formatted(decimals: 1)).font(.system(size: 10))
                        Circle().stroke(ColorPalette.textSecondary, lineWidth: 1.5).frame(width: 28, height: 28)
                        Text(minMaxSize.max.formatted(decimals: 1)).font(.system(size: 10))
                    }
                }
                
                // Color scale legend
                if config.bubbleColorColumn != nil {
                    HStack(spacing: 8) {
                        Text("Color Value:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(ColorPalette.textSecondary)
                        Text(minMaxColor.min.formatted(decimals: 1)).font(.system(size: 10))
                        LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                            .frame(width: 100, height: 10)
                            .cornerRadius(2)
                        Text(minMaxColor.max.formatted(decimals: 1)).font(.system(size: 10))
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Mathematical mappings
    
    private func diameter(for sizeValue: Double, minSize: Double, maxSize: Double) -> CGFloat {
        if sizeValue <= 0 { return 6.0 } // Negative or zero maps to minimum ring
        let range = maxSize - minSize
        guard range > 0 else { return 20.0 }
        // Scale diameter between 6pt and 40pt
        return 6.0 + CGFloat((sizeValue - minSize) / range) * 34.0
    }
    
    private func bubbleStyle(for pt: ChartDataPoint, isSelected: Bool, minVal: Double, maxVal: Double) -> AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color(hex: "#00B4D8"))
        }
        
        // If color column is mapped, return a gradient value interpolating the theme
        if let colorVal = pt.colorValue, colors.count > 1 {
            let range = maxVal - minVal
            let pct = range > 0 ? (colorVal - minVal) / range : 0.5
            let index = Int(pct * Double(colors.count - 1))
            return AnyShapeStyle(colors[max(0, min(colors.count - 1, index))])
        }
        
        // Fallback to series colors
        if let idx = data.seriesNames.firstIndex(of: pt.series) {
            return AnyShapeStyle(colors[idx % colors.count])
        }
        return AnyShapeStyle(colors.first ?? ColorPalette.accent)
    }
    
    // MARK: - Bounds utilities
    
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
    
    private func numericSizeBounds(for pts: [ChartDataPoint]) -> (min: Double, max: Double) {
        let values = pts.compactMap { $0.sizeValue }
        return (values.min() ?? 0.0, values.max() ?? 10.0)
    }
    
    private func numericColorBounds(for pts: [ChartDataPoint]) -> (min: Double, max: Double) {
        let values = pts.compactMap { $0.colorValue }
        return (values.min() ?? 0.0, values.max() ?? 10.0)
    }
    
    private func findClosestPoint(x: Double, y: Double, in pts: [ChartDataPoint]) -> ChartDataPoint? {
        guard !pts.isEmpty else { return nil }
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
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y))
        
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
