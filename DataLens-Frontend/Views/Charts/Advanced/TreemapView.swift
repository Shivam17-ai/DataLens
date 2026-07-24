import SwiftUI

struct TreemapView: View {
    let config: ChartConfig
    let data: ChartData
    let colors: [Color]
    let highlightedSeries: Set<String>
    @ObservedObject var chartViewModel: ChartViewModel
    
    @State private var zoomedParent: String? = nil
    @State private var hoverRect: TreemapRect? = nil
    @State private var hoverLocation: CGPoint = .zero
    
    var body: some View {
        let allItems = chartViewModel.treemapItems
        let totalValue = allItems.map { $0.value }.reduce(0.0, +)
        
        VStack(spacing: 8) {
            // Breadcrumb Navigation
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        zoomedParent = nil
                    }
                }) {
                    Text("All")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(zoomedParent == nil ? ColorPalette.textSecondary : ColorPalette.accent)
                }
                .buttonStyle(.plain)
                
                if let parent = zoomedParent {
                    Text(">")
                        .font(.system(size: 11))
                        .foregroundColor(ColorPalette.textSecondary)
                    Text(parent)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ColorPalette.textPrimary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(ColorPalette.cards.opacity(0.3))
            .cornerRadius(6)
            
            // Treemap Area
            GeometryReader { geo in
                let containerRect = CGRect(origin: .zero, size: geo.size)
                
                // Determine items to lay out
                let itemsForLayout: [TreemapItem]
                let layoutDepth: Int
                
                if let parent = zoomedParent {
                    // Zoomed view: only layout children of this parent, flat layout
                    itemsForLayout = allItems.filter { $0.parentLabel == parent }
                    layoutDepth = 1
                } else {
                    // Normal view: all items, 1 or 2 depth
                    itemsForLayout = allItems
                    layoutDepth = config.seriesColumn == nil ? 1 : 2
                }
                
                let rects = chartViewModel.calculateTreemapLayout(
                    items: itemsForLayout,
                    in: containerRect,
                    depth: layoutDepth
                )
                
                ZStack(alignment: .topLeading) {
                    // Background
                    Color.clear
                    
                    // Render layout rectangles
                    ForEach(rects) { itemRect in
                        let isParent = itemRect.depth == 1 && config.seriesColumn != nil && zoomedParent == nil
                        let item = itemRect.item
                        let rect = itemRect.rect
                        
                        if rect.width > 2 && rect.height > 2 {
                            let itemColor = getRectColor(item: item, colors: colors, allItems: allItems)
                            
                            Group {
                                if isParent {
                                    // Parent Category Container with Colored Header
                                    VStack(alignment: .leading, spacing: 0) {
                                        HStack {
                                            Text(item.label)
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 6)
                                        .frame(height: 24)
                                        .background(itemColor.darkened(by: 0.25))
                                        
                                        Spacer()
                                    }
                                    .frame(width: rect.width, height: rect.height)
                                    .background(Color.black.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(ColorPalette.border, lineWidth: 1.5)
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            zoomedParent = item.label
                                        }
                                    }
                                } else {
                                    // Child Category (Zoomable / Interactive)
                                    ZStack {
                                        Rectangle()
                                            .fill(itemColor)
                                            .cornerRadius(2)
                                        
                                        // Cell Labels (Auto-hide if cell is too small)
                                        if rect.width > 35 && rect.height > 35 {
                                            VStack(spacing: 2) {
                                                Text(item.label)
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                    .multilineTextAlignment(.center)
                                                
                                                Text(item.value.formatted(decimals: 0))
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.white.opacity(0.8))
                                            }
                                            .padding(4)
                                        }
                                    }
                                    .frame(width: rect.width - 2, height: rect.height - 2)
                                    .onTapGesture {
                                        // Zoom in on parent click if hierarchy exists
                                        if let parent = item.parentLabel {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                zoomedParent = parent
                                            }
                                        }
                                    }
                                }
                            }
                            .offset(x: rect.minX, y: rect.minY)
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    self.hoverLocation = CGPoint(x: rect.minX + location.x, y: rect.minY + location.y)
                                    self.hoverRect = itemRect
                                case .ended:
                                    self.hoverRect = nil
                                }
                            }
                        }
                    }
                    
                    // Tooltip Overlay
                    if config.showTooltips, let active = hoverRect {
                        let pct = totalValue > 0 ? (active.item.value / totalValue) * 100.0 : 0.0
                        VStack(alignment: .leading, spacing: 3) {
                            if let parent = active.item.parentLabel {
                                Text(parent)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(ColorPalette.textSecondary)
                            }
                            Text(active.item.label)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(ColorPalette.textPrimary)
                            HStack {
                                Text("Value:")
                                    .font(.system(size: 10))
                                    .foregroundColor(ColorPalette.textSecondary)
                                Spacer()
                                Text(active.item.value.formatted(decimals: 2))
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .frame(width: 130)
                            HStack {
                                Text("Share:")
                                    .font(.system(size: 10))
                                    .foregroundColor(ColorPalette.textSecondary)
                                Spacer()
                                Text(String(format: "%.1f%%", pct))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(ColorPalette.success)
                            }
                            .frame(width: 130)
                        }
                        .padding(8)
                        .background(ColorPalette.cards)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorPalette.border, lineWidth: 1))
                        .shadow(radius: 4)
                        .position(x: min(max(hoverLocation.x, 80), geo.size.width - 80), y: min(max(hoverLocation.y - 50, 45), geo.size.height - 45))
                        .allowsHitTesting(false)
                    }
                }
                .gesture(
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                zoomedParent = nil
                            }
                        }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(4)
    }
    
    // MARK: - Color Resolution
    
    private func getRectColor(item: TreemapItem, colors: [Color], allItems: [TreemapItem]) -> Color {
        let parentName = item.parentLabel ?? item.label
        let index = abs(parentName.hashValue) % colors.count
        let baseColor = colors[index]
        
        if item.parentLabel != nil {
            // Lighter shade depending on value intensity
            let parentVals = allItems.filter { $0.parentLabel == parentName }.map { $0.value }
            let maxVal = parentVals.max() ?? 1.0
            let intensity = maxVal > 0 ? CGFloat(0.45 + (item.value / maxVal) * 0.55) : 0.7
            return baseColor.opacity(intensity)
        }
        return baseColor
    }
}

// Color modification helper
extension Color {
    func darkened(by amount: CGFloat) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(.sRGB, red: Double(max(0, r - amount)), green: Double(max(0, g - amount)), blue: Double(max(0, b - amount)), opacity: Double(a))
    }
}
