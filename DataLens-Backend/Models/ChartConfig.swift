import SwiftUI

// MARK: - Chart Type Enum

enum ChartType: String, CaseIterable, Identifiable, Codable {
    case bar = "Bar"
    case horizontalBar = "Horizontal Bar"
    case line = "Line"
    case area = "Area"
    case pie = "Pie"
    case donut = "Donut"
    
    case scatter = "Scatter"
    case bubble = "Bubble"
    case histogram = "Histogram"
    case boxPlot = "Box Plot"
    
    case heatmap = "Heatmap"
    case treemap = "Treemap"
    case waterfall = "Waterfall"
    case funnel = "Funnel"
    case gauge = "Gauge"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .bar: return "chart.bar.fill"
        case .horizontalBar: return "align.horizontal.left.fill"
        case .line: return "chart.line.uptrend.xyaxis"
        case .area: return "photo.fill"
        case .pie: return "chart.pie.fill"
        case .donut: return "circle.circle.fill"
        case .scatter: return "point.3.connected.trianglepath.dotted"
        case .bubble: return "bubbles.and.sparkles.fill"
        case .histogram: return "chart.bar.xaxis"
        case .boxPlot: return "slider.horizontal.3"
        case .heatmap: return "square.grid.3x3.fill"
        case .treemap: return "rectangle.3.group.fill"
        case .waterfall: return "arrow.up.and.down.and.sparkles"
        case .funnel: return "filter"
        case .gauge: return "gauge.medium"
        }
    }
}

// MARK: - Color Theme Enum

enum ColorTheme: String, CaseIterable, Identifiable, Codable {
    case ocean = "Ocean"
    case sunset = "Sunset"
    case forest = "Forest"
    case metallic = "Metallic"
    case warm = "Warm"
    
    var id: String { self.rawValue }
    
    var colors: [Color] {
        switch self {
        case .ocean:
            return [
                Color(hex: "#00B4D8"),
                Color(hex: "#0077B6"),
                Color(hex: "#023E8A"),
                Color(hex: "#48CAE4"),
                Color(hex: "#90E0EF")
            ]
        case .sunset:
            return [
                Color(hex: "#F72585"),
                Color(hex: "#B5179E"),
                Color(hex: "#7209B7"),
                Color(hex: "#560BAD"),
                Color(hex: "#480CA8")
            ]
        case .forest:
            return [
                Color(hex: "#2DC653"),
                Color(hex: "#208B3A"),
                Color(hex: "#155D27"),
                Color(hex: "#10451D"),
                Color(hex: "#52B788")
            ]
        case .metallic:
            return [
                Color(hex: "#533483"),
                Color(hex: "#00B4D8"),
                Color(hex: "#0F3460"),
                Color(hex: "#16213E"),
                Color(hex: "#E0E0E0")
            ]
        case .warm:
            return [
                Color(hex: "#F59E0B"),
                Color(hex: "#EF4444"),
                Color(hex: "#8B5CF6"),
                Color(hex: "#06B6D4"),
                Color(hex: "#10B981")
            ]
        }
    }
}

// MARK: - Chart Config Model

struct ChartConfig: Identifiable, Codable, Equatable {
    var id = UUID()
    var chartType: ChartType
    var title: String
    var xAxisColumn: String?
    var yAxisColumn: String?
    var colorTheme: ColorTheme
    var showLegend: Bool
    var showGrid: Bool
    var showTooltips: Bool
    var showDataLabels: Bool
    var animationDuration: Double
    var autoSort: Bool = false
}

// MARK: - Chart Data Models

struct ChartDataPoint: Identifiable, Equatable {
    let id = UUID()
    let x: String
    let y: Double
    let series: String
}

struct ChartData: Equatable {
    var points: [ChartDataPoint] = []
    
    var isEmpty: Bool {
        points.isEmpty
    }
    
    var seriesNames: [String] {
        Array(Set(points.map { $0.series })).sorted()
    }
}
