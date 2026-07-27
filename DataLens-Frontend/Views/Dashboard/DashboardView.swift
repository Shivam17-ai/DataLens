import SwiftUI

// MARK: - DashboardView

/// Main container for Week 3 Day 3's Dashboard builder and management.
/// Renders multi-tab bar, gallery list screen when no tabs open, and template/save dialog sheets.
struct DashboardView: View {

    @StateObject private var dashboardViewModel = DashboardViewModel()
    @State private var showRightPanel: Bool = false

    /// Optional dataset injected by parent
    var dataset: DataSet? = nil

    var body: some View {
        VStack(spacing: 0) {
            // ── Top Browser-Style Tab Bar ──────────────────────────────
            tabBarHeader

            Divider().background(ColorPalette.border)

            // ── Content Router: Active Tab Canvas vs. Dashboards List ─────
            if let activeId = dashboardViewModel.activeTabId, dashboardViewModel.currentDashboard != nil {
                canvasView
            } else {
                DashboardListView(dashboardViewModel: dashboardViewModel)
            }
        }
        .background(ColorPalette.background)
        .overlay(
            // Toast Notification Overlay
            VStack {
                Spacer()
                if let toast = dashboardViewModel.toastMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ColorPalette.success)
                        Text(toast)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(ColorPalette.cards.opacity(0.95))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(ColorPalette.accent, lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(), value: dashboardViewModel.toastMessage)
        )
        .sheet(isPresented: $dashboardViewModel.showSaveDialog) {
            SaveDashboardDialog(dashboardViewModel: dashboardViewModel)
        }
        .sheet(isPresented: $dashboardViewModel.showTemplateSelector) {
            TemplatePickerView(dashboardViewModel: dashboardViewModel)
        }
        // Keyboard Shortcut Cmd+S
        .background(
            Button("") {
                Task {
                    try? await dashboardViewModel.saveCurrent()
                }
            }
            .keyboardShortcut("s", modifiers: .command)
            .hidden()
        )
    }

    // MARK: - Canvas View

    private var canvasView: some View {
        VStack(spacing: 0) {
            // Main Canvas Toolbar
            DashboardToolbar(
                dashboardViewModel: dashboardViewModel,
                onAddCard: { cardType in
                    addCardToCenter(type: cardType)
                },
                onBackToList: {
                    dashboardViewModel.activeTabId = nil
                }
            )

            // Canvas Grid + Config Side Panel
            HStack(spacing: 0) {
                DashboardGridView(
                    dashboardViewModel: dashboardViewModel,
                    dataset: dataset
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showRightPanel, let selectedId = dashboardViewModel.selectedCardIds.first,
                   let card = dashboardViewModel.cards.first(where: { $0.id == selectedId }) {
                    Divider().background(ColorPalette.border)
                    cardConfigPanel(for: card)
                        .frame(width: 260)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
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

    // MARK: - Browser-Style Tab Bar Header

    private var tabBarHeader: some View {
        HStack(spacing: 4) {
            // Home / Gallery Tab Button
            Button(action: {
                dashboardViewModel.activeTabId = nil
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 11))
                    Text("All Dashboards")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(dashboardViewModel.activeTabId == nil ? ColorPalette.textPrimary : ColorPalette.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(dashboardViewModel.activeTabId == nil ? ColorPalette.cards : Color.clear)
                .cornerRadius(6, corners: [.topLeft, .topRight])
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 16)
                .background(ColorPalette.border)

            // Open Dashboard Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(dashboardViewModel.openTabs) { tab in
                        let isActive = dashboardViewModel.activeTabId == tab.id
                        
                        HStack(spacing: 6) {
                            // Unsaved Amber Dot
                            if isActive && dashboardViewModel.hasUnsavedChanges {
                                Circle()
                                    .fill(Color(hex: "#F59E0B") ?? ColorPalette.warning)
                                    .frame(width: 6, height: 6)
                            }

                            Text(tab.name)
                                .font(.system(size: 11, weight: isActive ? .bold : .medium))
                                .foregroundColor(isActive ? ColorPalette.textPrimary : ColorPalette.textSecondary)
                                .lineLimit(1)

                            // Close Button (X)
                            Button(action: {
                                dashboardViewModel.closeTab(id: tab.id)
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(ColorPalette.textSecondary)
                                    .padding(3)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(isActive ? ColorPalette.cards : ColorPalette.sidebar)
                        .cornerRadius(6, corners: [.topLeft, .topRight])
                        .overlay(
                            Rectangle()
                                .frame(height: isActive ? 2 : 0)
                                .foregroundColor(ColorPalette.accent),
                            alignment: .bottom
                        )
                        .onTapGesture {
                            dashboardViewModel.switchTab(to: tab.id)
                        }
                    }
                }
            }

            // New Tab (+) Button
            if dashboardViewModel.openTabs.count < 5 {
                Button(action: {
                    dashboardViewModel.showTemplateSelector = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ColorPalette.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(ColorPalette.sidebar)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("New Dashboard Tab")
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .background(ColorPalette.sidebar)
    }

    // MARK: - Add Card Helper

    private func addCardToCenter(type: CardType) {
        let center = CGPoint(
            x: 600 - dashboardViewModel.canvasOffset.width / dashboardViewModel.zoomLevel,
            y: 400 - dashboardViewModel.canvasOffset.height / dashboardViewModel.zoomLevel
        )
        let jitter = CGPoint(x: CGFloat.random(in: -20...20), y: CGFloat.random(in: -20...20))
        dashboardViewModel.addCard(type: type, at: CGPoint(x: center.x + jitter.x, y: center.y + jitter.y))
    }

    // MARK: - Right Config Panel

    @ViewBuilder
    private func cardConfigPanel(for card: DashboardCard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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

                configField(label: "Title") {
                    cardTitleField(card: card)
                }

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

                configField(label: "Size") {
                    Text("\(Int(card.size.width)) × \(Int(card.size.height)) pt")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(ColorPalette.textSecondary)
                }

                configField(label: "Position") {
                    Text("x: \(Int(card.position.x)), y: \(Int(card.position.y))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(ColorPalette.textSecondary)
                }

                Divider().background(ColorPalette.border)

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

    private func configField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(ColorPalette.textSecondary)
            content()
        }
    }

    private func cardTitleField(card: DashboardCard) -> some View {
        Group {
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
    }

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

// MARK: - Save Dashboard Dialog Sheet

struct SaveDashboardDialog: View {
    @ObservedObject var dashboardViewModel: DashboardViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var name: String = ""
    @State private var descriptionText: String = ""
    @State private var tagsText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "square.and.arrow.down.fill")
                    .foregroundColor(ColorPalette.accent)
                    .font(.system(size: 16))
                Text("Save Dashboard")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ColorPalette.textPrimary)
                Spacer()
            }

            Divider().background(ColorPalette.border)

            VStack(alignment: .leading, spacing: 6) {
                Text("DASHBOARD NAME")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.textSecondary)
                TextField("e.g. Q3 Sales Overview", text: $name)
                    .font(.system(size: 12))
                    .padding(8)
                    .background(ColorPalette.background)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorPalette.border, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("DESCRIPTION (OPTIONAL)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.textSecondary)
                TextField("Add description...", text: $descriptionText)
                    .font(.system(size: 12))
                    .padding(8)
                    .background(ColorPalette.background)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorPalette.border, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("TAGS (COMMA SEPARATED)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.textSecondary)
                TextField("sales, q3, executive", text: $tagsText)
                    .font(.system(size: 12))
                    .padding(8)
                    .background(ColorPalette.background)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorPalette.border, lineWidth: 1))
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(ColorPalette.textSecondary)

                Spacer()

                Button("Save Dashboard") {
                    dashboardViewModel.currentDashboard?.name = name.isEmpty ? "Untitled Dashboard" : name
                    dashboardViewModel.currentDashboard?.description = descriptionText
                    dashboardViewModel.currentDashboard?.tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    
                    Task {
                        try? await dashboardViewModel.saveCurrent()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(ColorPalette.accent)
                .cornerRadius(6)
            }
        }
        .padding(20)
        .frame(width: 400, height: 340)
        .background(ColorPalette.cards)
        .onAppear {
            if let db = dashboardViewModel.currentDashboard {
                name = db.name
                descriptionText = db.description
                tagsText = db.tags.joined(separator: ", ")
            }
        }
    }
}

// MARK: - Template Picker Sheet

struct TemplatePickerView: View {
    @ObservedObject var dashboardViewModel: DashboardViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "rectangle.3.group.fill")
                    .foregroundColor(ColorPalette.accent)
                    .font(.system(size: 16))
                Text("Choose Dashboard Template")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ColorPalette.textPrimary)
                Spacer()
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Divider().background(ColorPalette.border)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(DashboardTemplate.allCases) { template in
                        Button(action: {
                            dashboardViewModel.newDashboard(from: template)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: template.accentHex)?.opacity(0.2) ?? ColorPalette.accent.opacity(0.2))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: template.iconName)
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(hex: template.accentHex) ?? ColorPalette.accent)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.rawValue)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(ColorPalette.textPrimary)
                                    Text(template.description)
                                        .font(.system(size: 11))
                                        .foregroundColor(ColorPalette.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(ColorPalette.textSecondary)
                            }
                            .padding(12)
                            .background(ColorPalette.sidebar)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ColorPalette.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(ColorPalette.textSecondary)
            }
        }
        .padding(20)
        .frame(width: 480, height: 460)
        .background(ColorPalette.cards)
    }
}
