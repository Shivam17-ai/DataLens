import Foundation

/// Defines the types of cards allowed on the drag-and-drop dashboard builder
enum CardType: String, Codable, CaseIterable {
    case chart = "Chart"
    case text = "Text Block"
    case kpi = "KPI Card"
    case filter = "Filter Dropdown"
}

/// Settings and dimensions for KPI metrics
struct KPIConfig: Codable, Equatable {
    var primaryMetricColumn: String = ""
    var labelText: String = "KPI"
    var comparisonColumn: String? = nil
    var showTrendArrow: Bool = true
    var formatAsPercentage: Bool = false
}

/// Representation of a dashboard card in layout schema
struct DashboardCard: Identifiable, Codable, Equatable {
    var id: UUID
    var type: CardType
    var position: CGPoint
    var size: CGSize
    var zIndex: Int
    var chartConfig: ChartConfig?
    var textContent: String?
    var kpiConfig: KPIConfig?
    var isMinimized: Bool
    var title: String

    init(id: UUID = UUID(),
         type: CardType,
         position: CGPoint,
         size: CGSize,
         zIndex: Int = 0,
         chartConfig: ChartConfig? = nil,
         textContent: String? = nil,
         kpiConfig: KPIConfig? = nil,
         isMinimized: Bool = false,
         title: String = "Untitled Card") {
        self.id = id
        self.type = type
        self.position = position
        self.size = size
        self.zIndex = zIndex
        self.chartConfig = chartConfig
        self.textContent = textContent
        self.kpiConfig = kpiConfig
        self.isMinimized = isMinimized
        self.title = title
    }
}

/// Representation of the overall dashboard configuration and layout
struct DashboardLayout: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var cards: [DashboardCard]
    var canvasSize: CGSize
    var backgroundColor: String
    var gridEnabled: Bool
    var snapToGrid: Bool

    init(id: UUID = UUID(),
         name: String = "Untitled Dashboard",
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         cards: [DashboardCard] = [],
         canvasSize: CGSize = CGSize(width: 2000, height: 2000),
         backgroundColor: String = "#1A1A2E",
         gridEnabled: Bool = true,
         snapToGrid: Bool = true) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.cards = cards
        self.canvasSize = canvasSize
        self.backgroundColor = backgroundColor
        self.gridEnabled = gridEnabled
        self.snapToGrid = snapToGrid
    }
}
