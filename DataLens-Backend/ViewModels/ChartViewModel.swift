import SwiftUI
import Combine
import AppKit

// MARK: - Statistical Support Structs

struct TrendLineData: Equatable {
    var rSquared: Double = 0.0
    var points: [ChartDataPoint] = []
}

struct HistogramBin: Identifiable, Equatable {
    var id = UUID()
    let lowerBound: Double
    let upperBound: Double
    var count: Int
    var density: Double
    var cumulativePercentage: Double
}

struct BoxPlotStats: Equatable {
    let min: Double
    let q1: Double
    let median: Double
    let q3: Double
    let max: Double
    let mean: Double
    let iqr: Double
    let lowerWhisker: Double
    let upperWhisker: Double
    let outliers: [Double]
    let confidenceInterval: ClosedRange<Double>
}

// MARK: - Main ChartViewModel

class ChartViewModel: ObservableObject {
    @Published var selectedChartType: ChartType = .bar
    @Published var chartConfig: ChartConfig
    @Published var chartData: ChartData = ChartData()
    @Published var annotations: [ChartAnnotation] = []
    @Published var selectedSlice: ChartDataPoint? = nil
    
    // Statistical workspace states
    @Published var ignoredNullCount: Int = 0
    @Published var trendLineData = TrendLineData()
    @Published var histogramBins: [HistogramBin] = []
    @Published var histogramRawValues: [Double] = []
    @Published var boxPlotStats: [String: BoxPlotStats] = [:]
    @Published var selectedScatterPoints: Set<UUID> = []
    
    @Published var isLoading: Bool = false
    
    var onShowToast: ((String, ToastType) -> Void)?
    
    private let dataViewModel: DataViewModel
    private var cancellables = Set<AnyCancellable>()
    
    init(dataViewModel: DataViewModel) {
        self.dataViewModel = dataViewModel
        
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
        
        dataViewModel.$currentDataSet
            .sink { [weak self] dataset in
                guard let self = self else { return }
                self.handleDatasetChange(dataset)
            }
            .store(in: &cancellables)
    }
    
    private func handleDatasetChange(_ dataset: DataSet?) {
        guard let dataset = dataset else {
            self.chartData = ChartData()
            self.chartConfig.xAxisColumn = nil
            self.chartConfig.yAxisColumn = nil
            self.chartConfig.seriesColumn = nil
            self.annotations = []
            self.selectedSlice = nil
            self.ignoredNullCount = 0
            self.trendLineData = TrendLineData()
            self.histogramBins = []
            self.histogramRawValues = []
            self.boxPlotStats = [:]
            self.selectedScatterPoints = []
            return
        }
        
        let visibleCols = dataset.visibleColumns
        guard !visibleCols.isEmpty else { return }
        
        let textOrDateCol = visibleCols.first { $0.type == .text || $0.type == .date } ?? visibleCols.first
        let numberCol = visibleCols.first { $0.type == .number } ?? visibleCols.first
        
        self.chartConfig.xAxisColumn = textOrDateCol?.name
        self.chartConfig.yAxisColumn = numberCol?.name
        self.chartConfig.title = "\(numberCol?.name ?? "Metric") by \(textOrDateCol?.name ?? "Category")"
        
        self.prepareChartData(dataset: dataset, config: self.chartConfig)
    }
    
    func updateConfig(_ config: ChartConfig) {
        self.chartConfig = config
        self.selectedChartType = config.chartType
        self.annotations = config.annotations
        if let dataset = dataViewModel.currentDataSet {
            prepareChartData(dataset: dataset, config: config)
        }
    }
    
    // MARK: - Dispatcher
    
    func prepareChartData(dataset: DataSet, config: ChartConfig) {
        self.isLoading = true
        self.ignoredNullCount = 0
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let data: ChartData
            switch config.chartType {
            case .scatter:
                data = self.prepareScatterData(dataset: dataset, config: config)
            case .bubble:
                data = self.prepareBubbleData(dataset: dataset, config: config)
            case .histogram:
                data = self.prepareHistogramData(dataset: dataset, config: config)
            case .boxPlot:
                data = self.prepareBoxPlotData(dataset: dataset, config: config)
            case .line:
                data = self.prepareLineData(dataset: dataset, config: config)
            case .area:
                data = self.prepareAreaData(dataset: dataset, config: config)
            case .pie, .donut:
                data = self.preparePieData(dataset: dataset, config: config)
            default:
                data = self.prepareDefaultBarData(dataset: dataset, config: config)
            }
            
            DispatchQueue.main.async {
                self.chartData = data
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Default Bar Data Preparation
    
    private func prepareDefaultBarData(dataset: DataSet, config: ChartConfig) -> ChartData {
        guard let xAxis = config.xAxisColumn, let yAxis = config.yAxisColumn else {
            return ChartData()
        }
        
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
        
        let points = sortedKeys.map { key in
            ChartDataPoint(x: key, y: grouped[key] ?? 0.0, series: yAxis)
        }
        return ChartData(points: points)
    }
    
    // MARK: - Line/Area/Pie Data Helpers (cloned from W2D2/W2D3)
    
    func prepareLineData(dataset: DataSet, config: ChartConfig) -> ChartData {
        guard let xAxis = config.xAxisColumn, let yAxis = config.yAxisColumn else {
            return ChartData()
        }
        var points: [ChartDataPoint] = []
        if let seriesCol = config.seriesColumn, !seriesCol.isEmpty {
            var grouped: [String: [String: Double]] = [:]
            for row in dataset.rows {
                let xVal = extractXLabel(row: row, column: xAxis)
                let yVal = extractYValue(row: row, column: yAxis)
                let seriesVal = row.values[seriesCol].map { "\($0)" } ?? "(Other)"
                grouped[seriesVal, default: [:]][xVal, default: 0.0] += yVal
            }
            let allXLabels = Array(Set(dataset.rows.map { extractXLabel(row: $0, column: xAxis) })).sorted()
            for (seriesName, xMap) in grouped {
                for xLabel in allXLabels {
                    points.append(ChartDataPoint(x: xLabel, y: xMap[xLabel] ?? 0.0, series: seriesName))
                }
            }
        } else {
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
    
    func prepareAreaData(dataset: DataSet, config: ChartConfig) -> ChartData {
        return prepareLineData(dataset: dataset, config: config)
    }
    
    func preparePieData(dataset: DataSet, config: ChartConfig) -> ChartData {
        guard let xAxis = config.xAxisColumn, let yAxis = config.yAxisColumn else {
            return ChartData()
        }
        var rawGrouped: [String: Double] = [:]
        var originalOrder: [String] = []
        for row in dataset.rows {
            let xVal = extractXLabel(row: row, column: xAxis)
            let yVal = extractYValue(row: row, column: yAxis)
            if rawGrouped[xVal] == nil {
                originalOrder.append(xVal)
            }
            rawGrouped[xVal, default: 0.0] += yVal
        }
        let nonZeroGrouped = rawGrouped.filter { $0.value > 0 }
        let totalSum = nonZeroGrouped.values.reduce(0.0, +)
        guard totalSum > 0 else { return ChartData() }
        let sortedByValue = nonZeroGrouped.sorted { $0.value > $1.value }
        var keptSlices: [ChartDataPoint] = []
        var otherSum = 0.0
        for (index, item) in sortedByValue.enumerated() {
            let pct = item.value / totalSum
            let exceedsThreshold = !config.groupSmallSlices || pct >= config.smallSliceThreshold
            let withinMaxLimit = keptSlices.count < (config.maxSlices - 1)
            if exceedsThreshold && withinMaxLimit {
                keptSlices.append(ChartDataPoint(x: item.key, y: item.value, series: item.key))
            } else {
                otherSum += item.value
            }
        }
        switch config.sliceSortOrder {
        case .descending:
            keptSlices.sort { $0.y > $1.y }
        case .ascending:
            keptSlices.sort { $0.y < $1.y }
        case .alphabetical:
            keptSlices.sort { $0.x.localizedCaseInsensitiveCompare($1.x) == .orderedAscending }
        case .original:
            let orderDict = Dictionary(uniqueKeysWithValues: originalOrder.enumerated().map { ($0.element, $0.offset) })
            keptSlices.sort {
                let idxA = orderDict[$0.x] ?? Int.max
                let idxB = orderDict[$1.x] ?? Int.max
                return idxA < idxB
            }
        }
        if otherSum > 0 {
            keptSlices.append(ChartDataPoint(x: "Other", y: otherSum, series: "Other"))
        }
        return ChartData(points: keptSlices)
    }
    
    // MARK: - Scatter Data Preparation
    
    func prepareScatterData(dataset: DataSet, config: ChartConfig) -> ChartData {
        guard let xAxis = config.xAxisColumn, let yAxis = config.yAxisColumn else {
            return ChartData()
        }
        
        var points: [ChartDataPoint] = []
        var nulls = 0
        
        for (idx, row) in dataset.rows.enumerated() {
            guard let xVal = extractYValueOptional(row: row, column: xAxis),
                  let yVal = extractYValueOptional(row: row, column: yAxis) else {
                nulls += 1
                continue
            }
            
            let seriesName = config.seriesColumn.flatMap { row.values[$0].map { "\($0)" } } ?? "Data Points"
            points.append(
                ChartDataPoint(
                    x: "\(xVal)",
                    y: yVal,
                    series: seriesName,
                    rawIndex: idx + 1
                )
            )
        }
        
        DispatchQueue.main.async {
            self.ignoredNullCount = nulls
        }
        
        let data = ChartData(points: points)
        
        // Compute trend lines on main thread context
        if config.showTrendLine {
            let trend = calculateTrendLine(data: data)
            DispatchQueue.main.async {
                self.trendLineData = trend
            }
        }
        
        return data
    }
    
    // MARK: - Bubble Data Preparation
    
    func prepareBubbleData(dataset: DataSet, config: ChartConfig) -> ChartData {
        guard let xAxis = config.xAxisColumn, let yAxis = config.yAxisColumn else {
            return ChartData()
        }
        
        var points: [ChartDataPoint] = []
        var nulls = 0
        
        let sizeCol = config.bubbleSizeColumn
        let colorCol = config.bubbleColorColumn
        
        for (idx, row) in dataset.rows.enumerated() {
            guard let xVal = extractYValueOptional(row: row, column: xAxis),
                  let yVal = extractYValueOptional(row: row, column: yAxis) else {
                nulls += 1
                continue
            }
            
            let sValue = sizeCol.flatMap { extractYValueOptional(row: row, column: $0) }
            let cValue = colorCol.flatMap { extractYValueOptional(row: row, column: $0) }
            
            let seriesName = config.seriesColumn.flatMap { row.values[$0].map { "\($0)" } } ?? "Data Points"
            points.append(
                ChartDataPoint(
                    x: "\(xVal)",
                    y: yVal,
                    series: seriesName,
                    sizeValue: sValue,
                    colorValue: cValue,
                    rawIndex: idx + 1
                )
            )
        }
        
        DispatchQueue.main.async {
            self.ignoredNullCount = nulls
        }
        
        let data = ChartData(points: points)
        return data
    }
    
    // MARK: - Histogram Data Preparation
    
    func prepareHistogramData(dataset: DataSet, config: ChartConfig) -> ChartData {
        guard let xAxis = config.xAxisColumn else {
            return ChartData()
        }
        
        var values: [Double] = []
        var nulls = 0
        
        for row in dataset.rows {
            if let val = extractYValueOptional(row: row, column: xAxis) {
                values.append(val)
            } else {
                nulls += 1
            }
        }
        
        DispatchQueue.main.async {
            self.ignoredNullCount = nulls
        }
        
        guard !values.isEmpty else { return ChartData() }
        
        // Calculate Bins
        let binCount: Int
        if config.useAutoBin {
            // Sturges rule: log2(n) + 1
            binCount = max(5, min(50, Int(ceil(log2(Double(values.count)) + 1))))
        } else {
            binCount = config.histogramBinCount
        }
        
        let bins = calculateBins(values: values, count: binCount)
        DispatchQueue.main.async {
            self.histogramBins = bins
            self.histogramRawValues = values
        }
        
        // Map bins to visual points
        let points = bins.map { bin in
            let label = String(format: "%.1f - %.1f", bin.lowerBound, bin.upperBound)
            let yVal = config.histogramType == .frequency ? Double(bin.count) : bin.density * 100.0
            return ChartDataPoint(x: label, y: yVal, series: "Frequency")
        }
        
        return ChartData(points: points)
    }
    
    // MARK: - Box Plot Data Preparation
    
    func prepareBoxPlotData(dataset: DataSet, config: ChartConfig) -> ChartData {
        guard let xAxis = config.xAxisColumn, let yAxis = config.yAxisColumn else {
            return ChartData()
        }
        
        var groupedValues: [String: [Double]] = [:]
        var nulls = 0
        
        for row in dataset.rows {
            let cat = extractXLabel(row: row, column: xAxis)
            if let val = extractYValueOptional(row: row, column: yAxis) {
                groupedValues[cat, default: []].append(val)
            } else {
                nulls += 1
            }
        }
        
        DispatchQueue.main.async {
            self.ignoredNullCount = nulls
        }
        
        var statsMap: [String: BoxPlotStats] = [:]
        for (cat, vals) in groupedValues {
            statsMap[cat] = calculateBoxStats(values: vals)
        }
        
        DispatchQueue.main.async {
            self.boxPlotStats = statsMap
        }
        
        // Order categories appropriately
        let sortedCats = statsMap.keys.sorted { a, b in
            let statA = statsMap[a]!
            let statB = statsMap[b]!
            
            switch config.boxSortOrder {
            case .median:
                return statA.median < statB.median
            case .mean:
                return statA.mean < statB.mean
            case .alphabetical:
                return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
            case .original:
                return true
            }
        }
        
        // Create baseline median points for standard layout bindings
        let points = sortedCats.map { cat in
            ChartDataPoint(x: cat, y: statsMap[cat]?.median ?? 0.0, series: cat)
        }
        
        return ChartData(points: points)
    }
    
    // MARK: - Statistical Calculations
    
    func calculateTrendLine(data: ChartData) -> TrendLineData {
        let numericPoints = data.points.compactMap { pt -> (x: Double, y: Double)? in
            guard let dx = Double(pt.x) else { return nil }
            return (dx, pt.y)
        }
        
        guard numericPoints.count > 1 else { return TrendLineData() }
        
        let n = Double(numericPoints.count)
        let xs = numericPoints.map { $0.x }
        let ys = numericPoints.map { $0.y }
        
        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        
        // Means
        let meanX = sumX / n
        let meanY = sumY / n
        
        var trendPoints: [ChartDataPoint] = []
        var rSquared = 0.0
        
        if chartConfig.trendLineType == .linear {
            // Linear regression: y = mx + c
            let sumXY = numericPoints.map { $0.x * $0.y }.reduce(0, +)
            let sumX2 = numericPoints.map { $0.x * $0.x }.reduce(0, +)
            
            let denom = n * sumX2 - sumX * sumX
            guard denom != 0 else { return TrendLineData() }
            
            let m = (n * sumXY - sumX * sumY) / denom
            let c = (sumY - m * sumX) / n
            
            // Plot trend lines across the min/max X boundaries
            let minX = xs.min() ?? 0.0
            let maxX = xs.max() ?? 10.0
            let step = (maxX - minX) / 20.0
            
            for i in 0...20 {
                let currX = minX + Double(i) * step
                let predY = m * currX + c
                trendPoints.append(ChartDataPoint(x: String(format: "%.2f", currX), y: predY, series: "Trend Line"))
            }
            
            // Compute R-squared
            let sst = ys.map { pow($0 - meanY, 2) }.reduce(0, +)
            let ssr = numericPoints.map { pow($0.y - (m * $0.x + c), 2) }.reduce(0, +)
            rSquared = sst > 0 ? (1.0 - (ssr / sst)) : 1.0
            
        } else if chartConfig.trendLineType == .polynomial {
            // Quadratic polynomial regression: y = ax^2 + bx + c
            // Solve standard linear equations:
            // | sum(x^4)  sum(x^3)  sum(x^2) |   | a |   | sum(x^2 * y) |
            // | sum(x^3)  sum(x^2)  sum(x)   | * | b | = | sum(x * y)   |
            // | sum(x^2)  sum(x)    n        |   | c |   | sum(y)       |
            
            let sumX2 = xs.map { $0 * $0 }.reduce(0, +)
            let sumX3 = xs.map { $0 * $0 * $0 }.reduce(0, +)
            let sumX4 = xs.map { $0 * $0 * $0 * $0 }.reduce(0, +)
            let sumXY = numericPoints.map { $0.x * $0.y }.reduce(0, +)
            let sumX2Y = numericPoints.map { $0.x * $0.x * $0.y }.reduce(0, +)
            
            // Determinant formulas using Cramer's rule
            let d = sumX4 * (sumX2 * n - sumX * sumX) - sumX3 * (sumX3 * n - sumX2 * sumX) + sumX2 * (sumX3 * sumX - sumX2 * sumX2)
            
            if abs(d) > 0.0001 {
                let da = sumX2Y * (sumX2 * n - sumX * sumX) - sumX3 * (sumXY * n - sumY * sumX) + sumX2 * (sumXY * sumX - sumY * sumX2)
                let db = sumX4 * (sumXY * n - sumY * sumX) - sumX2Y * (sumX3 * n - sumX2 * sumX) + sumX2 * (sumX3 * sumY - sumX2 * sumXY)
                let dc = sumX4 * (sumX2 * sumY - sumX * sumXY) - sumX3 * (sumX3 * sumY - sumX2 * sumXY) + sumX2Y * (sumX3 * sumX - sumX2 * sumX2)
                
                let aCoef = da / d
                let bCoef = db / d
                let cCoef = dc / d
                
                let minX = xs.min() ?? 0.0
                let maxX = xs.max() ?? 10.0
                let step = (maxX - minX) / 30.0
                
                for i in 0...30 {
                    let currX = minX + Double(i) * step
                    let predY = aCoef * currX * currX + bCoef * currX + cCoef
                    trendPoints.append(ChartDataPoint(x: String(format: "%.2f", currX), y: predY, series: "Trend Line"))
                }
                
                let sst = ys.map { pow($0 - meanY, 2) }.reduce(0, +)
                let ssr = numericPoints.map { pow($0.y - (aCoef * $0.x * $0.x + bCoef * $0.x + cCoef), 2) }.reduce(0, +)
                rSquared = sst > 0 ? (1.0 - (ssr / sst)) : 1.0
            }
        }
        
        return TrendLineData(rSquared: rSquared, points: trendPoints)
    }
    
    func calculateBins(values: [Double], count: Int) -> [HistogramBin] {
        guard !values.isEmpty, count > 0 else { return [] }
        let sorted = values.sorted()
        let minVal = sorted.first!
        let maxVal = sorted.last!
        
        // Handle edge case of single value dataset
        let range = maxVal - minVal
        let step = range == 0 ? 1.0 : range / Double(count)
        
        var bins: [HistogramBin] = []
        for i in 0..<count {
            let lower = minVal + Double(i) * step
            let upper = lower + step
            bins.append(HistogramBin(lowerBound: lower, upperBound: upper, count: 0, density: 0.0, cumulativePercentage: 0.0))
        }
        
        // Count values falling into bins
        for val in sorted {
            var placed = false
            for idx in 0..<count {
                // If it's the last bin, include the upper boundary
                let isLast = idx == count - 1
                let matches = isLast ? (val >= bins[idx].lowerBound && val <= bins[idx].upperBound) : (val >= bins[idx].lowerBound && val < bins[idx].upperBound)
                
                if matches {
                    bins[idx].count += 1
                    placed = true
                    break
                }
            }
            if !placed && val >= bins.last!.upperBound {
                bins[count - 1].count += 1
            }
        }
        
        // Calculate density metrics
        let total = Double(values.count)
        var runningSum = 0.0
        for idx in 0..<count {
            bins[idx].density = Double(bins[idx].count) / total
            runningSum += Double(bins[idx].count)
            bins[idx].cumulativePercentage = runningSum / total
        }
        
        return bins
    }
    
    func calculateBoxStats(values: [Double]) -> BoxPlotStats {
        guard !values.isEmpty else {
            return BoxPlotStats(min: 0, q1: 0, median: 0, q3: 0, max: 0, mean: 0, iqr: 0, lowerWhisker: 0, upperWhisker: 0, outliers: [], confidenceInterval: 0...0)
        }
        let sorted = values.sorted()
        let minVal = sorted.first!
        let maxVal = sorted.last!
        
        let sum = sorted.reduce(0, +)
        let meanVal = sum / Double(sorted.count)
        
        // Percentile calculator helper
        let q1Val = percentile(sorted, 0.25)
        let medianVal = percentile(sorted, 0.50)
        let q3Val = percentile(sorted, 0.75)
        
        let iqrVal = q3Val - q1Val
        let lowerWhiskerLimit = q1Val - 1.5 * iqrVal
        let upperWhiskerLimit = q3Val + 1.5 * iqrVal
        
        // Whisker endpoints cap at actual data boundaries
        let lowerWhiskerVal = sorted.first { $0 >= lowerWhiskerLimit } ?? minVal
        let upperWhiskerVal = sorted.reversed().first { $0 <= upperWhiskerLimit } ?? maxVal
        
        // Outliers are values outside whisker range
        let outliersVal = sorted.filter { $0 < lowerWhiskerVal || $0 > upperWhiskerVal }
        
        // Notch height (confidence interval of the median)
        let notchWidth = 1.57 * iqrVal / sqrt(Double(sorted.count))
        let lowerCI = medianVal - notchWidth
        let upperCI = medianVal + notchWidth
        
        return BoxPlotStats(
            min: minVal,
            q1: q1Val,
            median: medianVal,
            q3: q3Val,
            max: maxVal,
            mean: meanVal,
            iqr: iqrVal,
            lowerWhisker: lowerWhiskerVal,
            upperWhisker: upperWhiskerVal,
            outliers: outliersVal,
            confidenceInterval: lowerCI...upperCI
        )
    }
    
    private func percentile(_ sortedValues: [Double], _ p: Double) -> Double {
        guard !sortedValues.isEmpty else { return 0.0 }
        let index = p * Double(sortedValues.count - 1)
        let lower = Int(floor(index))
        let upper = Int(ceil(index))
        if lower == upper {
            return sortedValues[lower]
        }
        let weight = index - Double(lower)
        return sortedValues[lower] * (1.0 - weight) + sortedValues[upper] * weight
    }
    
    // MARK: - Formatting/Data Parsing Utilities
    
    private func extractXLabel(row: Row, column: String) -> String {
        guard let rawX = row.values[column] else { return "(blank)" }
        if let dateX = rawX as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: dateX)
        }
        return "\(rawX)"
    }
    
    private func extractYValue(row: Row, column: String) -> Double {
        return extractYValueOptional(row: row, column: column) ?? 1.0
    }
    
    private func extractYValueOptional(row: Row, column: String) -> Double? {
        guard let rawY = row.values[column] else { return nil }
        if let d = rawY as? Double { return d }
        if let i = rawY as? Int { return Double(i) }
        if let s = rawY as? String, let d = Double(s) { return d }
        return nil
    }
    
    // MARK: - Global Image Export PNG
    
    func exportChart<V: View>(view: V) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        
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
}
