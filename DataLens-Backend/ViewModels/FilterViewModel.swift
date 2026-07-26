import SwiftUI
import Combine

// MARK: - FilterViewModel

/// Coordinates ALL filter types in priority order:
///   1. Date range filter    (applied first)
///   2. Cross filters        (from chart clicks)
///   3. Search text filter
///   4. Category dropdown filters
///
/// The fully-composed filtered dataset is published on `filteredDataSet`.
final class FilterViewModel: ObservableObject {

    // MARK: Published State

    @Published var filterState: FilterState = FilterState()
    @Published var dateRange: DateRangeFilter? = nil
    @Published var filteredDataSet: DataSet? = nil
    @Published var detectedDateColumns: [Column] = []
    @Published var isFiltering: Bool = false

    /// Convenience reference so views can read/write cross filters
    let crossFilterManager: CrossFilterManager

    // MARK: Private

    private var sourceDataSet: DataSet? = nil
    private var cancellables = Set<AnyCancellable>()
    private var filterWorkItem: DispatchWorkItem? = nil

    // MARK: Init

    init(crossFilterManager: CrossFilterManager) {
        self.crossFilterManager = crossFilterManager
        bindCrossFilterUpdates()
    }

    // MARK: Public API

    /// Load a new dataset: detect date columns and kick off initial filtering pass
    func load(dataset: DataSet) {
        sourceDataSet = dataset
        crossFilterManager.setSourceDataSet(dataset)
        detectedDateColumns = detectDateColumns(in: dataset)

        // Auto-select the first date column if none is selected
        if dateRange == nil, let firstDateCol = detectedDateColumns.first {
            let dates = extractDates(from: dataset, column: firstDateCol.name)
            if let minDate = dates.min(), let maxDate = dates.max() {
                dateRange = DateRangeFilter(from: minDate, to: maxDate, columnName: firstDateCol.name)
            }
        }
        scheduleFilterApplication()
    }

    /// Set a new date range and re-apply filters
    func setDateRange(_ range: DateRangeFilter) {
        dateRange = range
        filterState.dateRange = range
        scheduleFilterApplication()
    }

    /// Apply a cross filter emitted by a chart view
    func addCrossFilter(_ filter: CrossFilter) {
        crossFilterManager.addFilter(filter)
        // cross-filter updates trigger re-computation via Combine binding
    }

    /// Remove a cross filter by ID
    func removeCrossFilter(id: UUID) {
        crossFilterManager.removeFilter(id: id)
    }

    /// Clear all cross filters, date range, search text, and category selections
    func clearAllFilters() {
        crossFilterManager.clearAllFilters()
        dateRange = nil
        filterState = FilterState()
        scheduleFilterApplication()
    }

    // MARK: Category Filter Helpers

    /// Returns the unique string values for a column (used by CategoryDropdown to populate choices)
    func getAvailableCategories(for columnName: String, in dataset: DataSet) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for row in dataset.rows {
            let val = "\(row.values[columnName] ?? "(blank)")"
            if seen.insert(val).inserted { ordered.append(val) }
        }
        return ordered.sorted()
    }

    /// Programmatically set a category filter for a column
    func setCategoryFilter(column: String, values: [String]) {
        filterState.selectedCategories[column] = values
        scheduleFilterApplication()
    }

    /// Remove the category filter for a specific column
    func clearCategoryFilter(for column: String) {
        filterState.selectedCategories.removeValue(forKey: column)
        scheduleFilterApplication()
    }

    func getFilteredRowCount() -> Int { filteredDataSet?.rowCount ?? 0 }
    func getTotalRowCount() -> Int    { sourceDataSet?.rowCount ?? 0 }

    /// Save the current filter state (for dashboard persistence)
    func saveFilterState() -> FilterState {
        var state = FilterState()
        state.activeFilters = crossFilterManager.activeFilters
        state.dateRange = dateRange
        state.searchText = filterState.searchText
        state.selectedCategories = filterState.selectedCategories
        return state
    }

    /// Restore a previously saved filter state
    func restoreFilterState(_ state: FilterState) {
        filterState = state
        dateRange = state.dateRange
        crossFilterManager.activeFilters = state.activeFilters
        scheduleFilterApplication()
    }

    // MARK: Column Detection

    /// Returns only columns whose type is .date
    func detectDateColumns(in dataset: DataSet) -> [Column] {
        dataset.columns.filter { $0.type == .date }
    }

    // MARK: Private Filter Pipeline

    /// Subscribes to CrossFilterManager changes so any chart-emitted filter
    /// automatically triggers a full re-composition here.
    private func bindCrossFilterUpdates() {
        crossFilterManager.$activeFilters
            .dropFirst()
            .sink { [weak self] _ in self?.scheduleFilterApplication() }
            .store(in: &cancellables)
    }

    /// Debounced (200 ms) full filter pipeline on a background thread
    private func scheduleFilterApplication() {
        filterWorkItem?.cancel()
        isFiltering = true

        let work = DispatchWorkItem { [weak self] in
            guard let self, let source = self.sourceDataSet else { return }
            let result = self.applyAllFilters(to: source)
            DispatchQueue.main.async {
                self.filteredDataSet = result
                self.isFiltering = false
            }
        }

        filterWorkItem = work
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    /// Composed filter pipeline (date → cross → search → category)
    func applyAllFilters(to dataset: DataSet) -> DataSet {
        var result = dataset

        // 1. Date range
        if let dr = dateRange {
            let rows = result.rows.filter { row in
                guard let val = row.values[dr.columnName] as? Date else { return false }
                return val >= dr.from && val <= dr.to
            }
            result = result.applying(rows: rows, label: "Date Range")
        }

        // 2. Cross filters
        result = crossFilterManager.applyFilters(to: result)

        // 3. Search text
        let searchText = filterState.searchText.trimmingCharacters(in: .whitespaces)
        if !searchText.isEmpty {
            let lower = searchText.lowercased()
            let rows = result.rows.filter { row in
                row.values.values.contains { "\($0)".lowercased().contains(lower) }
            }
            result = result.applying(rows: rows, label: "Search Text")
        }

        // 4. Category dropdown filters
        for (column, values) in filterState.selectedCategories where !values.isEmpty {
            let rows = result.rows.filter { row in
                guard let val = row.values[column] else { return false }
                return values.contains("\(val)")
            }
            result = result.applying(rows: rows, label: "Category Filter")
        }

        return result
    }

    // MARK: Date Extraction Helper

    /// Extract all valid Date values from a column for slider range calculation
    func extractDates(from dataset: DataSet, column: String) -> [Date] {
        dataset.rows.compactMap { row in
            row.values[column] as? Date
        }
    }

    /// Build histogram bins for the mini-timeline above the date slider
    func buildDateHistogram(from dataset: DataSet, column: String, binCount: Int = 30) -> [Int] {
        let dates = extractDates(from: dataset, column: column)
        guard !dates.isEmpty, let minDate = dates.min(), let maxDate = dates.max() else {
            return Array(repeating: 0, count: binCount)
        }

        let totalInterval = maxDate.timeIntervalSince(minDate)
        guard totalInterval > 0 else { return Array(repeating: dates.count, count: 1) }

        var bins = Array(repeating: 0, count: binCount)
        for date in dates {
            let fraction = date.timeIntervalSince(minDate) / totalInterval
            let idx = min(Int(fraction * Double(binCount)), binCount - 1)
            bins[idx] += 1
        }
        return bins
    }
}
