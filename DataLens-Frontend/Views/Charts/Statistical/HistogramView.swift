import SwiftUI
import Charts

/// HistogramView renders frequency distributions, normal bell curve overlays,
/// outlier bin highlights, and a comprehensive statistics row panel.
struct HistogramView: View {
    let config: ChartConfig
    let data: ChartData
    let colors: [Color]
    let highlightedSeries: Set<String>
    @ObservedObject var chartViewModel: ChartViewModel
    
    @State private var hoverBin: HistogramBin? = nil
    @State private var hoverLocation: CGPoint = .zero
    
    var body: some View {
        let bins = chartViewModel.histogramBins
        let rawValues = chartViewModel.histogramRawValues
        let stats = calculateFullStats(values: rawValues)
        
        VStack(spacing: 12) {
            
            // Primary Histogram Chart Canvas
            ZStack(alignment: .topLeading) {
                Chart {
                    // Render Bars for each bin
                    ForEach(Array(bins.enumerated()), id: \.offset) { idx, bin in
                        let label = String(format: "%.1f - %.1f", bin.lowerBound, bin.upperBound)
                        
                        // Outliers Highlight toggle: highlight bins exceeding 2 std devs in red
                        let isOutlier = config.showOutlierHighlight && (bin.lowerBound > stats.mean + 2.0 * stats.stdDev || bin.upperBound < stats.mean - 2.0 * stats.stdDev)
                        let barColor = isOutlier ? Color(hex: "#EF4444") : colors.first ?? ColorPalette.accent
                        
                        // Y height calculation: Cumulative vs standard
                        let yValue: Double
                        if config.cumulativeHistogram {
                            yValue = config.histogramType == .frequency ? Double(cumulativeCount(upTo: idx, bins: bins)) : bin.cumulativePercentage * 100.0
                        } else {
                            yValue = config.histogramType == .frequency ? Double(bin.count) : bin.density * 100.0
                        }
                        
                        BarMark(
                            x: .value("Bin Range", label),
                            y: .value("Frequency", yValue)
                        )
                        .foregroundStyle(barColor)
                        .cornerRadius(3)
                    }
                    
                    // Normal curve overlay bell shape
                    if config.showNormalCurve && !rawValues.isEmpty && stats.stdDev > 0 {
                        // Plot a LineMark overlay for the bell curve
                        ForEach(normalCurvePoints(stats: stats, bins: bins), id: \.x) { pt in
                            LineMark(
                                x: .value("Bin Range", pt.xBinLabel),
                                y: .value("Normal Curve", pt.yVal)
                            )
                            .foregroundStyle(Color(hex: "#F59E0B"))
                            .lineStyle(StrokeStyle(lineWidth: 2.0))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { value in
                        if config.showGrid {
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7))
                                .foregroundStyle(ColorPalette.border.opacity(0.5))
                        }
                        AxisValueLabel {
                            if let d = value.as(Double.self) {
                                Text(config.histogramType == .density && !config.cumulativeHistogram ? String(format: "%.0f%%", d) : d.formatted(decimals: 0))
                                    .font(.system(size: 9))
                                    .foregroundColor(ColorPalette.textSecondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel(anchor: .topTrailing) {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .rotationEffect(.degrees(-35))
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(ColorPalette.textSecondary)
                            }
                        }
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
                                    if let binLabel: String = proxy.value(atX: location.x) {
                                        self.hoverBin = bins.first { bin in
                                            let label = String(format: "%.1f - %.1f", bin.lowerBound, bin.upperBound)
                                            return label == binLabel
                                        }
                                    }
                                case .ended:
                                    self.hoverBin = nil
                                }
                            }
                    }
                }
                
                // Tooltip displays statistics
                if config.showTooltips, let bin = hoverBin {
                    let label = String(format: "%.1f - %.1f", bin.lowerBound, bin.upperBound)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(ColorPalette.textSecondary)
                        Text("Frequency Count: \(bin.count)")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Density Share: \(String(format: "%.1f%%", bin.density * 100.0))")
                        Text("Cumulative Share: \(String(format: "%.1f%%", bin.cumulativePercentage * 100.0))")
                    }
                    .padding(8)
                    .background(ColorPalette.cards)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorPalette.border, lineWidth: 1))
                    .shadow(radius: 4)
                    .position(x: min(max(hoverLocation.x, 80), 550), y: min(max(hoverLocation.y - 65, 45), 320))
                    .allowsHitTesting(false)
                }
            }
            .frame(height: 260)
            
            // Statistics panel row below the chart
            if !rawValues.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        StatItemCard(label: "Mean", value: stats.mean.formatted(decimals: 2))
                        StatItemCard(label: "Median", value: stats.median.formatted(decimals: 2))
                        StatItemCard(label: "Std Dev", value: stats.stdDev.formatted(decimals: 2))
                        StatItemCard(label: "Range", value: "\(stats.min.formatted(decimals: 1)) - \(stats.max.formatted(decimals: 1))")
                        
                        StatItemCard(
                            label: "Skewness",
                            value: stats.skewness.formatted(decimals: 2),
                            subtitle: skewnessLabel(stats.skewness)
                        )
                        
                        StatItemCard(
                            label: "Kurtosis",
                            value: stats.kurtosis.formatted(decimals: 2),
                            subtitle: kurtosisLabel(stats.kurtosis)
                        )
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 64)
            }
        }
    }
    
    // MARK: - Local Stats calculations
    
    private struct FullStats {
        let mean: Double
        let median: Double
        let stdDev: Double
        let skewness: Double
        let kurtosis: Double
        let min: Double
        let max: Double
    }
    
    // Raw values are now sourced from chartViewModel.histogramRawValues,
    // populated by ChartViewModel.prepareHistogramData().
    
    private func calculateFullStats(values: [Double]) -> FullStats {
        guard !values.isEmpty else {
            return FullStats(mean: 0, median: 0, stdDev: 0, skewness: 0, kurtosis: 0, min: 0, max: 0)
        }
        let sorted = values.sorted()
        let count = Double(sorted.count)
        
        let sum = sorted.reduce(0.0, +)
        let meanVal = sum / count
        
        // Median
        let medianVal: Double
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            medianVal = (sorted[mid - 1] + sorted[mid]) / 2.0
        } else {
            medianVal = sorted[mid]
        }
        
        // Standard Deviation
        let variance = sorted.map { pow($0 - meanVal, 2) }.reduce(0.0, +) / max(1.0, count - 1.0)
        let stdDevVal = sqrt(variance)
        
        // Skewness & Kurtosis
        var m3 = 0.0
        var m2 = 0.0
        var m4 = 0.0
        for val in sorted {
            let diff = val - meanVal
            m2 += pow(diff, 2)
            m3 += pow(diff, 3)
            m4 += pow(diff, 4)
        }
        m2 /= count
        m3 /= count
        m4 /= count
        
        let skewnessVal = m2 > 0 ? (m3 / pow(m2, 1.5)) : 0.0
        let kurtosisVal = m2 > 0 ? (m4 / pow(m2, 2.0) - 3.0) : 0.0
        
        return FullStats(
            mean: meanVal,
            median: medianVal,
            stdDev: stdDevVal,
            skewness: skewnessVal,
            kurtosis: kurtosisVal,
            min: sorted.first!,
            max: sorted.last!
        )
    }
    
    private func cumulativeCount(upTo index: Int, bins: [HistogramBin]) -> Int {
        return bins[0...index].map { $0.count }.reduce(0, +)
    }
    
    private func skewnessLabel(_ val: Double) -> String {
        if val < -1.0 || val > 1.0 { return "Highly Skewed" }
        if val < -0.5 || val > 0.5 { return "Moderately Skewed" }
        return "Symmetric"
    }
    
    private func kurtosisLabel(_ val: Double) -> String {
        if val > 0.5 { return "Heavy-tailed" }
        if val < -0.5 { return "Light-tailed" }
        return "Normal-like"
    }
    
    // MARK: - Normal Curve Generator
    
    private struct LinePoint {
        let x: Double
        let xBinLabel: String
        let yVal: Double
    }
    
    private func normalCurvePoints(stats: FullStats, bins: [HistogramBin]) -> [LinePoint] {
        guard !bins.isEmpty, stats.stdDev > 0 else { return [] }
        
        var points: [LinePoint] = []
        let totalCount = bins.map { $0.count }.reduce(0, +)
        let totalVal = Double(totalCount)
        
        for bin in bins {
            let midX = (bin.lowerBound + bin.upperBound) / 2.0
            
            // Probability Density Function: f(x)
            let exponent = -0.5 * pow((midX - stats.mean) / stats.stdDev, 2)
            let pdf = (1.0 / (stats.stdDev * sqrt(2.0 * .pi))) * exp(exponent)
            
            // Scale normal density to match count or percentage metrics
            let label = String(format: "%.1f - %.1f", bin.lowerBound, bin.upperBound)
            let yVal: Double
            
            let binWidth = bin.upperBound - bin.lowerBound
            if config.histogramType == .frequency {
                yVal = pdf * totalVal * binWidth
            } else {
                yVal = pdf * binWidth * 100.0
            }
            
            points.append(LinePoint(x: midX, xBinLabel: label, yVal: yVal))
        }
        
        return points
    }
}

// MARK: - Stat Item Card

private struct StatItemCard: View {
    let label: String
    let value: String
    var subtitle: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(ColorPalette.textSecondary)
            
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(ColorPalette.textPrimary)
            
            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(ColorPalette.success)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minWidth: 80, alignment: .leading)
        .background(Color(hex: "#0F3460"))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorPalette.border, lineWidth: 1))
    }
}
