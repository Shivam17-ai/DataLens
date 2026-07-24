import SwiftUI

struct FunnelChartView: View {
    let config: ChartConfig
    let data: ChartData
    let colors: [Color]
    let highlightedSeries: Set<String>
    @ObservedObject var chartViewModel: ChartViewModel
    
    @State private var animate = false
    @State private var hoverStage: FunnelStage? = nil
    @State private var hoverLocation: CGPoint = .zero
    @State private var selectedStage: FunnelStage? = nil
    
    var body: some View {
        let stages = chartViewModel.funnelStages
        
        VStack(spacing: 12) {
            if stages.isEmpty {
                EmptyStateView(
                    iconName: "filter",
                    title: "No Funnel Data Available",
                    subtitle: "Please configure X (categorical stages) and Y (numeric progression values)."
                )
            } else {
                // Funnel Stages Stack
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(stages.enumerated()), id: \.element.id) { idx, stage in
                            let isHovered = hoverStage?.id == stage.id
                            
                            VStack(spacing: 4) {
                                // Conversion Drop-off Marker between stages
                                if idx > 0 {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "arrow.down")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(ColorPalette.textSecondary)
                                        Text(String(format: "-%.1f%% Drop-off", stage.dropOffPct))
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(.red.opacity(0.8))
                                        Spacer()
                                    }
                                    .padding(.vertical, 2)
                                }
                                
                                // Stage Visual Shape + Row Labels
                                GeometryReader { geo in
                                    let w = geo.size.width
                                    let h = geo.size.height
                                    
                                    ZStack {
                                        // Background Shape (Classic Funnel, Pyramid, or Bar)
                                        funnelPath(for: idx, count: stages.count, stages: stages, width: w, height: h)
                                            .fill(stage.color)
                                            .opacity(isHovered ? 0.95 : 0.75)
                                            .overlay(
                                                funnelPath(for: idx, count: stages.count, stages: stages, width: w, height: h)
                                                    .stroke(ColorPalette.border, lineWidth: 1)
                                            )
                                            .shadow(color: Color.black.opacity(0.15), radius: 2)
                                            .scaleEffect(x: animate ? 1.0 : 0.0, y: 1.0, anchor: .center)
                                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(idx) * 0.1), value: animate)
                                            
                                        // Row Content Labels
                                        HStack {
                                            if !config.showDataLabels { // "Labels outside toggle" -> on left and right
                                                Text(stage.label)
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(ColorPalette.textPrimary)
                                                    .frame(width: w * 0.25, alignment: .leading)
                                                Spacer()
                                            } else {
                                                Spacer()
                                            }
                                            
                                            // Center info if inside, else right info
                                            VStack(spacing: 1) {
                                                Text(stage.value.formatted(decimals: 0))
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(config.showDataLabels ? .white : ColorPalette.textPrimary)
                                                Text(String(format: "%.1f%% of start", stage.pctOfFirst))
                                                    .font(.system(size: 8, weight: .semibold))
                                                    .foregroundColor(config.showDataLabels ? .white.opacity(0.8) : ColorPalette.textSecondary)
                                            }
                                            .frame(width: config.showDataLabels ? w * 0.5 : w * 0.25, alignment: config.showDataLabels ? .center : .trailing)
                                            
                                            if config.showDataLabels {
                                                Spacer()
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedStage = stage
                                    }
                                    .onContinuousHover { phase in
                                        switch phase {
                                        case .active(let location):
                                            self.hoverLocation = CGPoint(x: geo.frame(in: .global).minX + location.x, y: geo.frame(in: .global).minY + location.y)
                                            self.hoverStage = stage
                                        case .ended:
                                            self.hoverStage = nil
                                        }
                                    }
                                }
                                .frame(height: max(42, min(60, 240.0 / CGFloat(stages.count))))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                
                // Prominent Conversion Rate Badge Summary at Bottom
                if stages.count > 1 {
                    let overallConversion = (stages.last!.value / stages.first!.value) * 100.0
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("OVERALL CONVERSION RATE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(ColorPalette.textSecondary)
                            Text(String(format: "%.1f%%", overallConversion))
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(ColorPalette.success)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(ColorPalette.cards)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ColorPalette.border, lineWidth: 1.5)
                        )
                        Spacer()
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            animate = true
        }
    }
    
    // MARK: - Funnel Shapes generator
    
    private func funnelPath(for idx: Int, count: Int, stages: [FunnelStage], width: CGFloat, height: CGFloat) -> Path {
        let style = config.funnelStyle
        var path = Path()
        
        let pct = stages[idx].pctOfFirst / 100.0
        
        switch style {
        case .bar:
            // Centered blocky bar
            let barW = width * CGFloat(pct) * 0.7
            let xOffset = (width - barW) / 2.0
            path.addRoundedRect(in: CGRect(x: xOffset, y: 0, width: barW, height: height), cornerSize: CGSize(width: 4, height: 4))
            
        case .classic:
            // Continuous tapering trapezoid downwards
            let nextPct: Double
            if idx < count - 1 {
                nextPct = stages[idx + 1].pctOfFirst / 100.0
            } else {
                nextPct = pct * 0.7 // Taper final stage base
            }
            
            let topW = width * CGFloat(pct) * 0.7
            let botW = width * CGFloat(nextPct) * 0.7
            
            let topX = (width - topW) / 2.0
            let botX = (width - botW) / 2.0
            
            path.move(to: CGPoint(x: topX, y: 0))
            path.addLine(to: CGPoint(x: topX + topW, y: 0))
            path.addLine(to: CGPoint(x: botX + botW, y: height))
            path.addLine(to: CGPoint(x: botX, y: height))
            path.closeSubpath()
            
        case .pyramid:
            // Continuous tapering trapezoid upwards (wide at bottom, narrow at top)
            let topPct: Double
            if idx == 0 {
                topPct = pct * 0.3 // Narrow top cap
            } else {
                topPct = stages[idx - 1].pctOfFirst / 100.0
            }
            
            // Reversing widths to flare out downwards
            let topW = width * CGFloat(topPct) * 0.7
            let botW = width * CGFloat(pct) * 0.7
            
            let topX = (width - topW) / 2.0
            let botX = (width - botW) / 2.0
            
            path.move(to: CGPoint(x: topX, y: 0))
            path.addLine(to: CGPoint(x: topX + topW, y: 0))
            path.addLine(to: CGPoint(x: botX + botW, y: height))
            path.addLine(to: CGPoint(x: botX, y: height))
            path.closeSubpath()
        }
        
        return path
    }
}
