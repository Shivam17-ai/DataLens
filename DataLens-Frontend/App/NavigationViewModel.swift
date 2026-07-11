import SwiftUI
import Combine

/// Represents the selectable screens in the sidebar navigation
enum SidebarItem: String, CaseIterable, Identifiable {
    case home
    case importData
    case dashboard
    case charts
    case aiInsights
    case export
    
    var id: String { self.rawValue }
    
    var title: String {
        switch self {
        case .home: return AppConstants.Sidebar.home
        case .importData: return AppConstants.Sidebar.importData
        case .dashboard: return AppConstants.Sidebar.dashboard
        case .charts: return AppConstants.Sidebar.charts
        case .aiInsights: return AppConstants.Sidebar.aiInsights
        case .export: return AppConstants.Sidebar.export
        }
    }
    
    var iconName: String {
        switch self {
        case .home: return AppConstants.Icons.home
        case .importData: return AppConstants.Icons.importData
        case .dashboard: return AppConstants.Icons.dashboard
        case .charts: return AppConstants.Icons.charts
        case .aiInsights: return AppConstants.Icons.aiInsights
        case .export: return AppConstants.Icons.export
        }
    }
}

/// NavigationViewModel controls the selected navigation route
class NavigationViewModel: ObservableObject {
    @Published var selectedItem: SidebarItem = .home
    
    /// Navigates to a specific sidebar screen with smooth animation
    func navigate(to item: SidebarItem) {
        selectedItem = item
    }
}
