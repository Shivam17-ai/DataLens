import SwiftUI
import Charts

/// BoxPlotView renders distributions using quartile indicators, whisker caps,
/// outlier hollow circles, notched confidence shapes, and orientation toggles.
struct BoxPlotView: View {
    let config: ChartConfig
    let data: ChartData
    let colors: [Color]
    let highlightedSeries: Set<String>
    @ObservedObject var chartViewModel: ChartViewModel
    
    @State private var hoverCategory: String? = nil
    @State private var hoverLocation: CGPoint = .zero
    
    var body: some View {
        let statsMap = chartViewModel.boxPlotStats
        let categories = sortedCategories(keys: Array(statsMap.keys), stats: statsMap)
        
        ZStack(alignment: .topLeading) {
            Chart {
                ForEach(Array(categories.enumerated()), id: \.offset) { index, cat in
                    if let stats = statsMap[cat] {
                        let boxColor = colors[index % colors.count]
                        let isHovered = hoverCategory == cat
                        
                        if config.boxPlotOrientation == .vertical {
                            // ── VERTICAL BOX PLOT ──────────────────────────
                            
                            // Whiskers (Low & High)
                            RuleMark(
                                x: .value("Category", cat),
                                yStart: .value("Whisker Min", stats.lowerWhisker),
                                yEnd: .value("Q1", stats.q1)
                            )
                            .foregroundStyle(boxColor)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            
                            RuleMark(
                                x: .value("Category", cat),
                                yStart: .value("Q3", stats.q3),
                                yEnd: .value("Whisker Max", stats.upperWhisker)
                            )
                            .foregroundStyle(boxColor)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            
                            // Whisker cap ends
                            PointMark(x: .value("Category", cat), y: .value("Cap Min", stats.lowerWhisker))
                                .symbol(Rectangle())
                                .symbolSize(30)
                                .foregroundStyle(boxColor)
                            
                            PointMark(x: .value("Category", cat), y: .value("Cap Max", stats.upperWhisker))
                                .symbol(Rectangle())
                                .symbolSize(30)
                                .foregroundStyle(boxColor)
                            
                            // Main Box (Q1 to Q3)
                            BarMark(
                                x: .value("Category", cat),
                                yStart: .value("Q1", stats.q1),
                                yEnd: .value("Q3", stats.q3),
                                width: 32
                            )
                            .foregroundStyle(boxColor.opacity(isHovered ? 0.90 : 0.65))
                            
                            // Notched overlay (narrowed box around confidence interval of median)
                            if config.boxPlotNotched {
                                BarMark(
                                    x: .value("Category", cat),
                                    yStart: .value("Notch Low", stats.confidenceInterval.lowerBound),
                                    yEnd: .value("Notch High", stats.confidenceInterval.upperBound),
                                    width: 20
                                )
                                .foregroundStyle(Color(hex: "#0F3460").opacity(0.8))
                            }
                            
                            // Median Line (White, thicker)
                            RuleMark(
                                x: .value("Category", cat),
                                y: .value("Median", stats.median)
                            )
                            .foregroundStyle(.white)
                            .lineStyle(StrokeStyle(lineWidth: 3.0))
                            
                            // Outliers
                            ForEach(stats.outliers, id: \.self) { val in
                                PointMark(
                                    x: .value("Category", cat),
                                    y: .value("Outlier", val)
                                )
                                .symbol(Circle().stroke(lineWidth: 1.2))
                                .symbolSize(28)
                                .foregroundStyle(boxColor)
                            }
                            
                        } else {
                            // ── HORIZONTAL BOX PLOT ────────────────────────
                            
                            // Whiskers (Low & High)
                            RuleMark(
                                y: .value("Category", cat),
                                xStart: .value("Whisker Min", stats.lowerWhisker),
                                xEnd: .value("Q1", stats.q1)
                            )
                            .foregroundStyle(boxColor)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            
                            RuleMark(
                                y: .value("Category", cat),
                                xStart: .value("Q3", stats.q3),
                                xEnd: .value("Whisker Max", stats.upperWhisker)
                            )
                            .foregroundStyle(boxColor)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            
                            // Whisker cap ends
                            PointMark(x: .value("Cap Min", stats.lowerWhisker), y: .value("Category", cat))
                                .symbol(Rectangle())
                                .symbolSize(30)
                                .foregroundStyle(boxColor)
                            
                            PointMark(x: .value("Cap Max", stats.upperWhisker), y: .value("Category", cat))
                                .symbol(Rectangle())
                                .symbolSize(30)
                                .foregroundStyle(boxColor)
                            
                            // Main Box (Q1 to Q3)
                            BarMark(
                                y: .value("Category", cat),
                                xStart: .value("Q1", stats.q1),
                                xEnd: .value("Q3", stats.q3),
                                height: 32
                            )
                            .foregroundStyle(boxColor.opacity(isHovered ? 0.90 : 0.65))
                            
                            // Notched overlay
                            if config.boxPlotNotched {
                                BarMark(
                                    y: .value("Category", cat),
                                    xStart: .value("Notch Low", stats.confidenceInterval.lowerBound),
                                    xEnd: .value("Notch High", stats.confidenceInterval.upperBound),
                                    height: 20
                                )
                                .foregroundStyle(Color(hex: "#0F3460").opacity(0.8))
                            }
                            
                            // Median Line
                            RuleMark(
                                y: .value("Category", cat),
                                x: .value("Median", stats.median)
                            )
                            .foregroundStyle(.white)
                            .lineStyle(StrokeStyle(lineWidth: 3.0))
                            
                            // Outliers
                            ForEach(stats.outliers, id: \.self) { val in
                                PointMark(
                                    x: .value("Outlier", val),
                                    y: .value("Category", cat)
                                )
                                .symbol(Circle().stroke(lineWidth: 1.2))
                                .symbolSize(28)
                                .foregroundStyle(boxColor)
                            }
                        }
                    }
                }
            }
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
                    Color.clear
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                self.hoverLocation = location
                                if config.boxPlotOrientation == .vertical {
                                    if let cat: String = proxy.value(atX: location.x) {
                                        self.hoverCategory = cat
                                    }
                                } else {
                                    if let cat: String = proxy.value(atY: location.y) {
                                        self.hoverCategory = cat
                                    }
                                }
                            case .ended:
                                self.hoverCategory = nil
                            }
                        }
                }
            }
            
            // Hover Tooltip showing 5-number summary statistics
            if config.showTooltips, let cat = hoverCategory, let stats = statsMap[cat] {
                VStack(alignment: .leading, spacing: 3) {
                    Text(cat)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(ColorPalette.textSecondary)
                        .padding(.bottom, 2)
                    
                    tooltipRow(label: "Max (whisker)", val: stats.upperWhisker)
                    tooltipRow(label: "Q3 (75th pct)", val: stats.q3)
                    tooltipRow(label: "Median (Q2)", val: stats.median)
                    tooltipRow(label: "Mean (average)", val: stats.mean)
                    tooltipRow(label: "Q1 (25th pct)", val: stats.q1)
                    tooltipRow(label: "Min (whisker)", val: stats.lowerWhisker)
                    
                    if !stats.outliers.isEmpty {
                        Text("Outliers: \(stats.outliers.count) values")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(hex: "#EF4444"))
                    }
                }
                .padding(8)
                .background(ColorPalette.cards)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorPalette.border, lineWidth: 1))
                .shadow(radius: 4)
                .position(x: min(max(hoverLocation.x, 80), 550), y: min(max(hoverLocation.y - 70, 45), 320))
                .allowsHitTesting(false)
            }
        }
    }
    
    // MARK: - Utilities
    
    @ViewBuilder
    private func tooltipRow(label: String, val: Double) -> some View {
        HStack {
            Text(label + ":")
                .font(.system(size: 9))
                .foregroundColor(ColorPalette.textSecondary)
            Spacer()
            Text(val.formatted(decimals: 2))
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(ColorPalette.textPrimary)
        }
        .frame(width: 140)
    }
    
    private func sortedCategories(keys: [String], stats: [String: BoxPlotStats]) -> [String] {
        return keys.sorted { a, b in
            guard let statA = stats[a], let statB = stats[b] else { return true }
            
            switch config.boxSortOrder {
            case .median:
                return statA.median < statB.median
            case .mean:
                return statA.mean < statB.mean
            case .alphabetical:
                return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
            case .original:
                return true
            }
        }
    }
}
