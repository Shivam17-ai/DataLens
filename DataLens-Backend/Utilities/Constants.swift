import Foundation

/// Centralized Constants file containing app metadata, animation timings, layout guidelines, and text labels.
struct Constants {
    
    struct App {
        static let name = "DataLens"
        static let version = "1.0.0"
        static let buildNumber = "1"
        static let tagline = "Your Native Mac Analytics Tool"
        static let getStartedButton = "Get Started"
    }
    
    struct Animation {
        static let instant: Double = 0.15
        static let standard: Double = 0.25
        static let slow: Double = 0.35
    }
    
    struct Layout {
        static let cornerRadius: CGFloat = 12.0
        static let padding: CGFloat = 16.0
        static let outerPadding: CGFloat = 24.0
    }
    
    struct History {
        static let maxSnapshots = 10
    }
    
    struct Sidebar {
        static let home = "Home"
        static let importData = "Import Data"
        static let dashboard = "Dashboard"
        static let charts = "Charts"
        static let aiInsights = "AI Insights"
        static let export = "Export"
        static let settings = "Settings"
        static let help = "Help"
    }
    
    struct Onboarding {
        static let slide1Title = "Welcome to DataLens"
        static let slide1Subtitle = "Your native Mac analytics tool"
        
        static let slide2Title = "Import Your Data"
        static let slide2Subtitle = "Drag and drop CSV or Excel files to get started instantly"
        
        static let slide3Title = "Visualise Everything"
        static let slide3Subtitle = "15 chart types, interactive dashboards, and AI powered insights"
        
        static let slide4Title = "You're Ready!"
        static let slide4Subtitle = "Let's start analysing your data"
        
        static let skipButton = "Skip"
        static let doneButton = "Get Started"
    }

    struct EmptyStates {
        static let noDataTitle = "No Data Imported Yet"
        static let noDataSubtitle = "Import a CSV or Excel file to begin analyzing and building charts."
        
        static let noSearchTitle = "No Results Found"
        static let noSearchSubtitle = "Try adjusting your query or filters to find what you are looking for."
        
        static let noChartsTitle = "No Charts Created"
        static let noChartsSubtitle = "Create visual insights of your clean data in the Charts workspace."
        
        static let noDashboardsTitle = "No Dashboards Yet"
        static let noDashboardsSubtitle = "Assemble interactive grids of charts and KPIs into responsive dashboards."
    }
}
