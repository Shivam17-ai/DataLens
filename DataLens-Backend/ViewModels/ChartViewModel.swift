import SwiftUI
import Combine
import AppKit

/// ChartViewModel manages chart configurations, color theme options,
/// background aggregations, annotation CRUD, and PNG image exporting.
class ChartViewModel: ObservableObject {
    @Published var selectedChartType: ChartType = .bar
    @Published var chartConfig: ChartConfig
    @Published var chartData: ChartData = ChartData()
    @Published var annotations: [ChartAnnotation] = []
    @Published var isLoading: Bool = false
    
    // Shared toast trigger callback (can be assigned by view layers)
    var onShowToast: ((String, ToastType) -> Void)?
    
    private let dataViewModel: DataViewModel
    private var cancellables = Set<AnyCancellable>()
    
    init(dataViewModel: DataViewModel) {
        self.dataViewModel = dataViewModel
        
        // Define default configuration
        self.chartConfig = ChartConfig(
            id: UUID(),
            chartType: .bar,
            title: "Untitled Chart",
            xAxisColumn: nil,
            yAxisColumn: nil,
            seriesColumn: nil,
            colorTheme: .ocean,
            showLegend: true,
            showGrid: true,
            showTooltips: true,
            showDataLabels: false,
            animationDuration: 0.6,
            autoSort: false
        )
        
        // Subscribe to DataViewModel dataset updates
        dataViewModel.$currentDataSet
            .sink { [weak self] dataset in
                guard let self = self else { return }
                self.handleDatasetChange(dataset)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Dataset Change Handler
    
    /// Handles column auto-selection when a new dataset becomes active.
    private func handleDatasetChange(_ dataset: DataSet?) {
        guard let dataset = dataset else {
            self.chartData = ChartData()
            self.chartConfig.xAxisColumn = nil
            self.chartConfig.yAxisColumn = nil
            self.chartConfig.seriesColumn = nil
            self.annotations = []
            return
        }
        
        let visibleCols = dataset.visibleColumns
        guard !visibleCols.isEmpty else { return }
        
        // Auto-select text/date for X, and number for Y
        let textOrDateCol = visibleCols.first { $0.type == .text || $0.type == .date } ?? visibleCols.first
        let numberCol = visibleCols.first { $0.type == .number } ?? visibleCols.first
        
        self.chartConfig.xAxisColumn = textOrDateCol?.name
        self.chartConfig.yAxisColumn = numberCol?.name
        self.chartConfig.title = "\(numberCol?.name ?? "Metric") by \(textOrDateCol?.name ?? "Category")"
        
        self.prepareChartData(dataset: dataset, config: self.chartConfig)
    }
    
    // MARK: - Config Updates
    
    /// Updates configuration and triggers aggregation recalculation.
    func updateConfig(_ config: ChartConfig) {
        self.chartConfig = config
        self.selectedChartType = config.chartType
        // Sync annotations from config
        self.annotations = config.annotations
        if let dataset = dataViewModel.currentDataSet {
            prepareChartData(dataset: dataset, config: config)
        }
    }
    
    // MARK: - Chart Data Preparation
    
    /// Routes to the correct aggregation function based on chart type.
    func prepareChartData(dataset: DataSet, config: ChartConfig) {
        switch config.chartType {
        case .line:
            let data = prepareLineData(dataset: dataset, config: config)
            DispatchQueue.main.async { [weak self] in
                self?.chartData = data
                self?.isLoading = false
            }
        case .area:
            let data = prepareAreaData(dataset: dataset, config: config)
            DispatchQueue.main.async { [weak self] in
                self?.chartData = data
                self?.isLoading = false
            }
        default:
            prepareBarData(dataset: dataset, config: config)
        }
    }
    
    /// Aggregates data for bar-style charts (grouped by X, summed Y).
    private func prepareBarData(dataset: DataSet, config: ChartConfig) {
        guard let xAxis = config.xAxisColumn, let yAxis = config.yAxisColumn else {
            self.chartData = ChartData()
            return
        }
        
        self.isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var grouped: [String: Double] = [:]
            
            for row in dataset.rows {
                let xVal = self.extractXLabel(row: row, column: xAxis)
                let yVal = self.extractYValue(row: row, column: yAxis)
                grouped[xVal, default: 0.0] += yVal
            }
            
            let sortedKeys = grouped.keys.sorted { a, b in
                if let da = Double(a), let db = Double(b) { return da < db }
                return a < b
            }
            
            let points = sortedKeys.map { key in
                ChartDataPoint(x: key, y: grouped[key] ?? 0.0, series: yAxis)
            }
            
            DispatchQueue.main.async {
                self.chartData = ChartData(points: points)
                self.isLoading = false
            }
        }
    }
    
    /// Prepares multi-series line data: each unique value in seriesColumn
    /// becomes its own series. If no series column is set, a single series is produced.
    func prepareLineData(dataset: DataSet, config: ChartConfig) -> ChartData {
        guard let xAxis = config.xAxisColumn, let yAxis = config.yAxisColumn else {
            return ChartData()
        }
        
        isLoading = true
        
        var points: [ChartDataPoint] = []
        
        if let seriesCol = config.seriesColumn, !seriesCol.isEmpty {
            // Multi-series: group by (seriesCol, xAxis) and sum yAxis
            var grouped: [String: [String: Double]] = [:] // [seriesVal: [xVal: yVal]]
            
            for row in dataset.rows {
                let xVal = extractXLabel(row: row, column: xAxis)
                let yVal = extractYValue(row: row, column: yAxis)
                let seriesVal = row.values[seriesCol].map { "\($0)" } ?? "(Other)"
                grouped[seriesVal, default: [:]][xVal, default: 0.0] += yVal
            }
            
            // Collect all unique X labels, sorted
            let allXLabels = Array(Set(dataset.rows.map { extractXLabel(row: $0, column: xAxis) })).sorted()
            
            for (seriesName, xMap) in grouped {
                for xLabel in allXLabels {
                    points.append(ChartDataPoint(x: xLabel, y: xMap[xLabel] ?? 0.0, series: seriesName))
                }
            }
        } else {
            // Single series: aggregate by xAxis, sum y
            var grouped: [String: Double] = [:]
            for row in dataset.rows {
                let xVal = extractXLabel(row: row, column: xAxis)
                let yVal = extractYValue(row: row, column: yAxis)
                grouped[xVal, default: 0.0] += yVal
            }
            let sortedKeys = grouped.keys.sorted { a, b in
                if let da = Double(a), let db = Double(b) { return da < db }
                return a < b
            }
            points = sortedKeys.map { ChartDataPoint(x: $0, y: grouped[$0] ?? 0.0, series: yAxis) }
        }
        
        return ChartData(points: points)
    }
    
    /// Prepares area chart data — same aggregation as line data.
    /// Stacking normalization (100%) is handled at the view layer since
    /// it requires knowing the full Y-per-X across all series.
    func prepareAreaData(dataset: DataSet, config: ChartConfig) -> ChartData {
        return prepareLineData(dataset: dataset, config: config)
    }
    
    // MARK: - Annotation CRUD
    
    /// Pins a new annotation to a specific data point.
    func addAnnotation(at point: ChartDataPoint, text: String) {
        let annotation = ChartAnnotation(
            xLabel: point.x,
            series: point.series,
            yValue: point.y,
            text: text
        )
        annotations.append(annotation)
        chartConfig.annotations.append(annotation)
    }
    
    /// Removes an annotation by its identifier.
    func removeAnnotation(id: UUID) {
        annotations.removeAll { $0.id == id }
        chartConfig.annotations.removeAll { $0.id == id }
    }
    
    // MARK: - Export
    
    /// Exports the chart view structure as a high-res PNG file using NSSavePanel.
    func exportChart<V: View>(view: V) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0 // High DPI rendering
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        
        let sanitizedTitle = chartConfig.title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "_")
        
        savePanel.nameFieldStringValue = "\(sanitizedTitle).png"
        
        savePanel.begin { [weak self] response in
            guard let self = self else { return }
            if response == .OK, let url = savePanel.url {
                if let nsImage = renderer.nsImage {
                    if let tiffData = nsImage.tiffRepresentation,
                       let bitmapImage = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                        do {
                            try pngData.write(to: url)
                            self.onShowToast?("Chart exported to \(url.lastPathComponent)", .success)
                        } catch {
                            self.onShowToast?("Export failed: \(error.localizedDescription)", .error)
                        }
                    }
                } else {
                    self.onShowToast?("Failed to render chart image.", .error)
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    /// Extracts a display-ready string value from a row for the X axis.
    private func extractXLabel(row: Row, column: String) -> String {
        guard let rawX = row.values[column] else { return "(blank)" }
        if let dateX = rawX as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: dateX)
        }
        return "\(rawX)"
    }
    
    /// Extracts a numeric Y value from a row, defaulting to 1.0 for non-numeric types.
    private func extractYValue(row: Row, column: String) -> Double {
        guard let rawY = row.values[column] else { return 0.0 }
        if let d = rawY as? Double { return d }
        if let i = rawY as? Int { return Double(i) }
        if let s = rawY as? String, let d = Double(s) { return d }
        return 1.0
    }
}
