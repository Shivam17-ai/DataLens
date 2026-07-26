import SwiftUI

// MARK: - DashboardToolbar

/// Top bar of the Dashboard builder canvas. Provides:
///   - Add-card palette (chart / KPI / text / filter)
///   - Zoom controls with percentage display
///   - Preview / Edit mode toggle
///   - Snap-to-grid & grid-visibility toggles
///   - Fit-to-screen and reset zoom buttons
struct DashboardToolbar: View {

    @ObservedObject var dashboardViewModel: DashboardViewModel

    /// Callback when user wants to add a card at a default position
    var onAddCard: (CardType) -> Void

    @State private var showAddMenu: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // ── Left: Dashboard Title ─────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "rectangle.3.group.fill")
                    .foregroundColor(ColorPalette.accent)
                    .font(.system(size: 14))
                Text(dashboardViewModel.currentDashboard?.name ?? "Dashboard Builder")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(ColorPalette.textPrimary)
            }
            .frame(width: 200, alignment: .leading)

            Spacer()

            // ── Center: Add Card Button (popover) ─────────────────────
            ZStack {
                Button(action: { withAnimation { showAddMenu.toggle() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text("Add Card")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(ColorPalette.accent)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showAddMenu, arrowEdge: .bottom) {
                    addCardMenu
                }
            }

            Spacer()

            // ── Right: Zoom + Grid + Mode Controls ────────────────────
            HStack(spacing: 10) {
                // Grid lines toggle
                toolbarToggleButton(
                    icon: dashboardViewModel.currentDashboard?.gridEnabled == true ? "grid" : "square.dashed",
                    tooltip: "Toggle Grid",
                    isActive: dashboardViewModel.currentDashboard?.gridEnabled == true
                ) {
                    dashboardViewModel.currentDashboard?.gridEnabled.toggle()
                }

                // Snap to grid toggle
                toolbarToggleButton(
                    icon: "rectangle.and.arrow.up.right.and.arrow.down.left",
                    tooltip: "Snap to Grid",
                    isActive: dashboardViewModel.currentDashboard?.snapToGrid == true
                ) {
                    dashboardViewModel.currentDashboard?.snapToGrid.toggle()
                }

                Divider()
                    .frame(height: 20)
                    .background(ColorPalette.border)

                // Zoom out
                toolbarIconButton(icon: "minus.magnifyingglass", tooltip: "Zoom Out") {
                    dashboardViewModel.zoomLevel = max(0.5, dashboardViewModel.zoomLevel - 0.1)
                }

                // Zoom percentage
                Text("\(Int(dashboardViewModel.zoomLevel * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(ColorPalette.textSecondary)
                    .frame(width: 38)

                // Zoom in
                toolbarIconButton(icon: "plus.magnifyingglass", tooltip: "Zoom In") {
                    dashboardViewModel.zoomLevel = min(2.0, dashboardViewModel.zoomLevel + 0.1)
                }

                // Fit to screen
                toolbarIconButton(icon: "arrow.up.left.and.down.right.magnifyingglass", tooltip: "Fit to Screen") {
                    withAnimation(.spring()) {
                        dashboardViewModel.zoomLevel = 1.0
                        dashboardViewModel.canvasOffset = .zero
                    }
                }

                Divider()
                    .frame(height: 20)
                    .background(ColorPalette.border)

                // Preview / Edit mode
                Button(action: { withAnimation { dashboardViewModel.isPreviewMode.toggle() } }) {
                    HStack(spacing: 5) {
                        Image(systemName: dashboardViewModel.isPreviewMode ? "pencil.circle" : "eye.circle.fill")
                            .font(.system(size: 12))
                        Text(dashboardViewModel.isPreviewMode ? "Edit" : "Preview")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(dashboardViewModel.isPreviewMode ? ColorPalette.textSecondary : ColorPalette.success)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        dashboardViewModel.isPreviewMode
                            ? ColorPalette.border.opacity(0.3)
                            : ColorPalette.success.opacity(0.15)
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(ColorPalette.sidebar)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(ColorPalette.border),
            alignment: .bottom
        )
    }

    // MARK: - Add Card Menu

    private var addCardMenu: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Add to Canvas")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(ColorPalette.textSecondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 4)

            Divider().background(ColorPalette.border)

            ForEach(CardType.allCases, id: \.self) { type in
                cardTypeRow(type)
            }

            Divider().background(ColorPalette.border).padding(.top, 4)

            Text("Drop a card onto the canvas to position it")
                .font(.system(size: 9))
                .foregroundColor(ColorPalette.textSecondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
        .frame(width: 220)
        .background(ColorPalette.cards)
    }

    @ViewBuilder
    private func cardTypeRow(_ type: CardType) -> some View {
        Button(action: {
            showAddMenu = false
            onAddCard(type)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(cardTypeColor(type).opacity(0.18))
                        .frame(width: 30, height: 30)
                    Image(systemName: cardTypeIcon(type))
                        .font(.system(size: 14))
                        .foregroundColor(cardTypeColor(type))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ColorPalette.textPrimary)
                    Text(cardTypeDescription(type))
                        .font(.system(size: 10))
                        .foregroundColor(ColorPalette.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(Color.clear)
        .contentShape(Rectangle())
    }

    // MARK: - Reusable Toolbar Controls

    @ViewBuilder
    private func toolbarIconButton(icon: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ColorPalette.textSecondary)
                .frame(width: 28, height: 28)
                .background(ColorPalette.background.opacity(0.4))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    @ViewBuilder
    private func toolbarToggleButton(icon: String, tooltip: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isActive ? ColorPalette.accent : ColorPalette.textSecondary)
                .frame(width: 28, height: 28)
                .background(isActive ? ColorPalette.accent.opacity(0.15) : ColorPalette.background.opacity(0.4))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    // MARK: - Card Type Helpers

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

    private func cardTypeDescription(_ type: CardType) -> String {
        switch type {
        case .chart:  return "Bar, line, pie, scatter & more"
        case .text:   return "Rich text annotation block"
        case .kpi:    return "Single-metric callout card"
        case .filter: return "Interactive category dropdown"
        }
    }
}
