import SwiftUI
import Combine

// MARK: - CrossFilterManager

/// Singleton-like ObservableObject injected at app level via @EnvironmentObject.
/// Every chart view reads from and writes to this manager so selections on one
/// chart automatically propagate to all others ("Power BI cross-filtering").
final class CrossFilterManager: ObservableObject {

    // MARK: Published State

    /// All cross-filters emitted by chart interactions
    @Published var activeFilters: [CrossFilter] = []

    /// The dataset after applying all active filters (nil = no data loaded yet)
    @Published var filteredDataSet: DataSet? = nil

    /// True while background filter application is in progress
    @Published var isFiltering: Bool = false

    // MARK: Private State

    /// The unmodified source dataset used as the baseline for filtering
    private var sourceDataSet: DataSet? = nil

    /// Debounce work item so rapid filter changes don't thrash the CPU
    private var filterWorkItem: DispatchWorkItem? = nil

    // MARK: Computed Helpers

    /// True when at least one active filter exists
    var hasActiveFilters: Bool {
        !activeFilters.filter(\.isActive).isEmpty
    }

    /// Short human-readable summary displayed in the filter bar header
    var filterSummary: String {
        let count = activeFilters.filter(\.isActive).count
        if count == 0 { return "No active filters" }
        return "\(count) filter\(count == 1 ? "" : "s") active"
    }

    /// Number of rows after applying all filters
    var filteredRowCount: Int { filteredDataSet?.rowCount ?? 0 }

    /// Total rows before any filtering
    var totalRowCount: Int { sourceDataSet?.rowCount ?? 0 }

    // MARK: Public API

    /// Call when a new dataset is loaded so the manager can track the source
    func setSourceDataSet(_ dataset: DataSet) {
        sourceDataSet = dataset
        // On a fresh load, re-apply any lingering filters
        scheduleFilterApplication()
    }

    /// Add or replace a filter from a given chart on a given column.
    /// If the same chart already has a filter on the same column it is replaced
    /// (prevents stacking "same-axis" duplicates while allowing multi-column filters).
    func addFilter(_ filter: CrossFilter) {
        activeFilters.removeAll {
            $0.sourceChartId == filter.sourceChartId && $0.columnName == filter.columnName
        }
        activeFilters.append(filter)
        scheduleFilterApplication()
    }

    /// Remove a specific filter by its ID
    func removeFilter(id: UUID) {
        activeFilters.removeAll { $0.id == id }
        scheduleFilterApplication()
    }

    /// Disable all filters and restore the full dataset immediately
    func clearAllFilters() {
        filterWorkItem?.cancel()
        activeFilters.removeAll()
        filteredDataSet = sourceDataSet
        isFiltering = false
    }

    /// Apply the current set of active filters to any arbitrary DataSet
    /// (used by FilterViewModel for final pipeline composition)
    func applyFilters(to dataset: DataSet) -> DataSet {
        let actives = activeFilters.filter(\.isActive)
        guard !actives.isEmpty else { return dataset }

        let filteredRows = dataset.rows.filter { row in
            actives.allSatisfy { matchesFilter(row: row, filter: $0) }
        }
        return dataset.applying(rows: filteredRows, label: "Cross Filter")
    }

    // MARK: Private Helpers

    /// Debounced (200 ms) background filter application
    private func scheduleFilterApplication() {
        filterWorkItem?.cancel()
        isFiltering = true

        let work = DispatchWorkItem { [weak self] in
            guard let self, let source = self.sourceDataSet else { return }
            let result = self.applyFilters(to: source)
            DispatchQueue.main.async {
                self.filteredDataSet = result
                self.isFiltering = false
            }
        }

        filterWorkItem = work
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    /// Test whether a single row passes the constraint expressed by one CrossFilter
    private func matchesFilter(row: Row, filter: CrossFilter) -> Bool {
        let value = row.values[filter.columnName]

        switch filter.filterType {
        case .categorical(let allowed):
            let strVal: String
            if let v = value {
                strVal = "\(v)"
            } else {
                strVal = ""
            }
            return allowed.contains(strVal)

        case .numerical(let min, let max):
            var num: Double? = nil
            if let d = value as? Double       { num = d }
            else if let i = value as? Int     { num = Double(i) }
            else if let s = value as? String  { num = Double(s) }
            guard let n = num else { return false }
            return n >= min && n <= max

        case .dateRange(let from, let to):
            guard let dateVal = value as? Date else { return false }
            return dateVal >= from && dateVal <= to

        case .topN:
            // TopN is resolved at aggregation level before this call; pass through
            return true
        }
    }
}
