import Foundation

/// Represents a complete parsed dataset imported into DataLens
struct DataSet: Identifiable {
    let id: UUID
    let name: String
    let columns: [Column]
    let rows: [Row]
    let importedAt: Date
    
    /// Computes the total number of rows in the dataset
    var rowCount: Int {
        rows.count
    }
    
    /// Computes the total number of columns in the dataset
    var columnCount: Int {
        columns.count
    }
    
    init(id: UUID = UUID(), name: String, columns: [Column], rows: [Row], importedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.columns = columns
        self.rows = rows
        self.importedAt = importedAt
    }
}
