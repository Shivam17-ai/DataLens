import Foundation

/// Represents a complete parsed (or cleaned) dataset inside DataLens
struct DataSet: Identifiable {
    let id: UUID
    let name: String
    let columns: [Column]
    let rows: [Row]
    let importedAt: Date
    /// Label of the last cleaning operation applied — shown in undo/redo tooltip
    let operationLabel: String?

    // MARK: - Computed Properties

    /// Total number of rows
    var rowCount: Int { rows.count }

    /// Total number of columns (including hidden)
    var columnCount: Int { columns.count }

    /// Only the columns that are not hidden — used by the grid view
    var visibleColumns: [Column] { columns.filter { !$0.isHidden } }

    // MARK: - Init

    init(id: UUID = UUID(),
         name: String,
         columns: [Column],
         rows: [Row],
         importedAt: Date = Date(),
         operationLabel: String? = nil) {
        self.id             = id
        self.name           = name
        self.columns        = columns
        self.rows           = rows
        self.importedAt     = importedAt
        self.operationLabel = operationLabel
    }

    /// Returns a new DataSet derived from this one with a different set of rows/columns and an operation label
    func applying(columns: [Column]? = nil, rows: [Row]? = nil, label: String) -> DataSet {
        DataSet(
            name: name,
            columns: columns ?? self.columns,
            rows: rows ?? self.rows,
            importedAt: importedAt,
            operationLabel: label
        )
    }
}
