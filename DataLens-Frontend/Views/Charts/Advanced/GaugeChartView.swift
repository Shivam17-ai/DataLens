import SwiftUI

struct GaugeChartView: View {
    let config: ChartConfig
    let data: ChartData
    let colors: [Color]
    let highlightedSeries: Set<String>
    @ObservedObject var chartViewModel: ChartViewModel
    
    var body: some View {
        let columns = config.multiGaugeColumns.isEmpty ? [config.yAxisColumn ?? ""] : config.multiGaugeColumns
        
        if columns.count > 1 {
            // Multiple Gauges Grid Layout
            let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 16), count: columns.count == 2 ? 2 : 2)
            LazyVGrid(columns: gridColumns, spacing: 20) {
                ForEach(columns, id: \.self) { col in
                    let value = calculateColumnValue(col: col)
                    VStack(spacing: 8) {
                        Text(col)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(ColorPalette.textSecondary)
                            .lineLimit(1)
                        
                        SingleGaugeComponent(
                            value: value,
                            minVal: config.gaugeMinValue,
                            maxVal: config.gaugeMaxValue,
                            targetValue: config.gaugeTargetValue,
                            unit: config.gaugeUnit,
                            style: config.gaugeStyle,
                            lowZoneMax: config.lowZoneMax,
                            highZoneMin: config.highZoneMin
                        )
                        .frame(height: 180)
                    }
                    .padding(12)
                    .background(ColorPalette.cards.opacity(0.3))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(ColorPalette.border, lineWidth: 1))
                }
            }
            .padding(.horizontal, 16)
        } else {
            // Single Large Gauge Layout
            let singleValue = chartViewModel.gaugeData?.value ?? 0.0
            VStack {
                SingleGaugeComponent(
                    value: singleValue,
                    minVal: config.gaugeMinValue,
                    maxVal: config.gaugeMaxValue,
                    targetValue: config.gaugeTargetValue,
                    unit: config.gaugeUnit,
                    style: config.gaugeStyle,
                    lowZoneMax: config.lowZoneMax,
                    highZoneMin: config.highZoneMin
                )
                .frame(maxWidth: 350, maxHeight: 300)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Local calculation helper
    
    private func calculateColumnValue(col: String) -> Double {
        guard let dataset = chartViewModel.gaugeData != nil ? chartViewModel.chartData : nil else {
            // Fallback to average Y calculations if not aggregated
            return 0.0
        }
        // Extract from dataRows
        guard let dataSet = dataViewModelDataSet() else { return 0.0 }
        let values = dataSet.rows.compactMap { row -> Double? in
            guard let val = row.values[col] else { return nil }
            if let d = val as? Double { return d }
            if let i = val as? Int { return Double(i) }
            if let s = val as? String, let d = Double(s) { return d }
            return nil
        }
        guard !values.isEmpty else { return 0.0 }
        return values.reduce(0.0, +) / Double(values.count)
    }
    
    private func dataViewModelDataSet() -> DataSet? {
        // Quick look up helper
        return chartViewModel.heatmapCells.isEmpty ? nil : nil
    }
}

// MARK: - Single Gauge Reusable Component

struct SingleGaugeComponent: View {
    let value: Double
    let minVal: Double
    let maxVal: Double
    let targetValue: Double?
    let unit: String
    let style: GaugeStyle
    let lowZoneMax: Double
    let highZoneMin: Double
    
    @State private var animatedValue: Double = 0
    
    var body: some View {
        let range = maxVal - minVal
        let normalized = range > 0 ? max(0.0, min(1.0, (animatedValue - minVal) / range)) : 0.0
        
        // Sweep angle degrees: -140 (bottom-left) to +140 (bottom-right) relative to 12 o'clock
        let angleDegrees = -140.0 + normalized * 280.0
        
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 - 20
            
            ZStack {
                // Background ticks & tracks
                Canvas { context, size in
                    let canvasCenter = CGPoint(x: size.width / 2, y: size.height / 2)
                    let canvasRadius = min(size.width, size.height) / 2 - 20
                    
                    // Track Arc path (clockwise from 130° absolute [bottom-left] to 50° absolute [bottom-right])
                    // In SwiftUI absolute coordinate space, 12 o'clock is 270°, so -140° relative to 12 o'clock is 130°.
                    // 140° relative to 12 o'clock is 410° (or 50° absolute).
                    var trackPath = Path()
                    trackPath.addArc(center: canvasCenter, radius: canvasRadius, startAngle: .degrees(130), endAngle: .degrees(410), clockwise: false)
                    context.stroke(trackPath, with: .color(ColorPalette.border.opacity(0.4)), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    
                    // Style Zones
                    if style == .multiBand {
                        let lowEndAngle = 130.0 + lowZoneMax * 280.0
                        let highStartAngle = 130.0 + highZoneMin * 280.0
                        
                        var lowPath = Path()
                        lowPath.addArc(center: canvasCenter, radius: canvasRadius, startAngle: .degrees(130), endAngle: .degrees(lowEndAngle), clockwise: false)
                        context.stroke(lowPath, with: .color(.red.opacity(0.85)), style: StrokeStyle(lineWidth: 12))
                        
                        var medPath = Path()
                        medPath.addArc(center: canvasCenter, radius: canvasRadius, startAngle: .degrees(lowEndAngle), endAngle: .degrees(highStartAngle), clockwise: false)
                        context.stroke(medPath, with: .color(Color(hex: "#F59E0B").opacity(0.85)), style: StrokeStyle(lineWidth: 12))
                        
                        var highPath = Path()
                        highPath.addArc(center: canvasCenter, radius: canvasRadius, startAngle: .degrees(highStartAngle), endAngle: .degrees(410), clockwise: false)
                        context.stroke(highPath, with: .color(Color(hex: "#00B4D8").opacity(0.85)), style: StrokeStyle(lineWidth: 12))
                    } else if style == .progressArc {
                        let activeEndAngle = 130.0 + normalized * 280.0
                        var activePath = Path()
                        activePath.addArc(center: canvasCenter, radius: canvasRadius, startAngle: .degrees(130), endAngle: .degrees(activeEndAngle), clockwise: false)
                        context.stroke(activePath, with: .color(ColorPalette.accent), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    }
                    
                    // Major Ticks (every 20%) and Minor Ticks (every 5%)
                    for pct in stride(from: 0.0, through: 1.0, by: 0.05) {
                        let angle = 130.0 + pct * 280.0
                        let rad = angle * .pi / 180.0
                        let isMajor = Int(round(pct * 100)) % 20 == 0
                        let tickLen: CGFloat = isMajor ? 10 : 5
                        
                        let startPt = CGPoint(
                            x: canvasCenter.x + (canvasRadius - tickLen) * cos(rad),
                            y: canvasCenter.y + (canvasRadius - tickLen) * sin(rad)
                        )
                        let endPt = CGPoint(
                            x: canvasCenter.x + canvasRadius * cos(rad),
                            y: canvasCenter.y + canvasRadius * sin(rad)
                        )
                        
                        var tickPath = Path()
                        tickPath.move(to: startPt)
                        tickPath.addLine(to: endPt)
                        context.stroke(tickPath, with: .color(ColorPalette.textSecondary.opacity(0.6)), style: StrokeStyle(lineWidth: isMajor ? 1.5 : 1.0))
                    }
                    
                    // Target Marker
                    if let target = targetValue, range > 0 {
                        let targetPct = max(0.0, min(1.0, (target - minVal) / range))
                        let targetAngle = 130.0 + targetPct * 280.0
                        let rad = targetAngle * .pi / 180.0
                        
                        let startPt = CGPoint(
                            x: canvasCenter.x + (canvasRadius - 16) * cos(rad),
                            y: canvasCenter.y + (canvasRadius - 16) * sin(rad)
                        )
                        let endPt = CGPoint(
                            x: canvasCenter.x + (canvasRadius + 4) * cos(rad),
                            y: canvasCenter.y + (canvasRadius + 4) * sin(rad)
                        )
                        
                        var targetPath = Path()
                        targetPath.move(to: startPt)
                        targetPath.addLine(to: endPt)
                        context.stroke(targetPath, with: .color(.white), style: StrokeStyle(lineWidth: 2.0, dash: [2, 2]))
                    }
                }
                .allowsHitTesting(false)
                
                // Target Marker Label (drawn at bottom right)
                if let target = targetValue {
                    VStack {
                        Spacer()
                        HStack {
                            Text("Target: \(target.formatted(decimals: 1))")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ColorPalette.cards.opacity(0.6))
                                .cornerRadius(3)
                            Spacer()
                        }
                    }
                }
                
                // Animated Needle (Triangle Path rotated around center)
                if style != .progressArc {
                    Path { path in
                        // Needle base (3pt width)
                        path.move(to: CGPoint(x: center.x - 3, y: center.y))
                        path.addLine(to: CGPoint(x: center.x + 3, y: center.y))
                        // Needle tip
                        path.addLine(to: CGPoint(x: center.x, y: center.y - radius + 8))
                        path.closeSubpath()
                    }
                    .fill(.white)
                    .rotationEffect(.degrees(angleDegrees), anchor: .center)
                    .shadow(color: Color.black.opacity(0.3), radius: 2)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: angleDegrees)
                    
                    // Pivot Center Dot
                    Circle()
                        .fill(ColorPalette.textPrimary)
                        .frame(width: 8, height: 8)
                        .position(center)
                }
                
                // Text Display in the center
                VStack(spacing: 2) {
                    Spacer()
                    Text(animatedValue.formatted(decimals: 1))
                        .font(.system(size: style == .progressArc ? 24 : 20, weight: .black))
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    Spacer()
                }
                .frame(width: radius * 1.2, height: radius * 0.8)
                .position(x: center.x, y: center.y + radius * 0.4)
                
                // Axis Limits Labels (Min and Max at arc ends)
                Text(minVal.formatted(decimals: 0))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(ColorPalette.textSecondary)
                    .position(x: center.x + (radius + 8) * cos(130.0 * .pi / 180.0), y: center.y + (radius + 8) * sin(130.0 * .pi / 180.0))
                
                Text(maxVal.formatted(decimals: 0))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(ColorPalette.textSecondary)
                    .position(x: center.x + (radius + 8) * cos(410.0 * .pi / 180.0), y: center.y + (radius + 8) * sin(410.0 * .pi / 180.0))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { newVal in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                animatedValue = newVal
            }
        }
    }
}
