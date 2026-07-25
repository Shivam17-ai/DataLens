import Foundation
import SwiftUI

// MARK: - Filter Type

/// Describes how a cross-filter constrains data.
/// Each case carries the parameters needed to test a row's cell value.
enum FilterType: Equatable {
    case categorical(values: [String])
    case numerical(min: Double, max: Double)
    case dateRange(from: Date, to: Date)
    case topN(n: Int, column: String)

    /// A short human-readable description of the filter constraint
    var displayLabel: String {
        switch self {
        case .categorical(let vals):
            if vals.count == 1 { return vals[0] }
            return "\(vals.count) values"
        case .numerical(let min, let max):
            return String(format: "%.1f – %.1f", min, max)
        case .dateRange(let from, let to):
            let df = DateFormatter()
            df.dateStyle = .medium
            return "\(df.string(from: from)) → \(df.string(from: to))"
        case .topN(let n, _):
            return "Top \(n)"
        }
    }
}

// MARK: - Cross Filter

/// A single filter published by one chart that can affect all other charts.
struct CrossFilter: Identifiable, Equatable {
    /// Unique filter identity
    let id: UUID
    /// The chart that emitted this filter (used to avoid self-filtering)
    let sourceChartId: UUID
    /// Dataset column this filter applies to
    let columnName: String
    /// The constraint to apply
    let filterType: FilterType
    /// Human-readable label shown in the filter chip bar
    let label: String
    /// Whether this filter is currently contributing to the result set
    var isActive: Bool

    init(
        id: UUID = UUID(),
        sourceChartId: UUID,
        columnName: String,
        filterType: FilterType,
        label: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.sourceChartId = sourceChartId
        self.columnName = columnName
        self.filterType = filterType
        self.label = label ?? "\(columnName): \(filterType.displayLabel)"
        self.isActive = isActive
    }
}

// MARK: - Date Range Filter

/// Stores the current date range slider selection as a dedicated model
struct DateRangeFilter: Equatable {
    var from: Date
    var to: Date
    var columnName: String
}

// MARK: - Filter State

/// A snapshot of the full filter configuration; can be saved and restored.
struct FilterState {
    var activeFilters: [CrossFilter] = []
    var dateRange: DateRangeFilter? = nil
    var searchText: String = ""
    var selectedCategories: [String: [String]] = [:]

    /// True when no filters are applied at all
    var isEmpty: Bool {
        activeFilters.isEmpty
            && dateRange == nil
            && searchText.isEmpty
            && selectedCategories.values.allSatisfy { $0.isEmpty }
    }
}
