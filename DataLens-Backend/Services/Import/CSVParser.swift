import Foundation

/// Defines specific errors encountered during CSV parsing operations
enum CSVError: Error, LocalizedError {
    case invalidEncoding
    case emptyFile
    case tooLarge
    case fileAccessError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "Unable to read file content. Please check if the file encoding is UTF-8."
        case .emptyFile:
            return "The selected CSV file is empty."
        case .tooLarge:
            return "File exceeds the 50 MB limit. Please split the file into smaller parts."
        case .fileAccessError(let msg):
            return "Could not access the file: \(msg)"
        }
    }
}

/// Helper service for loading, parsing, and type-inferencing CSV files
struct CSVParser {
    
    /// 50 MB file size limit in bytes
    private static let maxFileSizeBytes: Int = 50 * 1024 * 1024

    /// Parses a CSV file asynchronously on a background thread
    static func parse(url: URL) async throws -> DataSet {
        // Resolve security scoped resource if sandboxed in macOS
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Guard against files that exceed the size limit
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attrs?[.size] as? Int, size > maxFileSizeBytes {
            throw CSVError.tooLarge
        }
        
        do {
            let data = try Data(contentsOf: url)
            guard let content = String(data: data, encoding: .utf8) else {
                throw CSVError.invalidEncoding
            }
            
            return try await Task.detached(priority: .userInitiated) {
                let parsedLines = parseRawCSV(content)
                guard !parsedLines.isEmpty else {
                    throw CSVError.emptyFile
                }
                
                let filename = url.lastPathComponent
                return processParsedLines(parsedLines, filename: filename)
            }.value
        } catch let error as CSVError {
            throw error
        } catch {
            throw CSVError.fileAccessError(error.localizedDescription)
        }
    }
    
    /// Basic robust CSV field extractor (handles double-quoted text, escaped quotes, newlines)
    private static func parseRawCSV(_ content: String) -> [[String]] {
        var result: [[String]] = []
        var currentField = ""
        var currentRecord: [String] = []
        var inQuotes = false
        
        let chars = Array(content)
        var i = 0
        let count = chars.count
        
        while i < count {
            let char = chars[i]
            
            if inQuotes {
                if char == "\"" {
                    if i + 1 < count && chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    currentField.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == "," {
                    currentRecord.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
                    currentField = ""
                } else if char == "\n" || char == "\r" {
                    currentRecord.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
                    // Avoid inserting completely empty spacer lines
                    if currentRecord.contains(where: { !$0.isEmpty }) {
                        result.append(currentRecord)
                    }
                    currentRecord = []
                    currentField = ""
                    
                    if char == "\r" && i + 1 < count && chars[i + 1] == "\n" {
                        i += 1
                    }
                } else {
                    currentField.append(char)
                }
            }
            i += 1
        }
        
        if !currentField.isEmpty || !currentRecord.isEmpty {
            currentRecord.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
            if currentRecord.contains(where: { !$0.isEmpty }) {
                result.append(currentRecord)
            }
        }
        
        return result
    }
    
    /// Processes the parsed matrix of strings into typed DataSet structure
    private static func processParsedLines(_ lines: [[String]], filename: String) -> DataSet {
        guard !lines.isEmpty else {
            return DataSet(name: filename, columns: [], rows: [])
        }
        
        let columnCount = lines.map { $0.count }.max() ?? 0
        guard columnCount > 0 else {
            return DataSet(name: filename, columns: [], rows: [])
        }
        
        // Pad all rows to match columnCount to prevent array out of bounds
        let paddedLines = lines.map { row -> [String] in
            if row.count < columnCount {
                return row + Array(repeating: "", count: columnCount - row.count)
            } else if row.count > columnCount {
                return Array(row[0..<columnCount])
            }
            return row
        }
        
        let firstRow = paddedLines[0]
        let hasHeader = detectHasHeader(firstRow: firstRow, subsequentRows: Array(paddedLines.dropFirst()))
        
        let headerRow: [String]
        let dataRows: [[String]]
        
        if hasHeader {
            headerRow = firstRow
            dataRows = Array(paddedLines.dropFirst())
        } else {
            headerRow = (0..<columnCount).map { "Column \($0 + 1)" }
            dataRows = paddedLines
        }
        
        // Detect Column Types
        var columns: [Column] = []
        var columnTypes: [ColumnType] = []
        
        for colIndex in 0..<columnCount {
            let colValues = dataRows.map { $0[colIndex] }
            let detectedType = detectColumnType(values: colValues)
            columnTypes.append(detectedType)
            
            let columnName = headerRow[colIndex].isEmpty ? "Column \(colIndex + 1)" : headerRow[colIndex]
            columns.append(Column(name: columnName, type: detectedType, index: colIndex))
        }
        
        // Build rows and parse typed values
        var rows: [Row] = []
        for line in dataRows {
            var rowValues: [String: Any] = [:]
            for colIndex in 0..<columnCount {
                let columnName = columns[colIndex].name
                let rawValue = line[colIndex]
                let type = columnTypes[colIndex]
                
                if rawValue.isEmpty {
                    continue
                }
                
                switch type {
                case .number:
                    if let number = Double(rawValue) {
                        rowValues[columnName] = number
                    } else {
                        rowValues[columnName] = rawValue
                    }
                case .date:
                    if let date = parseDate(rawValue) {
                        rowValues[columnName] = date
                    } else {
                        rowValues[columnName] = rawValue
                    }
                case .text:
                    rowValues[columnName] = rawValue
                }
            }
            rows.append(Row(values: rowValues))
        }
        
        return DataSet(name: filename, columns: columns, rows: rows)
    }
    
    /// Detects if the first row represents a column header
    private static func detectHasHeader(firstRow: [String], subsequentRows: [[String]]) -> Bool {
        guard !subsequentRows.isEmpty else { return false }
        
        var headerScore = 0
        var dataScore = 0
        
        let colCount = firstRow.count
        for colIndex in 0..<colCount {
            let cell = firstRow[colIndex]
            let cellType = detectValueType(cell)
            
            // Get types of subsequent rows in this column
            let subsequentCellTypes = subsequentRows.compactMap { row -> ColumnType? in
                guard colIndex < row.count else { return nil }
                let val = row[colIndex]
                return val.isEmpty ? nil : detectValueType(val)
            }
            
            // If subsequent rows have numeric or date values, but header is just text, it's a strong header signal
            let isSubsequentNumericOrDate = subsequentCellTypes.contains { $0 == .number || $0 == .date }
            if isSubsequentNumericOrDate && cellType == .text {
                headerScore += 1
            } else if !subsequentCellTypes.isEmpty && cellType == subsequentCellTypes[0] {
                dataScore += 1
            }
        }
        
        if headerScore > 0 {
            return true
        }
        if dataScore > 0 {
            return false
        }
        
        // Fallback: If first row has no empty cells and all are strings
        return firstRow.allSatisfy { !$0.isEmpty && detectValueType($0) == .text }
    }
    
    /// Detects type of a single string cell
    private static func detectValueType(_ value: String) -> ColumnType {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if Double(trimmed) != nil {
            return .number
        }
        if parseDate(trimmed) != nil {
            return .date
        }
        return .text
    }
    
    /// Detects type of a column based on all its non-empty cells
    private static func detectColumnType(values: [String]) -> ColumnType {
        let nonPadded = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !nonPadded.isEmpty else { return .text }
        
        var numbersCount = 0
        var datesCount = 0
        var textsCount = 0
        
        for val in nonPadded {
            let type = detectValueType(val)
            switch type {
            case .number: numbersCount += 1
            case .date: datesCount += 1
            case .text: textsCount += 1
            }
        }
        
        let total = nonPadded.count
        // If > 90% is numeric, class as numeric
        if Double(numbersCount) / Double(total) > 0.9 {
            return .number
        }
        // If > 90% is date, class as date
        if Double(datesCount) / Double(total) > 0.9 {
            return .date
        }
        return .text
    }
    
    /// Parses string representation into Date based on common templates
    private static func parseDate(_ value: String) -> Date? {
        let formats = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "dd/MM/yyyy",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        ]
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}
