import Foundation

/// Data types represented in DataLens columns
enum ColumnType: String, Codable, CaseIterable {
    case number
    case text
    case date
    
    /// Returns the SF Symbol icon name representing the data type
    var iconName: String {
        switch self {
        case .number: return "number"
        case .text: return "text.alignleft"
        case .date: return "calendar"
        }
    }
}

/// Represents metadata for a column in the imported dataset
struct Column: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let type: ColumnType
    let index: Int
    
    init(id: UUID = UUID(), name: String, type: ColumnType, index: Int) {
        self.id = id
        self.name = name
        self.type = type
        self.index = index
    }
}
