import SwiftUI
import Charts

struct HeatmapView: View {
    let config: ChartConfig
    let data: ChartData
    let colors: [Color]
    let highlightedSeries: Set<String>
    @ObservedObject var chartViewModel: ChartViewModel
    
    @State private var hoverCell: HeatmapCell? = nil
    @State private var hoverLocation: CGPoint = .zero
    
    // Clicking a cell highlights its entire row and column
    @State private var selectedXLabel: String? = nil
    @State private var selectedYLabel: String? = nil
    
    var body: some View {
        let cells = chartViewModel.heatmapCells
        let xLabels = chartViewModel.heatmapXLabels
        let yLabels = chartViewModel.heatmapYLabels
        
        let numericValues = cells.compactMap { $0.value }
        let minVal = numericValues.min() ?? 0.0
        let maxVal = numericValues.max() ?? 100.0
        
        // Compute dynamic dimensions based on category counts to guarantee minimum 20pt size
        let minSize: CGFloat = 24.0
        let chartWidth = max(400, CGFloat(xLabels.count) * minSize)
        let chartHeight = max(300, CGFloat(yLabels.count) * minSize)
        
        HStack(alignment: .top, spacing: 16) {
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    Chart {
                        ForEach(cells) { cell in
                            let isHighlighted = (selectedXLabel == nil && selectedYLabel == nil) ||
                                                (cell.xLabel == selectedXLabel || cell.yLabel == selectedYLabel)
                            let isHovered = hoverCell?.id == cell.id
                            let baseColor = cellColor(for: cell.value, minVal: minVal, maxVal: maxVal, scale: config.heatmapColorScale)
                            
                            RectangleMark(
                                x: .value("X Category", cell.xLabel),
                                y: .value("Y Category", cell.yLabel)
                            )
                            .foregroundStyle(baseColor)
                            .opacity(isHighlighted ? (isHovered ? 1.0 : 0.85) : 0.25)
                            .annotation(position: .center) {
                                if config.showCellLabels, xLabels.count < 15, yLabels.count < 15 {
                                    if let val = cell.value {
                                        Text(val.formatted(decimals: 1))
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(textBrightness(for: baseColor))
                                    } else {
                                        Text("N/A")
                                            .font(.system(size: 8))
                                            .foregroundColor(ColorPalette.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(position: .bottom, values: .automatic) { value in
                            AxisValueLabel {
                                if let str = value.as(String.self) {
                                    Text(str)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(ColorPalette.textSecondary)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic) { value in
                            AxisValueLabel {
                                if let str = value.as(String.self) {
                                    Text(str)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(ColorPalette.textSecondary)
                                }
                            }
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onEnded { value in
                                            if let x: String = proxy.value(atX: value.location.x),
                                               let y: String = proxy.value(atY: value.location.y) {
                                                if selectedXLabel == x && selectedYLabel == y {
                                                    selectedXLabel = nil
                                                    selectedYLabel = nil
                                                } else {
                                                    selectedXLabel = x
                                                    selectedYLabel = y
                                                }
                                            }
                                        }
                                )
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active(let location):
                                        self.hoverLocation = location
                                        if let x: String = proxy.value(atX: location.x),
                                           let y: String = proxy.value(atY: location.y) {
                                            self.hoverCell = cells.first { $0.xLabel == x && $0.yLabel == y }
                                        }
                                    case .ended:
                                        self.hoverCell = nil
                                    }
                                }
                        }
                    }
                    .frame(width: chartWidth, height: chartHeight)
                    
                    // Tooltip display
                    if config.showTooltips, let cell = hoverCell {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(config.xAxisColumn ?? "X"): \(cell.xLabel)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(ColorPalette.textSecondary)
                            Text("\(config.seriesColumn ?? "Y"): \(cell.yLabel)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(ColorPalette.textSecondary)
                            HStack {
                                Text("Value:")
                                    .font(.system(size: 11))
                                    .foregroundColor(ColorPalette.textPrimary)
                                Spacer()
                                Text(cell.value?.formatted(decimals: 2) ?? "N/A")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(ColorPalette.success)
                            }
                            .frame(width: 120)
                        }
                        .padding(8)
                        .background(ColorPalette.cards)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorPalette.border, lineWidth: 1))
                        .shadow(radius: 4)
                        .position(x: min(max(hoverLocation.x, 80), chartWidth - 80), y: min(max(hoverLocation.y - 55, 45), chartHeight - 45))
                        .allowsHitTesting(false)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Legend Panel on the right (16pt wide gradient bar)
            VStack(spacing: 8) {
                Text(config.yAxisColumn ?? "Value")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(ColorPalette.textSecondary)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 20, height: 60)
                
                Text(maxVal.formatted(decimals: 1))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(ColorPalette.textPrimary)
                
                legendGradient(scale: config.heatmapColorScale)
                    .frame(width: 16, height: 180)
                    .cornerRadius(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(ColorPalette.border, lineWidth: 1)
                    )
                
                Text(minVal.formatted(decimals: 1))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(ColorPalette.textPrimary)
            }
            .padding(.trailing, 8)
            .padding(.top, 16)
        }
    }
    
    // MARK: - Color Interpolation Helpers
    
    private func cellColor(for val: Double?, minVal: Double, maxVal: Double, scale: HeatmapColorScale) -> Color {
        guard let val = val else { return Color(hex: "#2A2A4A") }
        let range = maxVal - minVal
        let normalized = range > 0 ? (val - minVal) / range : 0.5
        
        switch scale {
        case .cool:
            return Color.white.interpolate(to: Color(hex: "#00B4D8"), fraction: normalized)
        case .hot:
            return Color.white.interpolate(to: Color.red, fraction: normalized)
        case .purple:
            return Color.white.interpolate(to: Color(hex: "#533483"), fraction: normalized)
        case .diverging:
            if val < 0 {
                let negFraction = minVal < 0 ? val / minVal : 0.0
                return Color(hex: "#EF4444").interpolate(to: Color.white, fraction: 1.0 - negFraction)
            } else {
                let posFraction = maxVal > 0 ? val / maxVal : 0.0
                return Color.white.interpolate(to: Color(hex: "#00B4D8"), fraction: posFraction)
            }
        }
    }
    
    private func textBrightness(for color: Color) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        let luma = 0.299 * r + 0.587 * g + 0.114 * b
        return luma > 0.5 ? Color.black : Color.white
    }
    
    @ViewBuilder
    private func legendGradient(scale: HeatmapColorScale) -> some View {
        switch scale {
        case .cool:
            LinearGradient(colors: [.white, Color(hex: "#00B4D8")], startPoint: .bottom, endPoint: .top)
        case .hot:
            LinearGradient(colors: [.white, .red], startPoint: .bottom, endPoint: .top)
        case .purple:
            LinearGradient(colors: [.white, Color(hex: "#533483")], startPoint: .bottom, endPoint: .top)
        case .diverging:
            LinearGradient(colors: [Color(hex: "#EF4444"), .white, Color(hex: "#00B4D8")], startPoint: .bottom, endPoint: .top)
        }
    }
}

// Color interpolation extension
extension Color {
    func interpolate(to other: Color, fraction: Double) -> Color {
        let f = CGFloat(max(0.0, min(1.0, fraction)))
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        NSColor(self).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        NSColor(other).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        return Color(.sRGB,
            red: Double(r1 + (r2 - r1) * f),
            green: Double(g1 + (g2 - g1) * f),
            blue: Double(b1 + (b2 - b1) * f),
            opacity: Double(a1 + (a2 - a1) * f)
        )
    }
}
