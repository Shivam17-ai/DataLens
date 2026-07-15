import Foundation

// MARK: - Supporting Enums

/// Strategy for filling missing values in a column
enum FillStrategy {
    case mean
    case median
    case mode
    case custom(String)
}

/// Case conversion direction
enum CaseConversion {
    case upper
    case lower
}

/// Method for outlier removal
enum OutlierMethod {
    case iqr
    case zscore
    case customRange(lo: Double, hi: Double)
}

/// Calendar components that can be extracted from a date column
enum DateComponent: String, CaseIterable, Identifiable {
    case year    = "Year"
    case month   = "Month"
    case day     = "Day"
    case weekday = "Weekday"

    var id: String { rawValue }

    var calendarComponent: Calendar.Component {
        switch self {
        case .year:    return .year
        case .month:   return .month
        case .day:     return .day
        case .weekday: return .weekday
        }
    }
}

// MARK: - DataCleaner

/// Pure stateless cleaning service.
/// Every method accepts a DataSet and returns a new one — the caller manages state.
/// All async methods run on a background thread via Task.detached.
struct DataCleaner {

    // MARK: - Column Management

    /// Attempts to convert all values in `column` to `targetType`.
    /// Returns the new DataSet and the count of values that could not be converted.
    static func changeColumnType(
        dataset: DataSet,
        columnName: String,
        to targetType: ColumnType
    ) async -> (DataSet, Int) {
        return await Task.detached(priority: .userInitiated) {
            guard let colIndex = dataset.columns.firstIndex(where: { $0.name == columnName }) else {
                return (dataset, 0)
            }
            var failCount = 0
            let newRows: [Row] = dataset.rows.map { row in
                var values = row.values
                guard let raw = values[columnName] else { return row }
                let strVal = String(describing: raw)

                switch targetType {
                case .number:
                    if let d = Double(strVal) {
                        values[columnName] = d
                    } else {
                        values[columnName] = nil as Any?
                        failCount += 1
                    }
                case .date:
                    if let d = Self.parseDate(strVal) {
                        values[columnName] = d
                    } else {
                        values[columnName] = nil as Any?
                        failCount += 1
                    }
                case .text:
                    // Any value can be represented as text
                    values[columnName] = Self.formatForText(raw)
                }
                return Row(id: row.id, values: values)
            }

            var newCols = dataset.columns
            newCols[colIndex] = newCols[colIndex].withType(targetType)
            let label = "Change \(columnName) → \(targetType.label)"
            return (dataset.applying(columns: newCols, rows: newRows, label: label), failCount)
        }.value
    }

    /// Renames a column (updates both the column descriptor and every row's value dictionary key).
    static func renameColumn(dataset: DataSet, columnName: String, newName: String) async -> DataSet {
        return await Task.detached(priority: .userInitiated) {
            guard let colIndex = dataset.columns.firstIndex(where: { $0.name == columnName }) else {
                return dataset
            }
            var newCols = dataset.columns
            newCols[colIndex] = newCols[colIndex].withName(newName)

            let newRows: [Row] = dataset.rows.map { row in
                var values = row.values
                if let val = values.removeValue(forKey: columnName) {
                    values[newName] = val
                }
                return Row(id: row.id, values: values)
            }
            return dataset.applying(columns: newCols, rows: newRows, label: "Rename \"\(columnName)\" → \"\(newName)\"")
        }.value
    }

    /// Marks a column as hidden (it remains in the data but is not rendered).
    static func hideColumn(dataset: DataSet, columnName: String) async -> DataSet {
        return await Task.detached(priority: .userInitiated) {
            var newCols = dataset.columns
            if let i = newCols.firstIndex(where: { $0.name == columnName }) {
                newCols[i] = newCols[i].hidden()
            }
            return dataset.applying(columns: newCols, label: "Hide \"\(columnName)\"")
        }.value
    }

    /// Creates a copy of a column appended at the end with a "(Copy)" suffix.
    static func duplicateColumn(dataset: DataSet, columnName: String) async -> DataSet {
        return await Task.detached(priority: .userInitiated) {
            guard let srcCol = dataset.columns.first(where: { $0.name == columnName }) else {
                return dataset
            }
            let copyName = "\(columnName) (Copy)"
            let newCol = Column(name: copyName, type: srcCol.type, index: dataset.columns.count)
            let newCols = dataset.columns + [newCol]

            let newRows: [Row] = dataset.rows.map { row in
                var values = row.values
                values[copyName] = values[columnName]
                return Row(id: row.id, values: values)
            }
            return dataset.applying(columns: newCols, rows: newRows, label: "Duplicate \"\(columnName)\"")
        }.value
    }

    /// Permanently removes a column and all its values from the dataset.
    static func deleteColumn(dataset: DataSet, columnName: String) async -> DataSet {
        return await Task.detached(priority: .userInitiated) {
            let newCols = dataset.columns.filter { $0.name != columnName }
            let newRows: [Row] = dataset.rows.map { row in
                var values = row.values
                values.removeValue(forKey: columnName)
                return Row(id: row.id, values: values)
            }
            return dataset.applying(columns: newCols, rows: newRows, label: "Delete \"\(columnName)\"")
        }.value
    }

    // MARK: - Missing Values

    /// Removes every row that has a nil/empty value in any of the specified columns (or all columns when nil).
    static func removeMissingRows(dataset: DataSet, columns: [String]? = nil) async -> DataSet {
        return await Task.detached(priority: .userInitiated) {
            let targetCols = columns ?? dataset.columns.map(\.name)
            let newRows = dataset.rows.filter { row in
                targetCols.allSatisfy { col in row.values[col] != nil }
            }
            return dataset.applying(rows: newRows, label: "Remove Rows with Missing Values")
        }.value
    }

    /// Fills nil values in `columnName` using the chosen strategy.
    static func fillMissing(
        dataset: DataSet,
        columnName: String,
        strategy: FillStrategy
    ) async -> DataSet {
        return await Task.detached(priority: .userInitiated) {
            let fillValue: Any? = Self.computeFill(dataset: dataset, columnName: columnName, strategy: strategy)
            guard let fill = fillValue else { return dataset }

            let newRows: [Row] = dataset.rows.map { row in
                guard row.values[columnName] == nil else { return row }
                var values = row.values
                values[columnName] = fill
                return Row(id: row.id, values: values)
            }
            return dataset.applying(rows: newRows, label: "Fill Missing in \"\(columnName)\"")
        }.value
    }

    // MARK: - Duplicates

    /// Counts duplicate rows, comparing only the given columns (all columns when nil).
    static func countDuplicates(dataset: DataSet, columns: [String]? = nil) -> Int {
        let targetCols = columns ?? dataset.columns.map(\.name)
        var seen = Set<String>()
        var dups = 0
        for row in dataset.rows {
            let key = targetCols.map { col -> String in
                guard let v = row.values[col] else { return "" }
                return String(describing: v)
            }.joined(separator: "||")
            if seen.contains(key) { dups += 1 } else { seen.insert(key) }
        }
        return dups
    }

    /// Removes duplicate rows, keeping the first occurrence.
    static func removeDuplicates(dataset: DataSet, columns: [String]? = nil) async -> DataSet {
        return await Task.detached(priority: .userInitiated) {
            let targetCols = columns ?? dataset.columns.map(\.name)
            var seen = Set<String>()
            let newRows = dataset.rows.filter { row in
                let key = targetCols.map { col -> String in
                    guard let v = row.values[col] else { return "" }
                    return String(describing: v)
                }.joined(separator: "||")
                if seen.contains(key) { return false }
                seen.insert(key)
                return true
            }
            let removed = dataset.rowCount - newRows.count
            return dataset.applying(rows: newRows, label: "Remove Duplicates (−\(removed) rows)")
        }.value
    }

    // MARK: - Text Cleaning

    /// Trims leading and trailing whitespace from every string cell in `columnName`.
    static func trimWhitespace(dataset: DataSet, columnName: String) async -> DataSet {
        return await Task.detached(priority: .userInitiated) {
            Self.mapStringValues(dataset: dataset, column: columnName, label: "Trim Whitespace in \"\(columnName)\"") {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }.value
    }

    /// Converts all string values in `columnName` to upper or lower case.
    static func convertCase(dataset: DataSet, columnName: String, to conversion: CaseConversion) async -> DataSet {
        return await Task.detached(priority: .userInitiated) {
            let label = conversion == .upper
                ? "Uppercase \"\(columnName)\""
                : "Lowercase \"\(columnName)\""
            return Self.mapStringValues(dataset: dataset, column: columnName, label: label) {
                conversion == .upper ? $0.uppercased() : $0.lowercased()
            }
        }.value
    }

    /// Strips characters that are not letters, digits, or spaces from `columnName`.
    static func removeSpecialCharacters(dataset: DataSet, columnName: String) async -> DataSet {
        return await Task.detached(priority: .userInitiated) {
            Self.mapStringValues(dataset: dataset, column: columnName,
                                 label: "Remove Special Chars in \"\(columnName)\"") {
                $0.unicodeScalars
                    .filter { CharacterSet.alphanumerics.union(.whitespaces).contains($0) }
                    .reduce("") { $0 + String($1) }
            }
        }.value
    }

    /// Replaces occurrences of `find` with `replace` in `columnName`.
    static func findAndReplace(
        dataset: DataSet,
        columnName: String,
        find: String,
        replace: String,
        caseSensitive: Bool
    ) async -> DataSet {
        return await Task.detached(priority: .userInitiated) {
            let options: String.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
            return Self.mapStringValues(
                dataset: dataset,
                column: columnName,
                label: "Find & Replace in \"\(columnName)\""
            ) { $0.replacingOccurrences(of: find, with: replace, options: options) }
        }.value
    }

    // MARK: - Number Cleaning

    /// Rounds all numeric values in `columnName` to `decimals` decimal places.
    static func roundValues(dataset: DataSet, columnName: String, decimals: Int) async -> DataSet {
        return await Task.detached(priority: .userInitiated) {
            let factor = pow(10.0, Double(decimals))
            return Self.mapDoubleValues(dataset: dataset, column: columnName,
                                        label: "Round \"\(columnName)\" to \(decimals) dp") {
                (($0 * factor).rounded()) / factor
            }
        }.value
    }

    /// Min-max normalises values in `columnName` to the [0, 1] range.
    static func normalizeValues(dataset: DataSet, columnName: String) async -> DataSet {
        return await Task.detached(priority: .userInitiated) {
            let nums = dataset.rows.compactMap { $0.values[columnName] as? Double }
            guard let mn = nums.min(), let mx = nums.max(), mx != mn else { return dataset }
            return Self.mapDoubleValues(dataset: dataset, column: columnName,
                                        label: "Normalize \"\(columnName)\"") {
                ($0 - mn) / (mx - mn)
            }
        }.value
    }

    /// Z-score standardises values in `columnName` (mean=0, std=1).
    static func standardizeValues(dataset: DataSet, columnName: String) async -> DataSet {
        return await Task.detached(priority: .userInitiated) {
            let nums = dataset.rows.compactMap { $0.values[columnName] as? Double }
            guard nums.count > 1 else { return dataset }
            let mean = nums.reduce(0, +) / Double(nums.count)
            let variance = nums.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(nums.count)
            let std = sqrt(variance)
            guard std > 0 else { return dataset }
            return Self.mapDoubleValues(dataset: dataset, column: columnName,
                                        label: "Standardize \"\(columnName)\"") {
                ($0 - mean) / std
            }
        }.value
    }

    /// Removes rows whose value in `columnName` is considered an outlier.
    static func removeOutliers(
        dataset: DataSet,
        columnName: String,
        method: OutlierMethod
    ) async -> DataSet {
        return await Task.detached(priority: .userInitiated) {
            let nums = dataset.rows.compactMap { $0.values[columnName] as? Double }
            guard !nums.isEmpty else { return dataset }

            let (lo, hi): (Double, Double) = {
                switch method {
                case .iqr:
                    let sorted = nums.sorted()
                    let q1 = sorted[sorted.count / 4]
                    let q3 = sorted[(sorted.count * 3) / 4]
                    let iqr = q3 - q1
                    return (q1 - 1.5 * iqr, q3 + 1.5 * iqr)
                case .zscore:
                    let mean = nums.reduce(0, +) / Double(nums.count)
                    let std  = sqrt(nums.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(nums.count))
                    return (mean - 3 * std, mean + 3 * std)
                case .customRange(let l, let h):
                    return (l, h)
                }
            }()

            let newRows = dataset.rows.filter { row in
                guard let v = row.values[columnName] as? Double else { return true }
                return v >= lo && v <= hi
            }
            let removed = dataset.rowCount - newRows.count
            return dataset.applying(rows: newRows, label: "Remove Outliers in \"\(columnName)\" (−\(removed))")
        }.value
    }

    // MARK: - Date Cleaning

    /// Re-formats all date values in `columnName` to a chosen string format (stored as text).
    static func standardizeDateFormat(
        dataset: DataSet,
        columnName: String,
        outputFormat: String
    ) async -> DataSet {
        return await Task.detached(priority: .userInitiated) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = outputFormat

            let newRows: [Row] = dataset.rows.map { row in
                guard let date = row.values[columnName] as? Date else { return row }
                var values = row.values
                values[columnName] = formatter.string(from: date)
                return Row(id: row.id, values: values)
            }
            // Column becomes text after format standardisation
            var newCols = dataset.columns
            if let i = newCols.firstIndex(where: { $0.name == columnName }) {
                newCols[i] = newCols[i].withType(.text)
            }
            return dataset.applying(columns: newCols, rows: newRows,
                                    label: "Format \"\(columnName)\" as \(outputFormat)")
        }.value
    }

    /// Extracts a calendar component from `columnName` into a new column.
    static func extractDateComponent(
        dataset: DataSet,
        columnName: String,
        component: DateComponent,
        newColumnName: String? = nil
    ) async -> DataSet {
        return await Task.detached(priority: .userInitiated) {
            let cal = Calendar.current
            let destName = newColumnName ?? "\(columnName)_\(component.rawValue)"
            let newCol   = Column(name: destName, type: .number, index: dataset.columns.count)
            let newCols  = dataset.columns + [newCol]

            let newRows: [Row] = dataset.rows.map { row in
                var values = row.values
                if let date = values[columnName] as? Date {
                    let val = cal.component(component.calendarComponent, from: date)
                    values[destName] = Double(val)
                }
                return Row(id: row.id, values: values)
            }
            return dataset.applying(columns: newCols, rows: newRows,
                                    label: "Extract \(component.rawValue) from \"\(columnName)\"")
        }.value
    }

    // MARK: - Private Helpers

    private static func mapStringValues(
        dataset: DataSet,
        column: String,
        label: String,
        transform: (String) -> String
    ) -> DataSet {
        let newRows: [Row] = dataset.rows.map { row in
            guard let val = row.values[column] else { return row }
            var values = row.values
            values[column] = transform(String(describing: val))
            return Row(id: row.id, values: values)
        }
        return dataset.applying(rows: newRows, label: label)
    }

    private static func mapDoubleValues(
        dataset: DataSet,
        column: String,
        label: String,
        transform: (Double) -> Double
    ) -> DataSet {
        let newRows: [Row] = dataset.rows.map { row in
            guard let val = row.values[column] as? Double else { return row }
            var values = row.values
            values[column] = transform(val)
            return Row(id: row.id, values: values)
        }
        return dataset.applying(rows: newRows, label: label)
    }

    private static func computeFill(dataset: DataSet, columnName: String, strategy: FillStrategy) -> Any? {
        switch strategy {
        case .custom(let val):
            return val
        case .mean:
            let nums = dataset.rows.compactMap { $0.values[columnName] as? Double }
            return nums.isEmpty ? nil : nums.reduce(0, +) / Double(nums.count)
        case .median:
            let sorted = dataset.rows.compactMap { $0.values[columnName] as? Double }.sorted()
            guard !sorted.isEmpty else { return nil }
            let mid = sorted.count / 2
            return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2.0 : sorted[mid]
        case .mode:
            var freq: [String: Int] = [:]
            dataset.rows.forEach {
                if let v = $0.values[columnName] {
                    freq[String(describing: v), default: 0] += 1
                }
            }
            return freq.max { $0.value < $1.value }?.key
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        let formats = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy",
                       "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssZ"]
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for fmt in formats {
            f.dateFormat = fmt
            if let d = f.date(from: value) { return d }
        }
        return nil
    }

    private static func formatForText(_ value: Any) -> String {
        if let d = value as? Date {
            let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
            return f.string(from: d)
        }
        if let n = value as? Double {
            return n.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", n)
                : String(n)
        }
        return String(describing: value)
    }
}
