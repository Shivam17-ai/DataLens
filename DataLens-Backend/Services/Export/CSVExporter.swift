import Foundation

// MARK: - CSV Export Configuration Types

enum CSVDelimiter: String, CaseIterable, Identifiable, Codable {
    case comma     = ","
    case semicolon = ";"
    case tab       = "\t"
    case pipe      = "|"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .comma:     return "Comma (,)"
        case .semicolon: return "Semicolon (;)"
        case .tab:       return "Tab (\\t)"
        case .pipe:      return "Pipe (|)"
        }
    }
}

enum NumberFormat: String, CaseIterable, Identifiable, Codable {
    case standard  = "Standard (1,234.56)"
    case european  = "European (1.234,56)"
    case scientific = "Scientific (1.23e+03)"

    var id: String { rawValue }
}

enum ExportScope: String, CaseIterable, Identifiable, Codable {
    case allData         = "All Data Rows"
    case filteredData    = "Filtered Rows Only"
    case selectedColumns = "Selected Columns"

    var id: String { rawValue }
}

struct CSVConfig: Codable, Equatable {
    var delimiter: CSVDelimiter    = .comma
    var includeHeaders: Bool       = true
    var includeRowNumbers: Bool    = false
    var dateFormat: String         = "yyyy-MM-dd HH:mm:ss"
    var numberFormat: NumberFormat = .standard
    var encoding: String.Encoding  = .utf8
    var exportScope: ExportScope   = .allData
    var selectedColumns: [String]  = []

    // Custom Codable for String.Encoding
    enum CodingKeys: String, CodingKey {
        case delimiter, includeHeaders, includeRowNumbers, dateFormat, numberFormat, encodingRaw, exportScope, selectedColumns
    }

    init(
        delimiter: CSVDelimiter = .comma,
        includeHeaders: Bool = true,
        includeRowNumbers: Bool = false,
        dateFormat: String = "yyyy-MM-dd HH:mm:ss",
        numberFormat: NumberFormat = .standard,
        encoding: String.Encoding = .utf8,
        exportScope: ExportScope = .allData,
        selectedColumns: [String] = []
    ) {
        self.delimiter = delimiter
        self.includeHeaders = includeHeaders
        self.includeRowNumbers = includeRowNumbers
        self.dateFormat = dateFormat
        self.numberFormat = numberFormat
        self.encoding = encoding
        self.exportScope = exportScope
        self.selectedColumns = selectedColumns
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        delimiter = try container.decode(CSVDelimiter.self, forKey: .delimiter)
        includeHeaders = try container.decode(Bool.self, forKey: .includeHeaders)
        includeRowNumbers = try container.decode(Bool.self, forKey: .includeRowNumbers)
        dateFormat = try container.decode(String.self, forKey: .dateFormat)
        numberFormat = try container.decode(NumberFormat.self, forKey: .numberFormat)
        let encRaw = try container.decode(UInt.self, forKey: .encodingRaw)
        encoding = String.Encoding(rawValue: encRaw)
        exportScope = try container.decode(ExportScope.self, forKey: .exportScope)
        selectedColumns = try container.decode([String].self, forKey: .selectedColumns)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(delimiter, forKey: .delimiter)
        try container.encode(includeHeaders, forKey: .includeHeaders)
        try container.encode(includeRowNumbers, forKey: .includeRowNumbers)
        try container.encode(dateFormat, forKey: .dateFormat)
        try container.encode(numberFormat, forKey: .numberFormat)
        try container.encode(encoding.rawValue, forKey: .encodingRaw)
        try container.encode(exportScope, forKey: .exportScope)
        try container.encode(selectedColumns, forKey: .selectedColumns)
    }
}

// MARK: - CSVExporter Service

final class CSVExporter {

    static let shared = CSVExporter()

    private init() {}

    func exportDataSet(
        dataset: DataSet,
        config: CSVConfig,
        onProgress: ((Double, String) -> Void)? = nil
    ) async throws -> URL {
        let rowsToExport: [Row]
        switch config.exportScope {
        case .allData, .filteredData, .selectedColumns:
            rowsToExport = dataset.rows
        }
        return try await generateCSV(
            columns: dataset.columns,
            rows: rowsToExport,
            filename: dataset.name,
            config: config,
            onProgress: onProgress
        )
    }

    func exportFilteredData(
        dataset: DataSet,
        filteredRows: [Row],
        config: CSVConfig,
        onProgress: ((Double, String) -> Void)? = nil
    ) async throws -> URL {
        return try await generateCSV(
            columns: dataset.columns,
            rows: filteredRows,
            filename: "\(dataset.name)_filtered",
            config: config,
            onProgress: onProgress
        )
    }

    func exportChartData(
        chartData: ChartData,
        chartTitle: String,
        config: CSVConfig,
        onProgress: ((Double, String) -> Void)? = nil
    ) async throws -> URL {
        onProgress?(0.1, "Preparing chart data...")

        var csv = ""
        let delim = config.delimiter.rawValue

        if config.includeHeaders {
            csv += "Category\(delim)Value\(delim)Series\n"
        }

        let total = Double(max(1, chartData.points.count))
        for (idx, pt) in chartData.points.enumerated() {
            let catEscaped = escapeCSV(pt.x, delimiter: delim)
            let valFormatted = formatNumber(pt.y, format: config.numberFormat)
            let seriesEscaped = escapeCSV(pt.series ?? "", delimiter: delim)

            csv += "\(catEscaped)\(delim)\(valFormatted)\(delim)\(seriesEscaped)\n"

            if idx % 100 == 0 {
                onProgress?(0.1 + 0.8 * (Double(idx) / total), "Formatting rows (\(idx)/\(chartData.points.count))...")
            }
        }

        onProgress?(0.9, "Writing CSV to file...")
        let filename = sanitizeFilename(chartTitle.isEmpty ? "chart_data" : chartTitle)
        return try saveToTemp(content: csv, filename: filename, extensionStr: "csv", encoding: config.encoding)
    }

    // MARK: - Private Generator

    private func generateCSV(
        columns: [Column],
        rows: [Row],
        filename: String,
        config: CSVConfig,
        onProgress: ((Double, String) -> Void)? = nil
    ) async throws -> URL {

        onProgress?(0.05, "Initializing CSV export...")

        // Determine active columns
        let activeCols: [Column]
        if config.exportScope == .selectedColumns && !config.selectedColumns.isEmpty {
            activeCols = columns.filter { config.selectedColumns.contains($0.name) }
        } else {
            activeCols = columns.filter { !$0.isHidden }
        }

        let delim = config.delimiter.rawValue
        var csvLines: [String] = []

        // Date Formatter
        let dateForm = DateFormatter()
        dateForm.dateFormat = config.dateFormat

        // 1. Header Line
        if config.includeHeaders {
            var headerParts: [String] = []
            if config.includeRowNumbers { headerParts.append("#") }
            for col in activeCols {
                headerParts.append(escapeCSV(col.name, delimiter: delim))
            }
            csvLines.append(headerParts.joined(separator: delim))
        }

        // 2. Data Rows
        let total = Double(max(1, rows.count))
        for (rowIdx, r) in rows.enumerated() {
            var rowParts: [String] = []
            if config.includeRowNumbers {
                rowParts.append("\(rowIdx + 1)")
            }

            for col in activeCols {
                if let rawVal = r.values[col.name] {
                    let formattedStr: String
                    if let d = rawVal as? Date {
                        formattedStr = dateForm.string(from: d)
                    } else if let num = rawVal as? Double {
                        formattedStr = formatNumber(num, format: config.numberFormat)
                    } else {
                        formattedStr = String(describing: rawVal)
                    }
                    rowParts.append(escapeCSV(formattedStr, delimiter: delim))
                } else {
                    rowParts.append("") // Empty value
                }
            }

            csvLines.append(rowParts.joined(separator: delim))

            if rowIdx % 500 == 0 {
                let p = 0.05 + 0.85 * (Double(rowIdx) / total)
                onProgress?(p, "Processing row \(rowIdx + 1) of \(rows.count)...")
            }
        }

        onProgress?(0.95, "Saving CSV file...")
        let fullContent = csvLines.joined(separator: "\n")
        let cleanName = sanitizeFilename(filename)
        return try saveToTemp(content: fullContent, filename: cleanName, extensionStr: "csv", encoding: config.encoding)
    }

    // MARK: - Helpers

    private func escapeCSV(_ text: String, delimiter: String) -> String {
        if text.contains(delimiter) || text.contains("\"") || text.contains("\n") || text.contains("\r") {
            let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return text
    }

    private func formatNumber(_ val: Double, format: NumberFormat) -> String {
        switch format {
        case .standard:
            return String(format: "%.2f", val)
        case .european:
            let str = String(format: "%.2f", val)
            return str.replacingOccurrences(of: ".", with: ",")
        case .scientific:
            return String(format: "%.2e", val)
        }
    }

    private func sanitizeFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }

    private func saveToTemp(content: String, filename: String, extensionStr: String, encoding: String.Encoding) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(filename).\(extensionStr)")

        guard let data = content.data(using: encoding) else {
            throw NSError(domain: "CSVExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode CSV text."])
        }

        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
