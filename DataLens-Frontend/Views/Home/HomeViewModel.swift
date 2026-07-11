import SwiftUI
import Combine

/// HomeViewModel manages the statistics and operations of the HomeView
class HomeViewModel: ObservableObject {
    @Published var totalDatasets: Int = 0
    @Published var totalCharts: Int = 0
    @Published var dashboardsCreated: Int = 0
    @Published var aiInsightsGenerated: Int = 0
    
    /// Handles the "Get Started" action by executing the completion callback
    func getStarted(completion: @escaping () -> Void) {
        // Any tracking or setup logic for Day 1 goes here
        completion()
    }
}
