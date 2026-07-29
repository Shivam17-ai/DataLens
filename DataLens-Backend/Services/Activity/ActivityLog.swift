import SwiftUI

// MARK: - ActivityLog

struct ActivityItem: Identifiable, Equatable {
    let id = UUID()
    let action: String
    let description: String
    let timestamp = Date()
    let iconName: String
    let color: Color
}

@MainActor
final class ActivityLog: ObservableObject {
    static let shared = ActivityLog()
    
    @Published var items: [ActivityItem] = []
    
    private init() {}
    
    func log(action: String, description: String, iconName: String, color: Color) {
        let newItem = ActivityItem(action: action, description: description, iconName: iconName, color: color)
        items.insert(newItem, at: 0)
        if items.count > 10 {
            items.removeLast()
        }
    }
}
