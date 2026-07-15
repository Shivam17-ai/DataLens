import Foundation

/// Data types representable in a DataLens column
enum ColumnType: String, Codable, CaseIterable {
    case number
    case text
    case date

    /// SF Symbol icon for this data type
    var iconName: String {
        switch self {
        case .number: return "number"
        case .text:   return "textformat"
        case .date:   return "calendar"
        }
    }

    /// Human-readable label
    var label: String {
        switch self {
        case .number: return "Number"
        case .text:   return "Text"
        case .date:   return "Date"
        }
    }
}

/// Represents metadata for a single column in the imported dataset
struct Column: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let type: ColumnType
    let index: Int
    /// When true the column is excluded from the visible grid
    let isHidden: Bool

    init(id: UUID = UUID(),
         name: String,
         type: ColumnType,
         index: Int,
         isHidden: Bool = false) {
        self.id       = id
        self.name     = name
        self.type     = type
        self.index    = index
        self.isHidden = isHidden
    }

    /// Returns a copy of this column with a different type
    func withType(_ newType: ColumnType) -> Column {
        Column(id: id, name: name, type: newType, index: index, isHidden: isHidden)
    }

    /// Returns a copy of this column with a different name
    func withName(_ newName: String) -> Column {
        Column(id: UUID(), name: newName, type: type, index: index, isHidden: isHidden)
    }

    /// Returns a copy with isHidden toggled to true
    func hidden() -> Column {
        Column(id: id, name: name, type: type, index: index, isHidden: true)
    }
}
