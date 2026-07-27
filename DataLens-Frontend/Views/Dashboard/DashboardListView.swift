import SwiftUI
import AppKit

/// Gallery-style list screen showing saved dashboards in a 3-column grid
struct DashboardListView: View {

    @ObservedObject var dashboardViewModel: DashboardViewModel

    @State private var dashboardToDelete: DashboardLayout? = nil
    @State private var showDeleteConfirmation: Bool = false

    private var columns: [GridItem] = [
        GridItem(.adaptive(minimum: 280, maximum: 320), spacing: 20)
    ]

    private var filteredDashboards: [DashboardLayout] {
        var list = dashboardViewModel.allDashboards

        // Search Filter
        let query = dashboardViewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            list = list.filter { d in
                d.name.lowercased().contains(query) ||
                d.description.lowercased().contains(query) ||
                d.tags.contains { $0.lowercased().contains(query) }
            }
        }

        // Sorting
        switch dashboardViewModel.sortOption {
        case .lastModified:
            list.sort { $0.updatedAt > $1.updatedAt }
        case .createdDate:
            list.sort { $0.createdAt > $1.createdAt }
        case .name:
            list.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        }

        return list
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Top Header Toolbar ────────────────────────────────────────
            topToolbar

            Divider().background(ColorPalette.border)

            // ── Main Content Area ────────────────────────────────────────
            if dashboardViewModel.allDashboards.isEmpty {
                emptyStateView
            } else if filteredDashboards.isEmpty {
                noSearchResultsView
            } else {
                dashboardGrid
            }
        }
        .background(ColorPalette.background)
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete Dashboard?"),
                message: Text("Are you sure you want to delete '\(dashboardToDelete?.name ?? "this dashboard")'? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    if let id = dashboardToDelete?.id {
                        Task {
                            await dashboardViewModel.deleteDashboard(id: id)
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: - Subviews

    private var topToolbar: some View {
        VStack(spacing: 12) {
            // Prominent Full Width Banner Button for New Dashboard
            Button(action: {
                dashboardViewModel.showTemplateSelector = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Create New Dashboard")
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                    Image(systemName: "rectangle.3.group.fill")
                        .font(.system(size: 16))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(ColorPalette.accent)
                .cornerRadius(8)
                .shadow(color: ColorPalette.accent.opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)

            HStack(spacing: 16) {
                // Search Input
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ColorPalette.textSecondary)
                        .font(.system(size: 12))
                    TextField("Search dashboards by name or tag...", text: $dashboardViewModel.searchQuery)
                        .font(.system(size: 12))
                        .foregroundColor(ColorPalette.textPrimary)
                        .textFieldStyle(.plain)
                    if !dashboardViewModel.searchQuery.isEmpty {
                        Button(action: { dashboardViewModel.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(ColorPalette.sidebar)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ColorPalette.border, lineWidth: 1))

                // Sort Picker
                Menu {
                    ForEach(DashboardViewModel.SortOption.allCases) { option in
                        Button(action: { dashboardViewModel.sortOption = option }) {
                            HStack {
                                Text(option.rawValue)
                                if dashboardViewModel.sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 11))
                        Text(dashboardViewModel.sortOption.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(ColorPalette.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(ColorPalette.sidebar)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(ColorPalette.border, lineWidth: 1))
                }
                .menuStyle(.borderlessButton)

                // Import Button
                Button(action: handleImport) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Import")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(ColorPalette.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(ColorPalette.sidebar)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(ColorPalette.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(ColorPalette.sidebar.opacity(0.5))
    }

    private var dashboardGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(filteredDashboards) { dashboard in
                    DashboardThumbnailView(
                        dashboard: dashboard,
                        onOpen: {
                            dashboardViewModel.openDashboard(id: dashboard.id)
                        },
                        onDuplicate: {
                            Task {
                                await dashboardViewModel.duplicateDashboard(id: dashboard.id)
                            }
                        },
                        onDelete: {
                            dashboardToDelete = dashboard
                            showDeleteConfirmation = true
                        },
                        onExport: {
                            handleExport(dashboard: dashboard)
                        }
                    )
                }
            }
            .padding(24)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(ColorPalette.accent.opacity(0.15))
                    .frame(width: 90, height: 90)
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 40))
                    .foregroundColor(ColorPalette.accent)
            }

            Text("No Dashboards Yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ColorPalette.textPrimary)

            Text("Create custom analytics dashboards with charts, KPIs, and interactive filters.")
                .font(.system(size: 12))
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Button(action: {
                dashboardViewModel.showTemplateSelector = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Your First Dashboard")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(ColorPalette.accent)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noSearchResultsView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(ColorPalette.textSecondary.opacity(0.6))
            Text("No Dashboards Found")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(ColorPalette.textPrimary)
            Text("No results match '\(dashboardViewModel.searchQuery)'")
                .font(.system(size: 12))
                .foregroundColor(ColorPalette.textSecondary)
            Button("Clear Search") {
                dashboardViewModel.searchQuery = ""
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(ColorPalette.accent)
            .buttonStyle(.plain)
            Spacer()
        }
    }

    // MARK: - Import / Export Actions

    private func handleImport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Import Dashboard"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await dashboardViewModel.importDashboard(from: url)
            }
        }
    }

    private func handleExport(dashboard: DashboardLayout) {
        guard let tempURL = dashboardViewModel.exportDashboard(id: dashboard.id) else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(dashboard.name).datalens"
        panel.prompt = "Save Dashboard"

        if panel.runModal() == .OK, let destURL = panel.url {
            try? FileManager.default.copyItem(at: tempURL, to: destURL)
            dashboardViewModel.showToast("Dashboard Exported")
        }
    }
}
