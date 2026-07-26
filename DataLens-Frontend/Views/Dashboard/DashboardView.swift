import SwiftUI

// MARK: - DashboardView

/// Main container for Week 3 Day 2's drag-and-drop dashboard builder.
/// Layout:
///   ┌──────────────────────────────────────────────────────────┐
///   │  DashboardToolbar                                         │
///   ├─────────────────────────────────────────┬────────────────┤
///   │  DashboardGridView (infinite canvas)    │  Right Panel   │
///   │                                         │  (card config) │
///   └─────────────────────────────────────────┴────────────────┘
struct DashboardView: View {

    @StateObject private var dashboardViewModel = DashboardViewModel()
    @State private var showRightPanel: Bool = false

    /// Optional dataset injected by the parent (e.g. ContentView / NavigationViewModel)
    var dataset: DataSet? = nil

    var body: some View {
        VStack(spacing: 0) {
            // ── Toolbar ─────────────────────────────────────────────────
            DashboardToolbar(dashboardViewModel: dashboardViewModel) { cardType in
                addCardToCenter(type: cardType)
            }

            // ── Canvas + Optional Config Panel ──────────────────────────
            HStack(spacing: 0) {
                // Main canvas
                DashboardGridView(
                    dashboardViewModel: dashboardViewModel,
                    dataset: dataset
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Right config panel (shown when a card is selected)
                if showRightPanel, let selectedId = dashboardViewModel.selectedCardIds.first,
                   let card = dashboardViewModel.cards.first(where: { $0.id == selectedId }) {
                    Divider().background(ColorPalette.border)
                    cardConfigPanel(for: card)
                        .frame(width: 260)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .background(ColorPalette.background)
        .onChange(of: dashboardViewModel.selectedCardIds) { ids in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showRightPanel = !ids.isEmpty && !dashboardViewModel.isPreviewMode
            }
        }
        .onChange(of: dashboardViewModel.isPreviewMode) { isPreview in
            if isPreview {
                withAnimation { showRightPanel = false }
            }
        }
    }

    // MARK: - Add Card Helper

    /// Place a new card near the center of the visible canvas
    private func addCardToCenter(type: CardType) {
        // Default drop position: center of a nominal 1200×800 visible area
        let center = CGPoint(
            x: 600 - dashboardViewModel.canvasOffset.width / dashboardViewModel.zoomLevel,
            y: 400 - dashboardViewModel.canvasOffset.height / dashboardViewModel.zoomLevel
        )
        // Slightly randomise so multiple adds don't stack exactly
        let jitter = CGPoint(x: CGFloat.random(in: -20...20), y: CGFloat.random(in: -20...20))
        dashboardViewModel.addCard(type: type, at: CGPoint(x: center.x + jitter.x, y: center.y + jitter.y))
    }

    // MARK: - Right Config Panel

    @ViewBuilder
    private func cardConfigPanel(for card: DashboardCard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: cardTypeIcon(card.type))
                        .foregroundColor(cardTypeColor(card.type))
                        .font(.system(size: 14))
                    Text("Card Settings")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(ColorPalette.textPrimary)
                    Spacer()
                    Button(action: { dashboardViewModel.clearSelection() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Divider().background(ColorPalette.border)

                // Title field
                configField(label: "Title") {
                    cardTitleField(card: card)
                }

                // Card type badge
                configField(label: "Type") {
                    HStack(spacing: 6) {
                        Image(systemName: cardTypeIcon(card.type))
                            .font(.system(size: 10))
                            .foregroundColor(cardTypeColor(card.type))
                        Text(card.type.rawValue)
                            .font(.system(size: 11))
                            .foregroundColor(ColorPalette.textPrimary)
                    }
                }

                // Size info
                configField(label: "Size") {
                    Text("\(Int(card.size.width)) × \(Int(card.size.height)) pt")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(ColorPalette.textSecondary)
                }

                // Position info
                configField(label: "Position") {
                    Text("x: \(Int(card.position.x)), y: \(Int(card.position.y))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(ColorPalette.textSecondary)
                }

                Divider().background(ColorPalette.border)

                // Actions
                VStack(spacing: 8) {
                    actionButton(label: "Bring to Front", icon: "square.stack.3d.up.fill", color: ColorPalette.accent) {
                        dashboardViewModel.bringToFront(id: card.id)
                    }
                    actionButton(label: "Send to Back", icon: "square.stack.3d.down.right.fill", color: ColorPalette.textSecondary) {
                        dashboardViewModel.sendToBack(id: card.id)
                    }
                    actionButton(label: "Duplicate", icon: "plus.square.on.square", color: ColorPalette.success) {
                        dashboardViewModel.duplicateCard(id: card.id)
                    }
                    actionButton(label: "Delete Card", icon: "trash", color: ColorPalette.warning) {
                        dashboardViewModel.deleteCard(id: card.id)
                        withAnimation { showRightPanel = false }
                    }
                }
            }
            .padding(16)
        }
        .background(ColorPalette.sidebar)
    }

    // MARK: - Config Panel Helpers

    @ViewBuilder
    private func configField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(ColorPalette.textSecondary)
            content()
        }
    }

    @ViewBuilder
    private func cardTitleField(card: DashboardCard) -> some View {
        if let idx = dashboardViewModel.cards.firstIndex(where: { $0.id == card.id }) {
            TextField("Card title", text: $dashboardViewModel.cards[idx].title)
                .font(.system(size: 12))
                .foregroundColor(ColorPalette.textPrimary)
                .textFieldStyle(.plain)
                .padding(7)
                .background(ColorPalette.background.opacity(0.5))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorPalette.border, lineWidth: 1))
        }
    }

    @ViewBuilder
    private func actionButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ColorPalette.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(color.opacity(0.08))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
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
