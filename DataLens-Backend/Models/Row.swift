import Foundation

/// Represents a single row of data inside the dataset with dynamically typed values
struct Row: Identifiable {
    let id: UUID
    let values: [String: Any]
    
    init(id: UUID = UUID(), values: [String: Any]) {
        self.id = id
        self.values = values
    }
}
