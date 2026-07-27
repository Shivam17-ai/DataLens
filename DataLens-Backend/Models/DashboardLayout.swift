import Foundation

// MARK: - Schema Version

/// Bump this constant whenever DashboardLayout's shape changes to maintain JSON compatibility
let kDashboardSchemaVersion: Int = 1

// MARK: - Card Type

/// Defines the types of cards allowed on the drag-and-drop dashboard builder
enum CardType: String, Codable, CaseIterable {
    case chart  = "Chart"
    case text   = "Text Block"
    case kpi    = "KPI Card"
    case filter = "Filter Dropdown"
}

// MARK: - Dashboard Template

/// Pre-built layout templates shown in the New Dashboard picker
enum DashboardTemplate: String, CaseIterable, Identifiable {
    case blank         = "Blank Dashboard"
    case salesOverview = "Sales Overview"
    case financial     = "Financial Summary"
    case marketing     = "Marketing Analytics"
    case operations    = "Operations Dashboard"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .blank:         return "Start from scratch with an empty canvas"
        case .salesOverview: return "Revenue KPIs, bar chart, pipeline funnel"
        case .financial:     return "P&L waterfall, gauge chart, trend lines"
        case .marketing:     return "Funnel conversion, heatmap, KPI row"
        case .operations:    return "Uptime gauge, scatter chart, filter panel"
        }
    }

    var iconName: String {
        switch self {
        case .blank:         return "rectangle.dashed"
        case .salesOverview: return "chart.bar.fill"
        case .financial:     return "dollarsign.circle.fill"
        case .marketing:     return "chart.pie.fill"
        case .operations:    return "gauge.high"
        }
    }

    var accentHex: String {
        switch self {
        case .blank:         return "#2A2A4A"
        case .salesOverview: return "#533483"
        case .financial:     return "#00B4D8"
        case .marketing:     return "#E879F9"
        case .operations:    return "#F59E0B"
        }
    }

    /// Returns a starter set of cards for this template
    func makeCards() -> [DashboardCard] {
        switch self {
        case .blank: return []

        case .salesOverview:
            return [
                DashboardCard(type: .kpi,   position: CGPoint(x: 40,  y: 40),  size: CGSize(width: 220, height: 140), title: "Total Revenue"),
                DashboardCard(type: .kpi,   position: CGPoint(x: 280, y: 40),  size: CGSize(width: 220, height: 140), title: "Orders This Month"),
                DashboardCard(type: .kpi,   position: CGPoint(x: 520, y: 40),  size: CGSize(width: 220, height: 140), title: "Avg Order Value"),
                DashboardCard(type: .chart, position: CGPoint(x: 40,  y: 210), size: CGSize(width: 460, height: 280), title: "Revenue by Region"),
                DashboardCard(type: .chart, position: CGPoint(x: 520, y: 210), size: CGSize(width: 340, height: 280), title: "Sales Funnel"),
            ]

        case .financial:
            return [
                DashboardCard(type: .kpi,   position: CGPoint(x: 40,  y: 40),  size: CGSize(width: 220, height: 140), title: "Net Profit"),
                DashboardCard(type: .kpi,   position: CGPoint(x: 280, y: 40),  size: CGSize(width: 220, height: 140), title: "Operating Margin"),
                DashboardCard(type: .chart, position: CGPoint(x: 40,  y: 210), size: CGSize(width: 400, height: 260), title: "P&L Waterfall"),
                DashboardCard(type: .chart, position: CGPoint(x: 460, y: 40),  size: CGSize(width: 240, height: 200), title: "Budget Gauge"),
                DashboardCard(type: .chart, position: CGPoint(x: 460, y: 260), size: CGSize(width: 400, height: 220), title: "Monthly Trend"),
            ]

        case .marketing:
            return [
                DashboardCard(type: .kpi,   position: CGPoint(x: 40,  y: 40),  size: CGSize(width: 200, height: 140), title: "Total Sessions"),
                DashboardCard(type: .kpi,   position: CGPoint(x: 260, y: 40),  size: CGSize(width: 200, height: 140), title: "Conversion Rate"),
                DashboardCard(type: .kpi,   position: CGPoint(x: 480, y: 40),  size: CGSize(width: 200, height: 140), title: "CAC"),
                DashboardCard(type: .chart, position: CGPoint(x: 40,  y: 210), size: CGSize(width: 320, height: 260), title: "Funnel Conversion"),
                DashboardCard(type: .chart, position: CGPoint(x: 380, y: 210), size: CGSize(width: 380, height: 260), title: "Channel Heatmap"),
            ]

        case .operations:
            return [
                DashboardCard(type: .kpi,    position: CGPoint(x: 40,  y: 40),  size: CGSize(width: 220, height: 140), title: "System Uptime"),
                DashboardCard(type: .chart,  position: CGPoint(x: 280, y: 40),  size: CGSize(width: 220, height: 220), title: "Load Gauge"),
                DashboardCard(type: .chart,  position: CGPoint(x: 40,  y: 210), size: CGSize(width: 420, height: 260), title: "Response Time"),
                DashboardCard(type: .filter, position: CGPoint(x: 520, y: 280), size: CGSize(width: 260, height: 100), title: "Region Filter"),
            ]
        }
    }
}

// MARK: - KPI Config

/// Settings and dimensions for KPI metrics
struct KPIConfig: Codable, Equatable {
    var primaryMetricColumn: String = ""
    var labelText: String           = "KPI"
    var comparisonColumn: String?   = nil
    var showTrendArrow: Bool        = true
    var formatAsPercentage: Bool    = false
}

// MARK: - CGPoint / CGSize Codable

/// Custom Codable conformances for CoreGraphics types (not Codable by default in SwiftUI)
extension CGPoint: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(x: try c.decode(CGFloat.self, forKey: .x),
                  y: try c.decode(CGFloat.self, forKey: .y))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(x, forKey: .x)
        try c.encode(y, forKey: .y)
    }
    private enum CodingKeys: String, CodingKey { case x, y }
}

extension CGSize: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(width:  try c.decode(CGFloat.self, forKey: .width),
                  height: try c.decode(CGFloat.self, forKey: .height))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(width,  forKey: .width)
        try c.encode(height, forKey: .height)
    }
    private enum CodingKeys: String, CodingKey { case width, height }
}

// MARK: - Dashboard Card

/// Representation of a single dashboard card in the layout schema
struct DashboardCard: Identifiable, Codable, Equatable {
    var id:           UUID
    var type:         CardType
    var position:     CGPoint
    var size:         CGSize
    var zIndex:       Int
    var chartConfig:  ChartConfig?
    var textContent:  String?
    var kpiConfig:    KPIConfig?
    var isMinimized:  Bool
    var title:        String

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
        self.id          = id
        self.type        = type
        self.position    = position
        self.size        = size
        self.zIndex      = zIndex
        self.chartConfig = chartConfig
        self.textContent = textContent
        self.kpiConfig   = kpiConfig
        self.isMinimized = isMinimized
        self.title       = title
    }
}

// MARK: - Dashboard Layout

/// Complete dashboard configuration — source of truth for persistence and rendering
struct DashboardLayout: Identifiable, Codable, Equatable {
    var id:              UUID
    var name:            String
    var description:     String
    var tags:            [String]
    var createdAt:       Date
    var updatedAt:       Date
    var cards:           [DashboardCard]
    var canvasSize:      CGSize
    var backgroundColor: String
    var gridEnabled:     Bool
    var snapToGrid:      Bool
    var canvasZoom:      Double
    var canvasOffsetX:   Double
    var canvasOffsetY:   Double
    var thumbnailData:   Data?

    init(id: UUID = UUID(),
         name: String = "Untitled Dashboard",
         description: String = "",
         tags: [String] = [],
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         cards: [DashboardCard] = [],
         canvasSize: CGSize = CGSize(width: 2000, height: 2000),
         backgroundColor: String = "#1A1A2E",
         gridEnabled: Bool = true,
         snapToGrid: Bool = true,
         canvasZoom: Double = 1.0,
         canvasOffsetX: Double = 0,
         canvasOffsetY: Double = 0,
         thumbnailData: Data? = nil) {
        self.id              = id
        self.name            = name
        self.description     = description
        self.tags            = tags
        self.createdAt       = createdAt
        self.updatedAt       = updatedAt
        self.cards           = cards
        self.canvasSize      = canvasSize
        self.backgroundColor = backgroundColor
        self.gridEnabled     = gridEnabled
        self.snapToGrid      = snapToGrid
        self.canvasZoom      = canvasZoom
        self.canvasOffsetX   = canvasOffsetX
        self.canvasOffsetY   = canvasOffsetY
        self.thumbnailData   = thumbnailData
    }
}
