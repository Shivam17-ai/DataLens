import SwiftUI

// MARK: - FilterPanelView (Updated - Week 3 Day 2)

/// Collapsible side panel containing:
///  - Active cross-filter chip list with clear buttons
///  - Date range slider (hidden when no date columns detected)
///  - SearchBarView (debounced, scoped, with history)
///  - Category dropdown filters (one per detected text column)
struct FilterPanelView: View {

    @ObservedObject var filterViewModel: FilterViewModel
    @EnvironmentObject var crossFilterManager: CrossFilterManager

    /// The raw (unfiltered) dataset – used for date slider bounds, histogram, and category value extraction
    let dataset: DataSet

    /// Collapsed sections
    @State private var crossFiltersExpanded: Bool = true
    @State private var dateRangeExpanded: Bool = true
    @State private var searchExpanded: Bool = true
    @State private var categoriesExpanded: Bool = true

    // Text columns available for category dropdowns
    private var textColumns: [Column] {
        dataset.columns.filter { $0.type == .string }.prefix(6).map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                filterPanelHeader

                Divider().background(ColorPalette.border)

                VStack(alignment: .leading, spacing: 12) {

                    // ── Active Cross Filters ───────────────────────────────
                    if !crossFilterManager.activeFilters.isEmpty {
                        FilterSection(
                            title: "Active Cross Filters",
                            icon: "point.3.connected.trianglepath.dotted",
                            isExpanded: $crossFiltersExpanded
                        ) {
                            activeCrossFiltersSection
                        }
                    }

                    // ── Date Range Slider ──────────────────────────────────
                    FilterSection(
                        title: "Date Range",
                        icon: "calendar",
                        isExpanded: $dateRangeExpanded
                    ) {
                        dateRangeSection
                    }

                    // ── Search ─────────────────────────────────────────────
                    FilterSection(
                        title: "Search",
                        icon: "magnifyingglass",
                        isExpanded: $searchExpanded
                    ) {
                        SearchBarView(
                            filterViewModel: filterViewModel,
                            dataset: dataset
                        )
                    }

                    // ── Category Dropdowns ─────────────────────────────────
                    if !textColumns.isEmpty {
                        FilterSection(
                            title: "Category Filters",
                            icon: "tag.fill",
                            isExpanded: $categoriesExpanded
                        ) {
                            categoryFiltersSection
                        }
                    }

                    // ── Row Count Footer ───────────────────────────────────
                    rowCountBadge
                }
                .padding(14)
            }
        }
        .background(ColorPalette.sidebar)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sub-views

    private var filterPanelHeader: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundColor(ColorPalette.accent)
                .font(.system(size: 14))
            Text("Filters")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(ColorPalette.textPrimary)
            Spacer()

            let hasFilters = filterViewModel.filterState.activeFilters.count > 0
                || crossFilterManager.hasActiveFilters
                || filterViewModel.dateRange != nil
                || !filterViewModel.filterState.searchText.isEmpty
                || !filterViewModel.filterState.selectedCategories.isEmpty

            if hasFilters {
                Button("Clear All") {
                    filterViewModel.clearAllFilters()
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(ColorPalette.warning)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var activeCrossFiltersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(crossFilterManager.activeFilters) { filter in
                HStack(spacing: 8) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.8))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(filter.columnName)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                        Text(filter.filterType.displayLabel)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer()

                    Button(action: { crossFilterManager.removeFilter(id: filter.id) }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ColorPalette.accent)
                .cornerRadius(8)
            }
        }
    }

    @ViewBuilder
    private var dateRangeSection: some View {
        let dateColumns = filterViewModel.detectedDateColumns

        if dateColumns.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 16))
                    .foregroundColor(ColorPalette.textSecondary.opacity(0.5))
                Text("No date column found")
                    .font(.system(size: 11))
                    .foregroundColor(ColorPalette.textSecondary)
            }
            .padding(.vertical, 8)
        } else {
            ForEach(dateColumns) { column in
                DateRangeSlider(
                    filterViewModel: filterViewModel,
                    dataset: dataset,
                    dateColumn: column
                )
            }
        }
    }

    private var categoryFiltersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(textColumns) { column in
                CategoryDropdown(
                    column: column,
                    dataset: dataset,
                    filterViewModel: filterViewModel
                )
                .environmentObject(crossFilterManager)
            }

            // Indicate if there are more text columns beyond the 6 shown
            let totalText = dataset.columns.filter { $0.type == .string }.count
            if totalText > 6 {
                Text("+ \(totalText - 6) more columns not shown")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(ColorPalette.textSecondary)
                    .padding(.top, 2)
            }
        }
    }

    private var rowCountBadge: some View {
        let filtered = filterViewModel.getFilteredRowCount()
        let total    = filterViewModel.getTotalRowCount()

        return HStack {
            if filterViewModel.isFiltering {
                ProgressView()
                    .scaleEffect(0.6)
            }
            Spacer()
            Text("\(filtered) of \(total) rows")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(filtered < total ? ColorPalette.warning : ColorPalette.textSecondary)
        }
        .padding(.top, 4)
    }
}

// MARK: - FilterSection Collapsible Container

private struct FilterSection<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(ColorPalette.accent)
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ColorPalette.textSecondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(ColorPalette.background.opacity(0.3))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ColorPalette.border.opacity(0.5), lineWidth: 1))
    }
}
