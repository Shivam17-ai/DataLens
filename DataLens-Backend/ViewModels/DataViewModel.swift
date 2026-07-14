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
            showError("Unsupported file type ".\(ext)". Please import a CSV or Excel (.xlsx) file.")
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

    // MARK: - Reset

    func reset() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentDataSet   = nil
            errorMessage     = nil
            successMessage   = nil
            isLoading        = false
            isImportSuccess  = false
            currentFileType  = .csv
            availableSheets  = []
            selectedSheet    = nil
            sortColumn       = nil
            sortAscending    = true
            searchText       = ""
            filteredRows     = []
            displayStats     = [:]
            currentExcelURL  = nil
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
