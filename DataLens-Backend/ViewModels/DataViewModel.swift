import SwiftUI
import Combine

/// Statistics structure representing aggregated metrics for a column in the dataset
struct ColumnStats {
    let type: ColumnType
    var sum: Double? = nil
    var average: Double? = nil
    var minNumeric: Double? = nil
    var maxNumeric: Double? = nil
    
    var uniqueCount: Int? = nil
    var mostCommonValue: String? = nil
    
    var earliestDate: Date? = nil
    var latestDate: Date? = nil
}

/// DataViewModel controls data import states and holds the actively parsed dataset
class DataViewModel: ObservableObject {
    @Published var currentDataSet: DataSet? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isImportSuccess: Bool = false
    
    // Sort and Search states
    @Published var sortColumn: String? = nil
    @Published var sortAscending: Bool = true
    @Published var searchText: String = ""
    
    // Dynamic lists derived from active dataset
    @Published var filteredRows: [Row] = []
    @Published var displayStats: [String: ColumnStats] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSearchDebounce()
    }
    
    /// Binds search query input publisher to trigger filter calculations with 300ms debounce
    private func setupSearchDebounce() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.applyFilterAndSort()
            }
            .store(in: &cancellables)
    }
    
    /// Imports a CSV file at the given URL asynchronously on a background thread
    func importCSV(url: URL) {
        // Enforce CSV extension
        guard url.pathExtension.lowercased() == "csv" else {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.errorMessage = "Only comma-separated values (.csv) files are supported."
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        isImportSuccess = false
        
        Task {
            do {
                let dataSet = try await CSVParser.parse(url: url)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.isLoading = false
                        self.isImportSuccess = true
                    }
                    
                    // Delay actual dataset assignment by 1 second to show checkmark transition
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.currentDataSet = dataSet
                            self.isImportSuccess = false
                            self.applyFilterAndSort() // Initial calculation of filtered list and stats
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    /// Cycles sorting order for the column: Ascending -> Descending -> None (Remove Sort)
    func sortData(by column: String) {
        if sortColumn == column {
            if sortAscending {
                sortAscending = false
            } else {
                sortColumn = nil
                sortAscending = true
            }
        } else {
            sortColumn = column
            sortAscending = true
        }
        applyFilterAndSort()
    }
    
    /// Returns filtered rows matching a query string (synchronous real-time helper)
    func searchData(query: String) -> [Row] {
        guard let dataset = currentDataSet else { return [] }
        if query.isEmpty { return dataset.rows }
        
        let lowerQuery = query.lowercased()
        let columns = dataset.columns
        
        return dataset.rows.filter { row in
            for col in columns {
                if let val = row.values[col.name] {
                    let strVal: String
                    if let dateVal = val as? Date {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .none
                        strVal = formatter.string(from: dateVal).lowercased()
                    } else {
                        strVal = String(describing: val).lowercased()
                    }
                    if strVal.contains(lowerQuery) {
                        return true
                    }
                }
            }
            return false
        }
    }
    
    /// Runs search filtering, sorting, and stats calculation in a background thread
    func applyFilterAndSort() {
        guard let dataset = currentDataSet else {
            self.filteredRows = []
            self.displayStats = [:]
            return
        }
        
        let query = searchText
        let col = sortColumn
        let ascending = sortAscending
        let columns = dataset.columns
        
        // Show indicator if the dataset is large
        if dataset.rowCount > 5000 {
            self.isLoading = true
        }
        
        Task.detached(priority: .userInitiated) {
            // 1. Filter rows
            var rows = dataset.rows
            if !query.isEmpty {
                let lowerQuery = query.lowercased()
                rows = rows.filter { row in
                    for column in columns {
                        if let val = row.values[column.name] {
                            let strVal: String
                            if let dateVal = val as? Date {
                                let formatter = DateFormatter()
                                formatter.dateStyle = .medium
                                formatter.timeStyle = .none
                                strVal = formatter.string(from: dateVal).lowercased()
                            } else {
                                strVal = String(describing: val).lowercased()
                            }
                            if strVal.contains(lowerQuery) {
                                return true
                            }
                        }
                    }
                    return false
                }
            }
            
            // 2. Sort rows
            if let sortCol = col, let column = columns.first(where: { $0.name == sortCol }) {
                rows.sort { (row1, row2) -> Bool in
                    let val1 = row1.values[sortCol]
                    let val2 = row2.values[sortCol]
                    
                    if val1 == nil && val2 == nil { return false }
                    if val1 == nil { return false } // nil items slide to bottom
                    if val2 == nil { return true }
                    
                    switch column.type {
                    case .number:
                        let n1 = val1 as? Double ?? -Double.infinity
                        let n2 = val2 as? Double ?? -Double.infinity
                        return ascending ? n1 < n2 : n1 > n2
                        
                    case .date:
                        let d1 = val1 as? Date ?? Date.distantPast
                        let d2 = val2 as? Date ?? Date.distantPast
                        return ascending ? d1 < d2 : d1 > d2
                        
                    case .text:
                        let s1 = String(describing: val1!)
                        let s2 = String(describing: val2!)
                        return ascending ? s1.localizedCompare(s2) == .orderedAscending : s1.localizedCompare(s2) == .orderedDescending
                    }
                }
            }
            
            // 3. Calculate statistics
            let stats = Self.computeStats(columns: columns, rows: rows)
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.filteredRows = rows
                    self.displayStats = stats
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Computes summary statistics for every column based on current rows
    private static func computeStats(columns: [Column], rows: [Row]) -> [String: ColumnStats] {
        var statsMap: [String: ColumnStats] = [:]
        
        for col in columns {
            let name = col.name
            let values = rows.compactMap { $0.values[name] }
            
            switch col.type {
            case .number:
                let numericValues = values.compactMap { $0 as? Double }
                if !numericValues.isEmpty {
                    let sum = numericValues.reduce(0, +)
                    let avg = sum / Double(numericValues.count)
                    let minVal = numericValues.min() ?? 0
                    let maxVal = numericValues.max() ?? 0
                    
                    statsMap[name] = ColumnStats(
                        type: .number,
                        sum: sum,
                        average: avg,
                        minNumeric: minVal,
                        maxNumeric: maxVal
                    )
                } else {
                    statsMap[name] = ColumnStats(type: .number)
                }
                
            case .date:
                let dateValues = values.compactMap { $0 as? Date }
                if !dateValues.isEmpty {
                    let earliest = dateValues.min()
                    let latest = dateValues.max()
                    
                    statsMap[name] = ColumnStats(
                        type: .date,
                        earliestDate: earliest,
                        latestDate: latest
                    )
                } else {
                    statsMap[name] = ColumnStats(type: .date)
                }
                
            case .text:
                let stringValues = values.map { String(describing: $0) }
                if !stringValues.isEmpty {
                    let uniqueValues = Set(stringValues)
                    
                    // Frequency frequency calculations
                    var frequencies: [String: Int] = [:]
                    for val in stringValues {
                        frequencies[val, default: 0] += 1
                    }
                    let mostCommon = frequencies.max { $0.value < $1.value }?.key
                    
                    statsMap[name] = ColumnStats(
                        type: .text,
                        uniqueCount: uniqueValues.count,
                        mostCommonValue: mostCommon
                    )
                } else {
                    statsMap[name] = ColumnStats(type: .text)
                }
            }
        }
        
        return statsMap
    }
    
    /// Retrieves all cell values for a specified column name
    func getColumnValues(columnName: String) -> [Any] {
        guard let dataset = currentDataSet else { return [] }
        return dataset.rows.compactMap { $0.values[columnName] }
    }
    
    /// Filters columns to only return numeric columns
    func getNumericColumns() -> [Column] {
        guard let dataset = currentDataSet else { return [] }
        return dataset.columns.filter { $0.type == .number }
    }
    
    /// Filters columns to only return text columns
    func getTextColumns() -> [Column] {
        guard let dataset = currentDataSet else { return [] }
        return dataset.columns.filter { $0.type == .text }
    }
    
    /// Resets the current state to allow importing a new file
    func reset() {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.currentDataSet = nil
            self.errorMessage = nil
            self.isLoading = false
            self.sortColumn = nil
            self.sortAscending = true
            self.searchText = ""
            self.filteredRows = []
            self.displayStats = [:]
        }
    }
}
