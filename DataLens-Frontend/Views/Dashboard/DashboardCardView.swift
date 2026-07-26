import SwiftUI

// MARK: - DashboardCardView

/// A single draggable, resizable card on the dashboard canvas.
/// Supports:
///   - Drag to reposition (with snap-to-grid)
///   - Resize handle in bottom-right corner
///   - Selection highlight with glow ring
///   - Context menu: Bring to Front, Send to Back, Duplicate, Delete
///   - Minimize / maximize toggle
///   - Card type-specific content (chart placeholder / text / KPI / filter)
struct DashboardCardView: View {

    @ObservedObject var dashboardViewModel: DashboardViewModel
    let card: DashboardCard
    var dataset: DataSet?

    @State private var isDragging: Bool = false
    @State private var isResizing: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var resizeDelta: CGSize = .zero

    private var isSelected: Bool {
        dashboardViewModel.selectedCardIds.contains(card.id)
    }

    private var effectiveSize: CGSize {
        CGSize(
            width: max(200, card.size.width + (isResizing ? resizeDelta.width : 0)),
            height: max(150, card.size.height + (isResizing ? resizeDelta.height : 0))
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // ── Card Shell ──────────────────────────────────────────────
            VStack(spacing: 0) {
                // Title bar (drag handle)
                cardTitleBar

                // Content
                if !card.isMinimized {
                    cardContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
            }
            .frame(width: effectiveSize.width, height: card.isMinimized ? 40 : effectiveSize.height)
            .background(ColorPalette.cards)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? ColorPalette.accent : ColorPalette.border, lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(
                color: isSelected ? ColorPalette.accent.opacity(0.3) : .black.opacity(0.25),
                radius: isSelected ? 12 : 6,
                x: 0,
                y: isSelected ? 4 : 2
            )
            .offset(dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dashboardViewModel.isPreviewMode { return }
                        isDragging = true
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        if dashboardViewModel.isPreviewMode { return }
                        let newPos = CGPoint(
                            x: card.position.x + value.translation.width,
                            y: card.position.y + value.translation.height
                        )
                        dashboardViewModel.moveCard(id: card.id, to: newPos)
                        dragOffset = .zero
                        isDragging = false
                    }
            )
            .onTapGesture {
                dashboardViewModel.selectCard(id: card.id, adding: false)
            }
            .contextMenu {
                cardContextMenu
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
            .animation(.interactiveSpring(), value: isDragging)

            // ── Resize Handle (only in edit mode, not minimized) ────────
            if !dashboardViewModel.isPreviewMode && !card.isMinimized {
                resizeHandle
            }
        }
        .position(
            x: card.position.x + effectiveSize.width / 2 + dragOffset.width,
            y: card.position.y + (card.isMinimized ? 20 : effectiveSize.height / 2) + dragOffset.height
        )
        .zIndex(Double(card.zIndex))
    }

    // MARK: - Card Title Bar

    private var cardTitleBar: some View {
        HStack(spacing: 8) {
            // Card type icon
            Image(systemName: cardTypeIcon(card.type))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(cardTypeColor(card.type))

            // Title
            Text(card.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ColorPalette.textPrimary)
                .lineLimit(1)

            Spacer()

            if !dashboardViewModel.isPreviewMode {
                // Minimize / maximize
                Button(action: {
                    if let idx = dashboardViewModel.cards.firstIndex(where: { $0.id == card.id }) {
                        dashboardViewModel.cards[idx].isMinimized.toggle()
                    }
                }) {
                    Image(systemName: card.isMinimized ? "arrow.up.left.and.arrow.down.right" : "minus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .buttonStyle(.plain)

                // Delete
                Button(action: { dashboardViewModel.deleteCard(id: card.id) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            cardTypeColor(card.type).opacity(0.08)
                .overlay(ColorPalette.sidebar.opacity(0.3))
        )
        .cornerRadius(12, corners: card.isMinimized ? .allCorners : [.topLeft, .topRight])
    }

    // MARK: - Card Content

    @ViewBuilder
    private var cardContent: some View {
        switch card.type {
        case .chart:
            chartCardContent
        case .text:
            textCardContent
        case .kpi:
            kpiCardContent
        case .filter:
            filterCardContent
        }
    }

    private var chartCardContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 36))
                .foregroundColor(ColorPalette.accent.opacity(0.4))
            Text(card.chartConfig?.title ?? "Chart Widget")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ColorPalette.textSecondary)
            Text("Configure chart type and columns\nfrom the chart editor")
                .font(.system(size: 10))
                .foregroundColor(ColorPalette.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var textCardContent: some View {
        ScrollView {
            Text(card.textContent ?? "Double-click to edit text…")
                .font(.system(size: 12))
                .foregroundColor(card.textContent == nil ? ColorPalette.textSecondary.opacity(0.5) : ColorPalette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(12)
        }
    }

    private var kpiCardContent: some View {
        VStack(spacing: 6) {
            Spacer()
            Text(card.kpiConfig?.labelText ?? "KPI")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ColorPalette.textSecondary)

            // Placeholder value
            Text("—")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(ColorPalette.success)

            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(ColorPalette.success)
                Text("No data column configured")
                    .font(.system(size: 9))
                    .foregroundColor(ColorPalette.textSecondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var filterCardContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "tag")
                .font(.system(size: 14))
                .foregroundColor(ColorPalette.accent)
            Text("Category filter will appear here")
                .font(.system(size: 11))
                .foregroundColor(ColorPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Resize Handle

    private var resizeHandle: some View {
        ZStack {
            Circle()
                .fill(ColorPalette.border)
                .frame(width: 16, height: 16)
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(ColorPalette.textSecondary)
        }
        .offset(x: -4, y: -4)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isResizing = true
                    resizeDelta = value.translation
                }
                .onEnded { value in
                    let newSize = CGSize(
                        width: max(200, card.size.width + value.translation.width),
                        height: max(150, card.size.height + value.translation.height)
                    )
                    dashboardViewModel.resizeCard(id: card.id, to: newSize)
                    resizeDelta = .zero
                    isResizing = false
                }
        )
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var cardContextMenu: some View {
        Button(action: { dashboardViewModel.bringToFront(id: card.id) }) {
            Label("Bring to Front", systemImage: "square.stack.3d.up.fill")
        }
        Button(action: { dashboardViewModel.sendToBack(id: card.id) }) {
            Label("Send to Back", systemImage: "square.stack.3d.down.right.fill")
        }
        Divider()
        Button(action: { dashboardViewModel.duplicateCard(id: card.id) }) {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        Divider()
        Button(role: .destructive, action: { dashboardViewModel.deleteCard(id: card.id) }) {
            Label("Delete Card", systemImage: "trash")
        }
    }

    // MARK: - Helpers

    private func cardTypeIcon(_ type: CardType) -> String {
        switch type {
        case .chart:  return "chart.bar.xaxis"
        case .text:   return "text.alignleft"
        case .kpi:    return "gauge.high"
        case .filter: return "tag.fill"
        }
    }

    private func cardTypeColor(_ type: CardType) -> Color {
        switch type {
        case .chart:  return ColorPalette.accent
        case .text:   return ColorPalette.success
        case .kpi:    return ColorPalette.warning
        case .filter: return Color(hex: "#E879F9") ?? ColorPalette.accent
        }
    }
}

// MARK: - Corner Radius Helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

struct RectCorner: OptionSet {
    let rawValue: Int
    static let topLeft     = RectCorner(rawValue: 1 << 0)
    static let topRight    = RectCorner(rawValue: 1 << 1)
    static let bottomLeft  = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: RectCorner

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let tl = corners.contains(.topLeft) ? radius : 0
        let tr = corners.contains(.topRight) ? radius : 0
        let bl = corners.contains(.bottomLeft) ? radius : 0
        let br = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()

        return path
    }
}
