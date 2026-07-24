import SwiftUI
import Charts

struct WaterfallChartView: View {
    let config: ChartConfig
    let data: ChartData
    let colors: [Color]
    let highlightedSeries: Set<String>
    @ObservedObject var chartViewModel: ChartViewModel
    
    @State private var hoverBar: WaterfallBar? = nil
    @State private var hoverLocation: CGPoint = .zero
    @State private var selectedBar: WaterfallBar? = nil
    
    var body: some View {
        let bars = chartViewModel.waterfallBars
        let runningTotals = bars.map { $0.runningTotal }
        let minY = min(0.0, runningTotals.min() ?? 0.0)
        let maxY = max(10.0, runningTotals.max() ?? 10.0) * 1.1
        
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                Chart {
                    ForEach(bars) { bar in
                        let isHovered = hoverBar?.id == bar.id
                        let barColor = getBarColor(bar: bar)
                        
                        // Floating Bar
                        BarMark(
                            x: .value("Category", bar.label),
                            yStart: .value("Start Y", yStart(for: bar)),
                            yEnd: .value("End Y", bar.runningTotal),
                            width: 32
                        )
                        .foregroundStyle(barColor)
                        .opacity(isHovered ? 1.0 : 0.85)
                        .cornerRadius(4)
                        .annotation(position: .top) {
                            if config.showCellLabels {
                                Text(labelValue(for: bar))
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(ColorPalette.textPrimary)
                            }
                        }
                    }
                    
                    // Optional Running Total Trend Line
                    if config.showRunningTotalLine {
                        ForEach(bars) { bar in
                            LineMark(
                                x: .value("Category", bar.label),
                                y: .value("Running Total", bar.runningTotal)
                            )
                            .foregroundStyle(ColorPalette.accent)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                        }
                        
                        ForEach(bars) { bar in
                            PointMark(
                                x: .value("Category", bar.label),
                                y: .value("Running Total", bar.runningTotal)
                            )
                            .foregroundStyle(.white)
                            .symbol(Circle())
                            .symbolSize(20)
                        }
                    }
                }
                .chartYScale(domain: minY...maxY)
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
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel()
                            .foregroundStyle(ColorPalette.textSecondary)
                    }
                }
                // Custom drawing overlay for horizontal connector lines
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        if config.showWaterfallConnectors, bars.count > 1 {
                            Path { path in
                                for i in 0..<(bars.count - 1) {
                                    let barA = bars[i]
                                    let barB = bars[i+1]
                                    let connectY = barA.runningTotal
                                    
                                    if let posA = proxy.position(for: (x: barA.label, y: connectY)),
                                       let posB = proxy.position(for: (x: barB.label, y: connectY)) {
                                        path.move(to: posA)
                                        path.addLine(to: posB)
                                    }
                                }
                            }
                            .stroke(ColorPalette.textSecondary, style: StrokeStyle(lineWidth: 1.0, dash: [4, 3]))
                            .opacity(0.6)
                        }
                        
                        // Hit testing for hover tooltip
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let hover = hoverBar {
                                    selectedBar = hover
                                }
                            }
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    self.hoverLocation = location
                                    if let cat: String = proxy.value(atX: location.x) {
                                        self.hoverBar = bars.first { $0.label == cat }
                                    }
                                case .ended:
                                    self.hoverBar = nil
                                }
                            }
                    }
                }
                
                // Tooltip Card
                if config.showTooltips, let bar = hoverBar {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(bar.label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(ColorPalette.textSecondary)
                        HStack {
                            Text("Change:")
                                .font(.system(size: 10))
                                .foregroundColor(ColorPalette.textSecondary)
                            Spacer()
                            Text((bar.changeValue >= 0 ? "+" : "") + bar.changeValue.formatted(decimals: 2))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(bar.changeValue >= 0 ? ColorPalette.success : .red)
                        }
                        .frame(width: 140)
                        HStack {
                            Text("Running Total:")
                                .font(.system(size: 10))
                                .foregroundColor(ColorPalette.textSecondary)
                            Spacer()
                            Text(bar.runningTotal.formatted(decimals: 2))
                                .font(.system(size: 10, weight: .bold))
                        }
                        .frame(width: 140)
                    }
                    .padding(8)
                    .background(ColorPalette.cards)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorPalette.border, lineWidth: 1))
                    .shadow(radius: 4)
                    .position(x: min(max(hoverLocation.x, 90), 550), y: min(max(hoverLocation.y - 50, 45), 250))
                    .allowsHitTesting(false)
                }
            }
            
            // Detailed breakdown card when bar clicked
            if let active = selectedBar {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(active.label)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ColorPalette.textPrimary)
                        Text(active.isTotal ? "Total Aggregation" : (active.isSubtotal ? "Subtotal Interval" : "Sequential Delta Change"))
                            .font(.system(size: 9))
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Running Total")
                            .font(.system(size: 9))
                            .foregroundColor(ColorPalette.textSecondary)
                        Text(active.runningTotal.formatted(decimals: 2))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(ColorPalette.textPrimary)
                    }
                    Button(action: { selectedBar = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(ColorPalette.cards)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorPalette.border, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Mathematical Helpers
    
    private func yStart(for bar: WaterfallBar) -> Double {
        if bar.isTotal || bar.isSubtotal {
            return 0.0
        }
        return bar.runningTotal - bar.changeValue
    }
    
    private func labelValue(for bar: WaterfallBar) -> String {
        // Toggle label: change value vs running total
        // We check if showRunningTotalLine is checked as a proxy or use standard delta.
        // Let's show change value (+X or -X) for normal bars, and total for total/subtotal.
        if bar.isTotal || bar.isSubtotal {
            return bar.runningTotal.formatted(decimals: 0)
        }
        let prefix = bar.changeValue >= 0 ? "+" : ""
        return prefix + bar.changeValue.formatted(decimals: 0)
    }
    
    private func getBarColor(bar: WaterfallBar) -> Color {
        if bar.isTotal {
            return Color(hex: "#533483") // Theme Button/Accent Color
        }
        if bar.isSubtotal {
            return Color(hex: "#F59E0B") // Warning/Amber Color
        }
        return bar.changeValue >= 0 ? Color(hex: "#00B4D8") : .red
    }
}
