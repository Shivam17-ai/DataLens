import Foundation

/// AppConstants holds all string literals, UI labels, icons, and sizing keys
struct AppConstants {
    
    struct General {
        static let appName = "DataLens"
        static let tagline = "Your Native Mac Analytics Tool"
        static let getStartedButton = "Get Started"
    }
    
    struct Sidebar {
        static let home = "Home"
        static let importData = "Import Data"
        static let dashboard = "Dashboard"
        static let charts = "Charts"
        static let aiInsights = "AI Insights"
        static let export = "Export"
    }
    
    struct Icons {
        static let home = "house.fill"
        static let importData = "square.and.arrow.down.fill"
        static let dashboard = "rectangle.3.group.fill"
        static let charts = "chart.bar.fill"
        static let aiInsights = "brain.head.profile"
        static let export = "square.and.arrow.up.fill"
    }
    
    struct Stats {
        static let totalDatasets = "Total Datasets"
        static let totalCharts = "Total Charts"
        static let dashboardsCreated = "Dashboards Created"
        static let aiInsightsGenerated = "AI Insights Generated"
        
        static let defaultValue = "0"
        static let sectionHeader = "Platform Overview"
    }
    
    struct Placeholders {
        static let screenTitleSuffix = " Screen"
        static let descriptionPrefix = "This is the content screen for "
        static let comingSoon = "Coming soon in Day 2 of development."
    }
}
