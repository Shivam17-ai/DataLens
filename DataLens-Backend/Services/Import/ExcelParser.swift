import Foundation
import CoreXLSX

// MARK: - Error Types

/// Errors specific to Excel (.xlsx) parsing operations
enum ExcelError: Error, LocalizedError {
    case fileAccessError(String)
    case tooLarge
    case passwordProtected
    case corrupted(String)
    case emptySheet
    case sheetNotFound(String)

    var errorDescription: String? {
        switch self {
        case .fileAccessError(let msg):
            return "Could not access the file: \(msg)"
        case .tooLarge:
            return "File exceeds the 50 MB limit. Please split the file into smaller parts."
        case .passwordProtected:
            return "This Excel file is password protected. Please remove the password and try again."
        case .corrupted(let msg):
            return "The Excel file appears to be corrupted and cannot be opened. (\(msg))"
        case .emptySheet:
            return "The selected sheet is empty. Please choose a different sheet."
        case .sheetNotFound(let name):
            return "The sheet \"\(name)\" could not be found in this workbook."
        }
    }
}

// MARK: - Sheet Metadata

/// Lightweight metadata about a single worksheet
struct SheetInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let rowCount: Int
    let columnCount: Int
}

// MARK: - Parser

/// Parses .xlsx files using the CoreXLSX package.
/// Mirrors the CSVParser structure: background-threaded, produces identical DataSet output.
struct ExcelParser {

    // 50 MB limit in bytes
    private static let maxFileSizeBytes: Int = 50 * 1024 * 1024

    // MARK: - Public API

    /// Returns metadata for every worksheet in the workbook without fully parsing cell data.
    /// Runs on a background thread.
    static func getSheetNames(url: URL) async throws -> [SheetInfo] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        try validateFileSize(url: url)

        return try await Task.detached(priority: .userInitiated) {
            do {
                guard let file = XLSXFile(filepath: url.path) else {
                    throw ExcelError.corrupted("Unable to open workbook")
                }
                let names = try file.parseWorksheetPaths()
                var infos: [SheetInfo] = []

                for (index, path) in names.enumerated() {
                    let sheetName = sheetDisplayName(file: file, index: index, path: path)
                    let ws = try file.parseWorksheet(at: path)
                    let rows = ws.data?.rows ?? []
                    let rowCount = rows.count
                    let colCount = rows.map { $0.cells.count }.max() ?? 0
                    infos.append(SheetInfo(name: sheetName, rowCount: max(0, rowCount - 1), columnCount: colCount))
                }
                return infos
            } catch let excelErr as ExcelError {
                throw excelErr
            } catch {
                // CoreXLSX throws a generic error for password-protected files
                let msg = error.localizedDescription.lowercased()
                if msg.contains("password") || msg.contains("encrypted") {
                    throw ExcelError.passwordProtected
                }
                throw ExcelError.corrupted(error.localizedDescription)
            }
        }.value
    }

    /// Fully parses a single worksheet and returns a DataSet.
    /// - Parameters:
    ///   - url: Path to the .xlsx file.
    ///   - sheetName: Name of the sheet to parse. Defaults to the first sheet when nil.
    static func parse(url: URL, sheetName: String? = nil) async throws -> DataSet {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        try validateFileSize(url: url)

        return try await Task.detached(priority: .userInitiated) {
            do {
                guard let file = XLSXFile(filepath: url.path) else {
                    throw ExcelError.corrupted("Unable to open workbook")
                }

                // Resolve the worksheet path to use
                let allPaths = try file.parseWorksheetPaths()
                guard !allPaths.isEmpty else { throw ExcelError.emptySheet }

                let targetPath: String
                if let sheetName = sheetName {
                    // Match by display name
                    guard let matchIndex = allPaths.indices.first(where: {
                        sheetDisplayName(file: file, index: $0, path: allPaths[$0]) == sheetName
                    }) else {
                        throw ExcelError.sheetNotFound(sheetName)
                    }
                    targetPath = allPaths[matchIndex]
                } else {
                    targetPath = allPaths[0]
                }

                let resolvedSheetName = sheetName ?? sheetDisplayName(file: file, index: 0, path: targetPath)
                let filename = url.lastPathComponent

                // Parse the shared strings table (needed to resolve string cells)
                let sharedStrings = try? file.parseSharedStrings()

                let worksheet = try file.parseWorksheet(at: targetPath)
                let rows = worksheet.data?.rows ?? []

                guard !rows.isEmpty else { throw ExcelError.emptySheet }

                return processWorksheetRows(rows,
                                            sharedStrings: sharedStrings,
                                            filename: filename,
                                            sheetName: resolvedSheetName)
            } catch let excelErr as ExcelError {
                throw excelErr
            } catch {
                let msg = error.localizedDescription.lowercased()
                if msg.contains("password") || msg.contains("encrypted") {
                    throw ExcelError.passwordProtected
                }
                throw ExcelError.corrupted(error.localizedDescription)
            }
        }.value
    }

    // MARK: - Private Helpers

    /// Validates the file does not exceed 50 MB
    private static func validateFileSize(url: URL) throws {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attrs?[.size] as? Int, size > maxFileSizeBytes {
            throw ExcelError.tooLarge
        }
    }

    /// Resolves a human-readable sheet name from the workbook relationships
    private static func sheetDisplayName(file: XLSXFile, index: Int, path: String) -> String {
        // Try to get the name from workbook relationships; fall back to Sheet N
        if let workbook = try? file.parseWorkbooks().first,
           let rel = workbook.sheets.items.first(where: { _ in true }) {
            // Walk through sheets in order
            let items = workbook.sheets.items
            if index < items.count {
                return items[index].name
            }
        }
        return "Sheet \(index + 1)"
    }

    /// Converts parsed worksheet rows into the canonical DataSet format
    private static func processWorksheetRows(
        _ rows: [Row],
        sharedStrings: SharedStrings?,
        filename: String,
        sheetName: String
    ) -> DataSet {
        guard !rows.isEmpty else {
            return DataSet(name: filename, columns: [], rows: [])
        }

        // Convert every Row → [String] (raw cell values)
        var matrix: [[String]] = rows.map { row in
            row.cells.map { cell in
                extractCellValue(cell, sharedStrings: sharedStrings)
            }
        }

        // Pad shorter rows to match the maximum column count
        let maxCols = matrix.map { $0.count }.max() ?? 0
        matrix = matrix.map { row in
            row.count < maxCols ? row + Array(repeating: "", count: maxCols - row.count) : row
        }

        guard maxCols > 0 else {
            return DataSet(name: filename, columns: [], rows: [])
        }

        // Re-use CSVParser's header detection and type inference logic
        let firstRow = matrix[0]
        let hasHeader = detectHasHeader(firstRow: firstRow, subsequentRows: Array(matrix.dropFirst()))

        let headerRow: [String]
        let dataRows: [[String]]

        if hasHeader {
            headerRow = firstRow.map { $0.isEmpty ? "Column" : $0 }
            dataRows = Array(matrix.dropFirst())
        } else {
            headerRow = (0..<maxCols).map { "Column \($0 + 1)" }
            dataRows = matrix
        }

        // Build columns with detected types
        var columns: [Column] = []
        var columnTypes: [ColumnType] = []

        for colIndex in 0..<maxCols {
            let colValues = dataRows.map { $0[colIndex] }
            let detectedType = detectColumnType(values: colValues)
            columnTypes.append(detectedType)
            let colName = headerRow[colIndex].isEmpty ? "Column \(colIndex + 1)" : headerRow[colIndex]
            columns.append(Column(name: colName, type: detectedType, index: colIndex))
        }

        // Build typed rows
        var parsedRows: [Row] = []
        for line in dataRows {
            var rowValues: [String: Any] = [:]
            for colIndex in 0..<maxCols {
                let rawValue = line[colIndex]
                let colName = columns[colIndex].name
                guard !rawValue.isEmpty else { continue }

                switch columnTypes[colIndex] {
                case .number:
                    rowValues[colName] = Double(rawValue) ?? rawValue
                case .date:
                    rowValues[colName] = parseDate(rawValue) ?? rawValue
                case .text:
                    rowValues[colName] = rawValue
                }
            }
            parsedRows.append(Row(values: rowValues))
        }

        return DataSet(name: "\(filename) — \(sheetName)", columns: columns, rows: parsedRows)
    }

    // MARK: - Cell Value Extraction

    /// Extracts a plain string representation from a CoreXLSX Cell
    private static func extractCellValue(_ cell: Cell, sharedStrings: SharedStrings?) -> String {
        // Formula cells: use the cached value if available
        if let value = cell.value {
            // Shared-string index
            if cell.type == .sharedString, let idx = Int(value), let ss = sharedStrings {
                return ss.items[safe: idx]?.text ?? value
            }
            // Boolean
            if cell.type == .boolean {
                return value == "1" ? "TRUE" : "FALSE"
            }
            // Number / date serial / general
            return value
        }
        return ""
    }

    // MARK: - Type Detection (mirrors CSVParser)

    private static func detectHasHeader(firstRow: [String], subsequentRows: [[String]]) -> Bool {
        guard !subsequentRows.isEmpty else { return false }
        var headerScore = 0
        var dataScore = 0
        for colIndex in 0..<firstRow.count {
            let cellType = detectValueType(firstRow[colIndex])
            let subTypes = subsequentRows.compactMap { row -> ColumnType? in
                guard colIndex < row.count else { return nil }
                let v = row[colIndex]
                return v.isEmpty ? nil : detectValueType(v)
            }
            let isSubNumericOrDate = subTypes.contains { $0 == .number || $0 == .date }
            if isSubNumericOrDate && cellType == .text { headerScore += 1 }
            else if !subTypes.isEmpty && cellType == subTypes[0] { dataScore += 1 }
        }
        if headerScore > 0 { return true }
        if dataScore > 0 { return false }
        return firstRow.allSatisfy { !$0.isEmpty && detectValueType($0) == .text }
    }

    private static func detectValueType(_ value: String) -> ColumnType {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if Double(t) != nil { return .number }
        if parseDate(t) != nil { return .date }
        return .text
    }

    private static func detectColumnType(values: [String]) -> ColumnType {
        let nonEmpty = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !nonEmpty.isEmpty else { return .text }
        var numbers = 0, dates = 0
        for v in nonEmpty {
            switch detectValueType(v) {
            case .number: numbers += 1
            case .date:   dates += 1
            case .text:   break
            }
        }
        let total = Double(nonEmpty.count)
        if Double(numbers) / total > 0.9 { return .number }
        if Double(dates)   / total > 0.9 { return .date   }
        return .text
    }

    private static func parseDate(_ value: String) -> Date? {
        let formats = [
            "yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for fmt in formats {
            formatter.dateFormat = fmt
            if let d = formatter.date(from: value) { return d }
        }
        return nil
    }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
