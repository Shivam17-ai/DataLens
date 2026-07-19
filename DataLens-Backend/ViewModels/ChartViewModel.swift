import SwiftUI
import Combine
import AppKit

/// ChartViewModel manages chart configurations, color theme options,
/// background aggregations, and PNG image exporting.
class ChartViewModel: ObservableObject {
    @Published var selectedChartType: ChartType = .bar
    @Published var chartConfig: ChartConfig
    @Published var chartData: ChartData = ChartData()
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
    
    /// Handle initial column detection when a new dataset is loaded
    private func handleDatasetChange(_ dataset: DataSet?) {
        guard let dataset = dataset else {
            self.chartData = ChartData()
            self.chartConfig.xAxisColumn = nil
            self.chartConfig.yAxisColumn = nil
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
    
    /// Updates configuration and triggers aggregation recalculation
    func updateConfig(_ config: ChartConfig) {
        self.chartConfig = config
        self.selectedChartType = config.chartType
        if let dataset = dataViewModel.currentDataSet {
            prepareChartData(dataset: dataset, config: config)
        }
    }
    
    /// Aggregates and prepared chart points on a background queue
    func prepareChartData(dataset: DataSet, config: ChartConfig) {
        guard let xAxis = config.xAxisColumn, let yAxis = config.yAxisColumn else {
            self.chartData = ChartData()
            return
        }
        
        self.isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var grouped: [String: Double] = [:]
            
            for row in dataset.rows {
                let xVal: String
                if let rawX = row.values[xAxis] {
                    if let dateX = rawX as? Date {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .short
                        xVal = formatter.string(from: dateX)
                    } else {
                        xVal = "\(rawX)"
                    }
                } else {
                    xVal = "(blank)"
                }
                
                let yVal: Double
                if let rawY = row.values[yAxis] {
                    if let doubleY = rawY as? Double {
                        yVal = doubleY
                    } else if let intY = rawY as? Int {
                        yVal = Double(intY)
                    } else if let stringY = rawY as? String, let doubleY = Double(stringY) {
                        yVal = doubleY
                    } else {
                        yVal = 1.0 // Default count value if non-numeric
                    }
                } else {
                    yVal = 0.0
                }
                
                grouped[xVal, default: 0.0] += yVal
            }
            
            // Sort keys intelligently (supporting numeric or lexicographical)
            let sortedKeys = grouped.keys.sorted { a, b in
                if let doubleA = Double(a), let doubleB = Double(b) {
                    return doubleA < doubleB
                }
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
    
    /// Exports the chart view structure as a high-res PNG file using NSSavePanel
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
                            self.onShowToast?("Chart exported successfully to \(url.lastPathComponent)", .success)
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
}
