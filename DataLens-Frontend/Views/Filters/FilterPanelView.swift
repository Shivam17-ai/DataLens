import SwiftUI

// MARK: - FilterPanelView

/// Collapsible side panel (or sheet) that contains:
///  - Active cross-filter chip list with clear buttons
///  - Date range slider (hidden when no date columns detected)
///  - Search text field
struct FilterPanelView: View {

    @ObservedObject var filterViewModel: FilterViewModel
    @EnvironmentObject var crossFilterManager: CrossFilterManager

    /// The raw (unfiltered) dataset – used for date slider bounds and histogram
    let dataset: DataSet

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header ──────────────────────────────────────────────
                filterPanelHeader

                Divider().background(ColorPalette.border)

                VStack(alignment: .leading, spacing: 16) {

                    // ── Active Cross Filters ─────────────────────────────
                    if !crossFilterManager.activeFilters.isEmpty {
                        activeCrossFiltersSection
                    }

                    // ── Date Range Slider ─────────────────────────────────
                    dateRangeSection

                    // ── Search ────────────────────────────────────────────
                    searchSection

                    // ── Stats footer ──────────────────────────────────────
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
            if filterViewModel.filterState.activeFilters.count > 0
                || crossFilterManager.hasActiveFilters
                || filterViewModel.dateRange != nil {
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
        VStack(alignment: .leading, spacing: 8) {
            Label("Active Cross Filters", systemImage: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(ColorPalette.textSecondary)

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
            VStack(spacing: 6) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 20))
                    .foregroundColor(ColorPalette.textSecondary.opacity(0.5))
                Text("No date column found")
                    .font(.system(size: 11))
                    .foregroundColor(ColorPalette.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("Date Range", systemImage: "calendar")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(ColorPalette.textSecondary)

                ForEach(dateColumns) { column in
                    DateRangeSlider(
                        filterViewModel: filterViewModel,
                        dataset: dataset,
                        dateColumn: column
                    )
                }
            }
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Search", systemImage: "magnifyingglass")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(ColorPalette.textSecondary)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ColorPalette.textSecondary)
                    .font(.system(size: 12))
                TextField("Search all columns...", text: $filterViewModel.filterState.searchText)
                    .font(.system(size: 12))
                    .foregroundColor(ColorPalette.textPrimary)
                    .textFieldStyle(.plain)
                if !filterViewModel.filterState.searchText.isEmpty {
                    Button(action: { filterViewModel.filterState.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(ColorPalette.background.opacity(0.5))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ColorPalette.border, lineWidth: 1))
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
