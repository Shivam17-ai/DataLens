import SwiftUI
import Combine

// MARK: - Supporting Types

/// The source file format of the most recently imported dataset
enum FileType: String {
    case csv   = "CSV"
    case excel = "XLSX"

    /// SF Symbol icon representing the file type
    var iconName: String {
        switch self {
        case .csv:   return "doc.plaintext.fill"
        case .excel: return "tablecells.fill"
        }
    }
}

/// Statistics structure representing aggregated metrics for a column in the dataset
struct ColumnStats {
    let type: ColumnType
    var sum: Double?        = nil
    var average: Double?    = nil
    var minNumeric: Double? = nil
    var maxNumeric: Double? = nil
    var uniqueCount: Int?   = nil
    var mostCommonValue: String? = nil
    var earliestDate: Date? = nil
    var latestDate: Date?   = nil
}

/// Defines a distinct, value-type cleaning action that can be performed on the dataset.
enum CleaningOperation {
    case changeType(columnName: String, type: ColumnType)
    case rename(columnName: String, newName: String)
    case hide(columnName: String)
    case duplicate(columnName: String)
    case delete(columnName: String)
    case removeMissing(columns: [String]?)
    case fillMissing(columnName: String, strategy: FillStrategy)
    case removeDuplicates(columns: [String]?)
    case trimWhitespace(columnName: String)
    case convertCase(columnName: String, conversion: CaseConversion)
    case removeSpecialCharacters(columnName: String)
    case findAndReplace(columnName: String, find: String, replace: String, caseSensitive: Bool)
    case round(columnName: String, decimals: Int)
    case normalize(columnName: String)
    case standardize(columnName: String)
    case removeOutliers(columnName: String, method: OutlierMethod)
    case standardizeDate(columnName: String, format: String)
    case extractDateComponent(columnName: String, component: DateComponent, newColumnName: String?)

    /// Returns a localized display name describing the operation (used in tooltips, banners, and history tracking).
    var label: String {
        switch self {
        case .changeType(let col, let type):
            return "Change \(col) → \(type.label)"
        case .rename(let col, let newName):
            return "Rename \"\(col)\" → \"\(newName)\""
        case .hide(let col):
            return "Hide \"\(col)\""
        case .duplicate(let col):
            return "Duplicate \"\(col)\""
        case .delete(let col):
            return "Delete \"\(col)\""
        case .removeMissing:
            return "Remove Rows with Missing Values"
        case .fillMissing(let col, _):
            return "Fill Missing in \"\(col)\""
        case .removeDuplicates:
            return "Remove Duplicates"
        case .trimWhitespace(let col):
            return "Trim Whitespace in \"\(col)\""
        case .convertCase(let col, let conv):
            return conv == .upper ? "Uppercase \"\(col)\"" : "Lowercase \"\(col)\""
        case .removeSpecialCharacters(let col):
            return "Remove Special Chars in \"\(col)\""
        case .findAndReplace(let col, _, _, _):
            return "Find & Replace in \"\(col)\""
        case .round(let col, let dec):
            return "Round \"\(col)\" to \(dec) dp"
        case .normalize(let col):
            return "Normalize \"\(col)\""
        case .standardize(let col):
            return "Standardize \"\(col)\""
        case .removeOutliers(let col, _):
            return "Remove Outliers in \"\(col)\""
        case .standardizeDate(let col, let fmt):
            return "Format \"\(col)\" as \(fmt)"
        case .extractDateComponent(let col, let comp, _):
            return "Extract \(comp.rawValue) from \"\(col)\""
        }
    }
}

// MARK: - DataViewModel

/// Shared state controller for the active dataset, import states, search, sort and statistics.
/// Injected at app level as an @EnvironmentObject.
class DataViewModel: ObservableObject {

    // MARK: Import State
    @Published var currentDataSet: DataSet? = nil
    @Published var isLoading: Bool          = false
    @Published var errorMessage: String?    = nil
    @Published var isImportSuccess: Bool    = false
    @Published var successMessage: String?  = nil
    @Published var currentFileType: FileType = .csv

    // MARK: Excel Sheet State
    @Published var availableSheets: [SheetInfo] = []
    @Published var selectedSheet: String?       = nil

    // MARK: Sort / Search / Filter State
    @Published var sortColumn: String?   = nil
    @Published var sortAscending: Bool   = true
    @Published var searchText: String    = ""
    @Published var filteredRows: [Row]   = []
    @Published var displayStats: [String: ColumnStats] = [:]

    // MARK: Cleaning State
    /// Ring buffer of up to 10 DataSet snapshots for undo/redo
    @Published var cleaningHistory: [DataSet] = []
    @Published var historyIndex: Int          = -1
    @Published var isCleaningPanelOpen: Bool  = false
    @Published var cleaningMessage: String?   = nil

    /// True when there is a previous state to restore
    var canUndo: Bool { historyIndex > 0 }
    /// True when there is a later state to move forward to
    var canRedo: Bool { historyIndex < cleaningHistory.count - 1 }
    /// Label of the operation that would be undone, for tooltip display
    var undoLabel: String { historyIndex > 0 ? (cleaningHistory[historyIndex].operationLabel ?? "Undo") : "Undo" }
    /// Label of the operation that would be re-applied, for tooltip display
    var redoLabel: String {
        let next = historyIndex + 1
        return next < cleaningHistory.count ? (cleaningHistory[next].operationLabel ?? "Redo") : "Redo"
    }

    // MARK: Private
    private var cancellables       = Set<AnyCancellable>()
    private var currentExcelURL: URL? = nil   // retained for sheet switching

    // MARK: - Init

    init() {
        setupSearchDebounce()
    }

    /// Subscribes to searchText changes and triggers filter/sort after 300 ms of inactivity
    private func setupSearchDebounce() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in self?.applyFilterAndSort() }
            .store(in: &cancellables)
    }

    // MARK: - Unified Import Dispatcher

    /// Routes a dropped or picked file URL to the correct parser based on file extension
    func importFile(url: URL) {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "csv":
            importCSV(url: url)
        case "xlsx", "xls":
            importExcel(url: url)
        default:
            showError("Unsupported file type \"\(ext)\". Please import a CSV or Excel (.xlsx) file.")
        }
    }

    // MARK: - CSV Import

    /// Imports a CSV file asynchronously, shows success/failure states, then triggers filter/sort
    func importCSV(url: URL) {
        guard url.pathExtension.lowercased() == "csv" else {
            showError("Only comma-separated values (.csv) files are supported.")
            return
        }

        beginLoading(fileType: .csv)

        Task {
            do {
                let dataSet = try await CSVParser.parse(url: url)
                let msg = "CSV imported successfully — \(dataSet.rowCount) rows, \(dataSet.columnCount) columns"
                await finishLoading(dataSet: dataSet, fileType: .csv, successMessage: msg, sheets: [], selectedSheet: nil)
            } catch {
                await failLoading(error: error)
            }
        }
    }

    // MARK: - Excel Import

    /// Opens an Excel workbook: first reads sheet names, then parses the first (or only) sheet
    func importExcel(url: URL) {
        beginLoading(fileType: .excel)
        currentExcelURL = url

        Task {
            do {
                // Step 1 — fetch available sheets
                let sheets = try await ExcelParser.getSheetNames(url: url)
                guard !sheets.isEmpty else {
                    await failLoading(error: ExcelError.emptySheet)
                    return
                }

                // Step 2 — parse the first sheet by default
                let firstSheetName = sheets[0].name
                let dataSet = try await ExcelParser.parse(url: url, sheetName: firstSheetName)
                let msg = "Excel imported successfully — Sheet: \(firstSheetName), \(dataSet.rowCount) rows, \(dataSet.columnCount) columns"

                await finishLoading(dataSet: dataSet,
                                    fileType: .excel,
                                    successMessage: msg,
                                    sheets: sheets,
                                    selectedSheet: firstSheetName)
            } catch {
                await failLoading(error: error)
            }
        }
    }

    // MARK: - Sheet Switching

    /// Re-parses the stored Excel URL using a different sheet name
    func switchSheet(to sheetName: String) {
        guard let url = currentExcelURL else { return }
        guard sheetName != selectedSheet else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let dataSet = try await ExcelParser.parse(url: url, sheetName: sheetName)
                let msg = "Excel imported successfully — Sheet: \(sheetName), \(dataSet.rowCount) rows, \(dataSet.columnCount) columns"
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.selectedSheet = sheetName
                        self.currentDataSet = dataSet
                        self.successMessage = msg
                        self.isLoading = false
                    }
                    self.applyFilterAndSort()
                }
            } catch {
                await failLoading(error: error)
            }
        }
    }

    // MARK: - Sort / Filter

    /// Cycles through Ascending → Descending → No Sort for the given column
    func sortData(by column: String) {
        if sortColumn == column {
            if sortAscending { sortAscending = false }
            else { sortColumn = nil; sortAscending = true }
        } else {
            sortColumn = column
            sortAscending = true
        }
        applyFilterAndSort()
    }

    /// Returns filtered rows matching query across all columns (synchronous helper for one-off use)
    func searchData(query: String) -> [Row] {
        guard let dataset = currentDataSet else { return [] }
        if query.isEmpty { return dataset.rows }
        let lowerQ = query.lowercased()
        return dataset.rows.filter { rowMatchesQuery($0, columns: dataset.columns, query: lowerQ) }
    }

    /// Filters, sorts, and recalculates stats on a background thread, then publishes results
    func applyFilterAndSort() {
        guard let dataset = currentDataSet else {
            filteredRows = []; displayStats = [:]; return
        }

        let query   = searchText
        let col     = sortColumn
        let asc     = sortAscending
        let columns = dataset.columns

        if dataset.rowCount > 5_000 { isLoading = true }

        Task.detached(priority: .userInitiated) {
            // 1 — Filter
            var rows = dataset.rows
            if !query.isEmpty {
                let lq = query.lowercased()
                rows = rows.filter { self.rowMatchesQuery($0, columns: columns, query: lq) }
            }

            // 2 — Sort
            if let sortCol = col, let column = columns.first(where: { $0.name == sortCol }) {
                rows.sort { r1, r2 in
                    let v1 = r1.values[sortCol]
                    let v2 = r2.values[sortCol]
                    if v1 == nil && v2 == nil { return false }
                    if v1 == nil { return false }
                    if v2 == nil { return true }

                    switch column.type {
                    case .number:
                        return asc
                            ? (v1 as? Double ?? -.infinity) < (v2 as? Double ?? -.infinity)
                            : (v1 as? Double ?? -.infinity) > (v2 as? Double ?? -.infinity)
                    case .date:
                        return asc
                            ? (v1 as? Date ?? .distantPast) < (v2 as? Date ?? .distantPast)
                            : (v1 as? Date ?? .distantPast) > (v2 as? Date ?? .distantPast)
                    case .text:
                        let s1 = String(describing: v1!), s2 = String(describing: v2!)
                        return asc
                            ? s1.localizedCompare(s2) == .orderedAscending
                            : s1.localizedCompare(s2) == .orderedDescending
                    }
                }
            }

            // 3 — Compute stats
            let stats = Self.computeStats(columns: columns, rows: rows)

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.filteredRows  = rows
                    self.displayStats  = stats
                    self.isLoading     = false
                }
            }
        }
    }

    // MARK: - Column Utilities

    func getColumnValues(columnName: String) -> [Any] {
        currentDataSet?.rows.compactMap { $0.values[columnName] } ?? []
    }

    func getNumericColumns() -> [Column] {
        currentDataSet?.columns.filter { $0.type == .number } ?? []
    }

    func getTextColumns() -> [Column] {
        currentDataSet?.columns.filter { $0.type == .text } ?? []
    }

    // MARK: - Cleaning Operations

    /// Runs a value-type CleaningOperation on a background thread and pushes the resulting DataSet onto the history stack.
    func applyCleaningOperation(_ operation: CleaningOperation) {
        guard let dataset = currentDataSet else { return }
        isLoading = true
        cleaningMessage = nil

        Task {
            let result: DataSet
            var failCount = 0

            switch operation {
            case .changeType(let col, let targetType):
                let (res, fc) = await DataCleaner.changeColumnType(dataset: dataset, columnName: col, to: targetType)
                result = res
                failCount = fc
            case .rename(let col, let newName):
                result = await DataCleaner.renameColumn(dataset: dataset, columnName: col, newName: newName)
            case .hide(let col):
                result = await DataCleaner.hideColumn(dataset: dataset, columnName: col)
            case .duplicate(let col):
                result = await DataCleaner.duplicateColumn(dataset: dataset, columnName: col)
            case .delete(let col):
                result = await DataCleaner.deleteColumn(dataset: dataset, columnName: col)
            case .removeMissing(let cols):
                result = await DataCleaner.removeMissingRows(dataset: dataset, columns: cols)
            case .fillMissing(let col, let strategy):
                result = await DataCleaner.fillMissing(dataset: dataset, columnName: col, strategy: strategy)
            case .removeDuplicates(let cols):
                result = await DataCleaner.removeDuplicates(dataset: dataset, columns: cols)
            case .trimWhitespace(let col):
                result = await DataCleaner.trimWhitespace(dataset: dataset, columnName: col)
            case .convertCase(let col, let conversion):
                result = await DataCleaner.convertCase(dataset: dataset, columnName: col, to: conversion)
            case .removeSpecialCharacters(let col):
                result = await DataCleaner.removeSpecialCharacters(dataset: dataset, columnName: col)
            case .findAndReplace(let col, let find, let replace, let caseSensitive):
                result = await DataCleaner.findAndReplace(dataset: dataset, columnName: col, find: find, replace: replace, caseSensitive: caseSensitive)
            case .round(let col, let decimals):
                result = await DataCleaner.roundValues(dataset: dataset, columnName: col, decimals: decimals)
            case .normalize(let col):
                result = await DataCleaner.normalizeValues(dataset: dataset, columnName: col)
            case .standardize(let col):
                result = await DataCleaner.standardizeValues(dataset: dataset, columnName: col)
            case .removeOutliers(let col, let method):
                result = await DataCleaner.removeOutliers(dataset: dataset, columnName: col, method: method)
            case .standardizeDate(let col, let format):
                result = await DataCleaner.standardizeDateFormat(dataset: dataset, columnName: col, outputFormat: format)
            case .extractDateComponent(let col, let component, let newCol):
                result = await DataCleaner.extractDateComponent(dataset: dataset, columnName: col, component: component, newColumnName: newCol)
            }

            await MainActor.run {
                // Truncate forward history when branching
                if historyIndex < cleaningHistory.count - 1 {
                    cleaningHistory = Array(cleaningHistory.prefix(historyIndex + 1))
                }
                // Append new snapshot (cap at 10)
                cleaningHistory.append(result)
                if cleaningHistory.count > 10 {
                    cleaningHistory.removeFirst()
                }
                historyIndex = cleaningHistory.count - 1

                withAnimation(.easeInOut(duration: 0.2)) {
                    self.currentDataSet = result
                    self.isLoading = false
                }

                // Set feedback message
                if case .changeType = operation {
                    if failCount > 0 {
                        self.cleaningMessage = "⚠️ \(failCount) value(s) could not be converted and were set to empty."
                    } else {
                        self.cleaningMessage = "✓ All values converted successfully."
                    }
                } else {
                    self.cleaningMessage = "✓ Applied: \(operation.label)"
                }

                self.applyFilterAndSort()
            }
        }
    }

    /// Reverts the dataset to the previous snapshot in the history stack
    func undo() {
        guard canUndo else { return }
        historyIndex -= 1
        withAnimation(.easeInOut(duration: 0.2)) {
            currentDataSet = cleaningHistory[historyIndex]
        }
        applyFilterAndSort()
    }

    /// Re-applies the next snapshot in the history stack
    func redo() {
        guard canRedo else { return }
        historyIndex += 1
        withAnimation(.easeInOut(duration: 0.2)) {
            currentDataSet = cleaningHistory[historyIndex]
        }
        applyFilterAndSort()
    }

    // MARK: - Reset

    func reset() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentDataSet    = nil
            errorMessage      = nil
            successMessage    = nil
            isLoading         = false
            isImportSuccess   = false
            currentFileType   = .csv
            availableSheets   = []
            selectedSheet     = nil
            sortColumn        = nil
            sortAscending     = true
            searchText        = ""
            filteredRows      = []
            displayStats      = [:]
            currentExcelURL   = nil
            cleaningHistory   = []
            historyIndex      = -1
            isCleaningPanelOpen = false
            cleaningMessage   = nil
        }
    }

    // MARK: - Private Helpers

    private func beginLoading(fileType: FileType) {
        isLoading       = true
        errorMessage    = nil
        successMessage  = nil
        isImportSuccess = false
        currentFileType = fileType
    }

    @MainActor
    private func finishLoading(
        dataSet: DataSet,
        fileType: FileType,
        successMessage: String,
        sheets: [SheetInfo],
        selectedSheet: String?
    ) {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.isLoading      = false
            self.isImportSuccess = true
            self.availableSheets = sheets
            self.selectedSheet   = selectedSheet
            self.currentFileType = fileType
        }
        self.successMessage = successMessage

        // Brief checkmark, then reveal the data table
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.currentDataSet  = dataSet
                self.isImportSuccess = false
            }
            self.applyFilterAndSort()
        }
    }

    @MainActor
    private func failLoading(error: Error) {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.errorMessage = error.localizedDescription
            self.isLoading    = false
        }
        // Auto-dismiss error banner after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.errorMessage = nil
            }
        }
    }

    private func showError(_ message: String) {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.errorMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.errorMessage = nil
            }
        }
    }

    private func rowMatchesQuery(_ row: Row, columns: [Column], query: String) -> Bool {
        for col in columns {
            guard let val = row.values[col.name] else { continue }
            let str: String
            if let d = val as? Date {
                let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
                str = f.string(from: d)
            } else {
                str = String(describing: val)
            }
            if str.lowercased().contains(query) { return true }
        }
        return false
    }

    private static func computeStats(columns: [Column], rows: [Row]) -> [String: ColumnStats] {
        var map: [String: ColumnStats] = [:]
        for col in columns {
            let values = rows.compactMap { $0.values[col.name] }
            switch col.type {
            case .number:
                let nums = values.compactMap { $0 as? Double }
                if nums.isEmpty { map[col.name] = ColumnStats(type: .number); continue }
                let sum = nums.reduce(0, +)
                map[col.name] = ColumnStats(type: .number,
                                            sum: sum,
                                            average: sum / Double(nums.count),
                                            minNumeric: nums.min(),
                                            maxNumeric: nums.max())
            case .date:
                let dates = values.compactMap { $0 as? Date }
                map[col.name] = ColumnStats(type: .date,
                                            earliestDate: dates.min(),
                                            latestDate: dates.max())
            case .text:
                let strs = values.map { String(describing: $0) }
                var freq: [String: Int] = [:]
                strs.forEach { freq[$0, default: 0] += 1 }
                map[col.name] = ColumnStats(type: .text,
                                            uniqueCount: Set(strs).count,
                                            mostCommonValue: freq.max { $0.value < $1.value }?.key)
            }
        }
        return map
    }
}
