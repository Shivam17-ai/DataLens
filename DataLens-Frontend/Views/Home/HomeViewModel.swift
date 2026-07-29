import SwiftUI
import Combine

/// HomeViewModel manages the statistics and operations of the HomeView
@MainActor
class HomeViewModel: ObservableObject {
    @Published var totalDatasets: Int = 0
    @Published var totalCharts: Int = 0
    @Published var dashboardsCreated: Int = 0
    @Published var aiInsightsGenerated: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        refreshStats()
    }
    
    func refreshStats() {
        // Datasets count from recentFiles
        if let data = UserDefaults.standard.data(forKey: "recentFiles"),
           let decoded = try? JSONDecoder().decode([RecentFile].self, from: data) {
            totalDatasets = decoded.count
        } else {
            totalDatasets = 0
        }
        
        // Charts created count
        totalCharts = UserDefaults.standard.integer(forKey: "datalens_charts_count")
        
        // Dashboards saved count
        dashboardsCreated = UserDefaults.standard.integer(forKey: "datalens_dashboards_count")
        
        // AI queries made count
        aiInsightsGenerated = UserDefaults.standard.integer(forKey: "datalens_ai_queries_count")
    }
    
    /// Handles the "Get Started" action by executing the completion callback
    func getStarted(completion: @escaping () -> Void) {
        completion()
    }
}
