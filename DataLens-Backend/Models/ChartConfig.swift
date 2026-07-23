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

// MARK: - Line Interpolation Mode

enum LineInterpolation: String, CaseIterable, Identifiable, Codable {
    case curved = "Curved"
    case straight = "Straight"
    
    var id: String { rawValue }
}

// MARK: - Area Baseline Mode

enum AreaBaseline: String, CaseIterable, Identifiable, Codable {
    case zero = "Zero"
    case minimum = "Minimum Value"
    case custom = "Custom Value"
    
    var id: String { rawValue }
}

// MARK: - Area Stacking Mode

enum AreaStackMode: String, CaseIterable, Identifiable, Codable {
    case none = "None"
    case stacked = "Stacked"
    case normalized = "100% Stacked"
    
    var id: String { rawValue }
}

// MARK: - Donut Center Content Options

enum DonutCenterContent: String, CaseIterable, Identifiable, Codable {
    case totalValue = "Total Value"
    case totalCount = "Total Count"
    case percentage = "Percentage"
    case customText = "Custom Text"
    
    var id: String { rawValue }
}

// MARK: - Slice Sort Order

enum SliceSortOrder: String, CaseIterable, Identifiable, Codable {
    case descending = "Value Descending"
    case ascending = "Value Ascending"
    case alphabetical = "Alphabetical"
    case original = "Original Order"
    
    var id: String { rawValue }
}

// MARK: - Trend Line Type

enum TrendLineType: String, CaseIterable, Identifiable, Codable {
    case none = "None"
    case linear = "Linear Regression"
    case polynomial = "Polynomial Curve (Order 2)"
    
    var id: String { rawValue }
}

// MARK: - Histogram Type (Y-Axis Metric)

enum HistogramType: String, CaseIterable, Identifiable, Codable {
    case frequency = "Frequency Count"
    case density = "Density Percentage"
    
    var id: String { rawValue }
}

// MARK: - Box Sort Order

enum BoxSortOrder: String, CaseIterable, Identifiable, Codable {
    case alphabetical = "Category Name"
    case median = "Median Value"
    case mean = "Mean Value"
    case original = "Original Order"
    
    var id: String { rawValue }
}

// MARK: - Box Plot Orientation

enum BoxPlotOrientation: String, CaseIterable, Identifiable, Codable {
    case vertical = "Vertical"
    case horizontal = "Horizontal"
    
    var id: String { rawValue }
}

// MARK: - Chart Annotation Model

struct ChartAnnotation: Identifiable, Codable, Equatable {
    var id = UUID()
    /// The X-axis category label this annotation is pinned to
    var xLabel: String
    /// The series name this annotation references
    var series: String
    /// The numeric Y value at pin point (for display)
    var yValue: Double
    /// User-authored annotation text
    var text: String
}

// MARK: - Chart Config Model

struct ChartConfig: Identifiable, Codable, Equatable {
    var id = UUID()
    var chartType: ChartType
    var title: String
    var xAxisColumn: String?
    var yAxisColumn: String?
    /// Optional second grouping column for multi-series breakdown
    var seriesColumn: String?
    var colorTheme: ColorTheme
    var showLegend: Bool
    var showGrid: Bool
    var showTooltips: Bool
    var showDataLabels: Bool
    var animationDuration: Double
    var autoSort: Bool = false
    
    // MARK: Line / Area chart settings
    var interpolationMode: LineInterpolation = .curved
    var showReferenceLines: Bool = false
    var customReferenceLineValue: Double? = nil
    var customReferenceLineLabel: String? = nil
    var yAxisMinOverride: Double? = nil
    var yAxisMaxOverride: Double? = nil
    
    // MARK: Area chart specific settings
    var baselineMode: AreaBaseline = .zero
    var customBaselineValue: Double = 0
    var stackMode: AreaStackMode = .none
    
    // MARK: Pie / Donut chart specific settings
    var maxSlices: Int = 12
    var groupSmallSlices: Bool = true
    var smallSliceThreshold: Double = 0.02
    var explodeAll: Bool = false
    var semiCircleMode: Bool = false
    var donutCenterText: DonutCenterContent = .totalValue
    var customCenterText: String = ""
    var showLeaderLines: Bool = true
    var pieStartAngle: Double = -90.0
    var comparisonColumn: String? = nil
    var sliceSortOrder: SliceSortOrder = .descending
    
    // MARK: Statistical chart settings
    
    // Scatter & Bubble options
    var bubbleSizeColumn: String? = nil
    var bubbleColorColumn: String? = nil
    var showTrendLine: Bool = false
    var trendLineType: TrendLineType = .none
    var showQuadrantLines: Bool = false
    var showDensityOverlay: Bool = false
    var xAxisLogScale: Bool = false
    var yAxisLogScale: Bool = false
    var zeroOrigin: Bool = false
    
    // Histogram options
    var histogramBinCount: Int = 10
    var useAutoBin: Bool = true // Sturges Rule
    var histogramType: HistogramType = .frequency
    var showNormalCurve: Bool = false
    var showOutlierHighlight: Bool = false
    var cumulativeHistogram: Bool = false
    
    // Box Plot options
    var boxPlotNotched: Bool = false
    var showViolinOverlay: Bool = false
    var boxPlotOrientation: BoxPlotOrientation = .vertical
    var boxSortOrder: BoxSortOrder = .alphabetical
    
    // MARK: Persistent annotations
    var annotations: [ChartAnnotation] = []
}

// MARK: - Chart Data Models

struct ChartDataPoint: Identifiable, Equatable {
    let id = UUID()
    let x: String
    let y: Double
    let series: String
    
    // Additional parameters for statistical dimensions
    var sizeValue: Double? = nil
    var colorValue: Double? = nil
    var rawIndex: Int? = nil
}

struct ChartData: Equatable {
    var points: [ChartDataPoint] = []
    
    var isEmpty: Bool {
        points.isEmpty
    }
    
    var seriesNames: [String] {
        Array(Set(points.map { $0.series })).sorted()
    }
    
    /// Returns points grouped by series name, preserving x-order.
    var pointsBySeries: [String: [ChartDataPoint]] {
        Dictionary(grouping: points, by: { $0.series })
    }
    
    /// Returns the overall Y range across all points.
    var yRange: ClosedRange<Double> {
        let values = points.map { $0.y }
        let minY = values.min() ?? 0
        let maxY = values.max() ?? 1
        return minY...maxY
    }
    
    /// Returns the overall X range across all points (for numerical X axis).
    var xRange: ClosedRange<Double> {
        let values = points.compactMap { Double($0.x) }
        let minX = values.min() ?? 0
        let maxX = values.max() ?? 1
        return minX...maxX
    }
    
    /// Average Y value across all points.
    var averageY: Double {
        guard !points.isEmpty else { return 0 }
        return points.map { $0.y }.reduce(0, +) / Double(points.count)
    }
}
