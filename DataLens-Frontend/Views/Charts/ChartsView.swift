import SwiftUI

/// ChartsView represents the main workspace for data visualization.
/// It features a sidebar for selecting chart types, and a main canvas area
/// with toolbar selectors (X/Y axes, title, theme, auto-sort) and the active chart.
/// It now also hosts the cross-filter chips bar and the collapsible FilterPanelView.
struct ChartsView: View {
    @EnvironmentObject var dataViewModel: DataViewModel
    @EnvironmentObject var toastManager: ToastManager
    @EnvironmentObject var crossFilterManager: CrossFilterManager
    @ObservedObject var navigationViewModel: NavigationViewModel
    
    @StateObject private var chartViewModel: ChartViewModel
    @StateObject private var filterViewModel: FilterViewModel
    @State private var highlightedSeries: Set<String> = []
    @State private var showFilterPanel: Bool = false
    
    init(navigationViewModel: NavigationViewModel, dataViewModel: DataViewModel) {
        self.navigationViewModel = navigationViewModel
        let cfm = CrossFilterManager()
        self._chartViewModel  = StateObject(wrappedValue: ChartViewModel(dataViewModel: dataViewModel))
        self._filterViewModel = StateObject(wrappedValue: FilterViewModel(crossFilterManager: cfm))
    }
    
    var body: some View {
        HStack(spacing: 0) {
            
            // MARK: - Left Panel: Chart Selector (240pt)
            VStack(alignment: .leading, spacing: 0) {
                Text("Chart Library")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ColorPalette.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                
                Divider()
                    .background(ColorPalette.border)
                    
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ChartTypeSection(
                            title: "Basic Charts",
                            types: [.bar, .horizontalBar, .line, .area, .pie, .donut],
                            selectedType: $chartViewModel.chartConfig.chartType
                        )
                        
                        ChartTypeSection(
                            title: "Statistical Charts",
                            types: [.scatter, .bubble, .histogram, .boxPlot],
                            selectedType: $chartViewModel.chartConfig.chartType
                        )
                        
                        ChartTypeSection(
                            title: "Advanced Charts",
                            types: [.heatmap, .treemap, .waterfall, .funnel, .gauge],
                            selectedType: $chartViewModel.chartConfig.chartType
                        )
                    }
                    .padding(16)
                }
            }
            .frame(width: 240)
            .background(ColorPalette.sidebar)
            .overlay(
                Rectangle()
                    .fill(ColorPalette.border)
                    .frame(width: 1),
                alignment: .trailing
            )
            
            // MARK: - Right Panel: Toolbar + Filter Bar + Canvas (+ optional filter panel)
            HStack(spacing: 0) {
                VStack(spacing: 0) {

                    // ── Chart Configuration Toolbar ──────────────────────
                    HStack(spacing: 0) {
                        ChartsToolbar(chartViewModel: chartViewModel)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)

                        // Filter panel toggle button
                        Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showFilterPanel.toggle() } }) {
                            Image(systemName: showFilterPanel ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(crossFilterManager.hasActiveFilters ? ColorPalette.accent : ColorPalette.textSecondary)
                                .padding(.trailing, 16)
                        }
                        .buttonStyle(.plain)
                        .help(showFilterPanel ? "Hide Filters" : "Show Filters")
                    }
                    .background(ColorPalette.sidebar.opacity(0.6))
                    .overlay(VStack { Spacer(); Rectangle().fill(ColorPalette.border).frame(height: 1) })

                    // ── Active Filter Chips Bar ──────────────────────────
                    if crossFilterManager.hasActiveFilters {
                        ActiveFilterChipsBar(crossFilterManager: crossFilterManager)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // ── Canvas Area ──────────────────────────────────────
                    ZStack {
                        ColorPalette.background
                            .edgesIgnoringSafeArea(.all)

                        if dataViewModel.currentDataSet == nil {
                            EmptyStateView(
                                iconName: "square.and.arrow.down",
                                title: Constants.EmptyStates.noDataTitle,
                                subtitle: Constants.EmptyStates.noDataSubtitle,
                                actionButtonTitle: "Import Data",
                                action: {
                                    withAnimation { navigationViewModel.navigate(to: .importData) }
                                }
                            )
                        } else if (filterViewModel.filteredDataSet?.rowCount ?? 0) == 0
                                    && crossFilterManager.hasActiveFilters {
                            // Empty-filtered state
                            VStack(spacing: 12) {
                                EmptyStateView(
                                    iconName: "line.3.horizontal.decrease.circle",
                                    title: "No data matches current filters",
                                    subtitle: "Try removing a filter or widening the date range.",
                                    actionButtonTitle: "Clear Filters",
                                    action: { filterViewModel.clearAllFilters() }
                                )
                            }
                        } else {
                            // Interactive Chart Container
                            ChartContainer(
                                title: chartViewModel.chartConfig.title,
                                config: chartViewModel.chartConfig,
                                seriesList: chartViewModel.chartData.seriesNames,
                                colors: chartViewModel.chartConfig.colorTheme.colors,
                                isEmpty: chartViewModel.chartData.isEmpty,
                                isLoading: chartViewModel.isLoading || crossFilterManager.isFiltering,
                                highlightedSeries: $highlightedSeries,
                                onExport: { chartViewModel.exportChart(view: currentChartView) }
                            ) {
                                currentChartView
                            }
                            .padding(16)
                        }
                    }
                }

                // ── Collapsible Filter Panel ─────────────────────────────
                if showFilterPanel, let dataset = dataViewModel.currentDataSet {
                    Rectangle().fill(ColorPalette.border).frame(width: 1)
                    FilterPanelView(filterViewModel: filterViewModel, dataset: dataset)
                        .frame(width: 260)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Bind toast notifier
            chartViewModel.onShowToast = { msg, type in
                toastManager.show(message: msg, type: type)
            }
            // Load dataset into filter pipeline and prepare initial chart
            if let dataset = dataViewModel.currentDataSet {
                filterViewModel.load(dataset: dataset)
                chartViewModel.prepareChartData(dataset: dataset, config: chartViewModel.chartConfig)
            }
        }
        .onChange(of: dataViewModel.currentDataSet?.id) { _ in
            if let dataset = dataViewModel.currentDataSet {
                filterViewModel.load(dataset: dataset)
                chartViewModel.prepareChartData(dataset: dataset, config: chartViewModel.chartConfig)
            }
        }
        .onChange(of: filterViewModel.filteredDataSet?.rowCount) { _ in
            // Re-aggregate charts whenever the filtered row count changes
            let dataset = filterViewModel.filteredDataSet ?? dataViewModel.currentDataSet
            if let ds = dataset {
                chartViewModel.prepareChartData(dataset: ds, config: chartViewModel.chartConfig)
            }
        }
        .onChange(of: chartViewModel.chartConfig.chartType) { newType in
            chartViewModel.selectedChartType = newType
            let dataset = filterViewModel.filteredDataSet ?? dataViewModel.currentDataSet
            if let ds = dataset {
                chartViewModel.prepareChartData(dataset: ds, config: chartViewModel.chartConfig)
            }
        }
    }
    
    // MARK: - Current Chart Dispatcher View

    /// A stable identity string for re-triggering enter animation on data/type change.
    private var chartAnimationId: String {
        "\(chartViewModel.chartConfig.chartType.rawValue)-\(chartViewModel.chartData.labels.count)"
    }

    @ViewBuilder
    private var currentChartView: some View {
        switch chartViewModel.chartConfig.chartType {
        case .bar:
            BarChartView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries
            )
            .chartEnterAnimation(style: .riseUp, chartId: chartAnimationId)

        case .horizontalBar:
            HorizontalBarChartView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries
            )
            .chartEnterAnimation(style: .sweepIn, chartId: chartAnimationId)

        case .line:
            LineChartView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries,
                chartViewModel: chartViewModel
            )
            .chartEnterAnimation(style: .sweepIn, chartId: chartAnimationId)

        case .area:
            AreaChartView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries,
                chartViewModel: chartViewModel
            )
            .chartEnterAnimation(style: .sweepIn, chartId: chartAnimationId)

        case .pie:
            PieChartView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries,
                chartViewModel: chartViewModel
            )
            .chartEnterAnimation(style: .scaleIn, chartId: chartAnimationId)

        case .donut:
            DonutChartView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries,
                chartViewModel: chartViewModel
            )
            .chartEnterAnimation(style: .scaleIn, chartId: chartAnimationId)

        case .scatter:
            ScatterPlotView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries,
                chartViewModel: chartViewModel
            )
            .chartEnterAnimation(style: .sweepIn, chartId: chartAnimationId)

        case .bubble:
            BubbleChartView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries,
                chartViewModel: chartViewModel
            )
            .chartEnterAnimation(style: .sweepIn, chartId: chartAnimationId)

        case .histogram:
            HistogramView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries,
                chartViewModel: chartViewModel
            )
            .chartEnterAnimation(style: .riseUp, chartId: chartAnimationId)

        case .boxPlot:
            BoxPlotView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries,
                chartViewModel: chartViewModel
            )
            .chartEnterAnimation(style: .dropIn, chartId: chartAnimationId)

        case .heatmap:
            HeatmapView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries,
                chartViewModel: chartViewModel
            )
            .chartEnterAnimation(style: .sweepIn, chartId: chartAnimationId)

        case .treemap:
            TreemapView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries,
                chartViewModel: chartViewModel
            )
            .chartEnterAnimation(style: .scaleIn, chartId: chartAnimationId)

        case .waterfall:
            WaterfallChartView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries,
                chartViewModel: chartViewModel
            )
            .chartEnterAnimation(style: .riseUp, chartId: chartAnimationId)

        case .funnel:
            FunnelChartView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries,
                chartViewModel: chartViewModel
            )
            .chartEnterAnimation(style: .riseUp, chartId: chartAnimationId)

        case .gauge:
            GaugeChartView(
                config: chartViewModel.chartConfig,
                data: chartViewModel.chartData,
                colors: chartViewModel.chartConfig.colorTheme.colors,
                highlightedSeries: highlightedSeries,
                chartViewModel: chartViewModel
            )
            .chartEnterAnimation(style: .scaleIn, chartId: chartAnimationId)

        default:
            EmptyStateView(
                iconName: chartViewModel.chartConfig.chartType.iconName,
                title: "\(chartViewModel.chartConfig.chartType.rawValue) Chart",
                subtitle: "Visualization layout is coming soon."
            )
            .chartEnterAnimation(style: .uniform, chartId: chartAnimationId)
        }
    }
}

// MARK: - Chart Selector Section Group

struct ChartTypeSection: View {
    let title: String
    let types: [ChartType]
    @Binding var selectedType: ChartType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(ColorPalette.textSecondary)
                .padding(.leading, 4)
            
            VStack(spacing: 4) {
                ForEach(types) { type in
                    Button(action: {
                        withAnimation(.easeInOut(duration: Constants.Animation.instant)) {
                            selectedType = type
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: type.iconName)
                                .font(.system(size: 12))
                                .frame(width: 16)
                            Text(type.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(selectedType == type ? .white : ColorPalette.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedType == type ? ColorPalette.accent : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Charts Toolbar Configurator

struct ChartsToolbar: View {
    @ObservedObject var chartViewModel: ChartViewModel
    @EnvironmentObject var dataViewModel: DataViewModel
    
    private var isLineOrArea: Bool {
        chartViewModel.chartConfig.chartType == .line || chartViewModel.chartConfig.chartType == .area
    }
    
    private var isPieOrDonut: Bool {
        chartViewModel.chartConfig.chartType == .pie || chartViewModel.chartConfig.chartType == .donut
    }
    
    private var isScatterOrBubble: Bool {
        chartViewModel.chartConfig.chartType == .scatter || chartViewModel.chartConfig.chartType == .bubble
    }
    
    var body: some View {
        let columns = dataViewModel.currentDataSet?.visibleColumns ?? []
        
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Chart Title Input
                ToolbarField(label: "Chart Title") {
                    TextField("Untitled Chart", text: $chartViewModel.chartConfig.title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ColorPalette.cards)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorPalette.border, lineWidth: 1))
                        .frame(width: 150)
                }
                
                ToolbarDivider()
                
                // X-Axis Selector
                ToolbarField(label: chartViewModel.chartConfig.chartType == .histogram ? "Value Column" : "X-Axis") {
                    Picker("", selection: $chartViewModel.chartConfig.xAxisColumn) {
                        Text("Select Column").tag(String?.none)
                        ForEach(columns) { col in
                            Text(col.name).tag(String?.some(col.name))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 130)
                }
                
                // Y-Axis Selector (Not needed for Histogram)
                if chartViewModel.chartConfig.chartType != .histogram {
                    ToolbarField(label: "Y-Axis") {
                        Picker("", selection: $chartViewModel.chartConfig.yAxisColumn) {
                            Text("Select Column").tag(String?.none)
                            ForEach(columns) { col in
                                Text(col.name).tag(String?.some(col.name))
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 130)
                    }
                }
                
                // Color Theme Picker
                ToolbarField(label: "Theme") {
                    Picker("", selection: $chartViewModel.chartConfig.colorTheme) {
                        ForEach(ColorTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 110)
                }
                
                ToolbarDivider()
                
                // ── Line / Area only controls ──────────────────────────
                if isLineOrArea {
                    // Interpolation mode toggle
                    ToolbarField(label: "Line Style") {
                        Picker("", selection: $chartViewModel.chartConfig.interpolationMode) {
                            ForEach(LineInterpolation.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 130)
                    }
                    
                    // Series grouping column (multi-series breakdown)
                    ToolbarField(label: "Group By") {
                        Picker("", selection: $chartViewModel.chartConfig.seriesColumn) {
                            Text("None").tag(String?.none)
                            ForEach(columns) { col in
                                Text(col.name).tag(String?.some(col.name))
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    
                    // Reference lines toggle
                    ToolbarField(label: "Ref. Lines") {
                        Toggle("", isOn: $chartViewModel.chartConfig.showReferenceLines)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                }
                
                // ── Area-only controls ─────────────────────────────────
                if chartViewModel.chartConfig.chartType == .area {
                    ToolbarDivider()
                    
                    ToolbarField(label: "Stack Mode") {
                        Picker("", selection: $chartViewModel.chartConfig.stackMode) {
                            ForEach(AreaStackMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    
                    ToolbarField(label: "Baseline") {
                        Picker("", selection: $chartViewModel.chartConfig.baselineMode) {
                            ForEach(AreaBaseline.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 130)
                    }
                }
                
                // ── Pie / Donut only controls ──────────────────────────
                if isPieOrDonut {
                    ToolbarField(label: "Sort Slices") {
                        Picker("", selection: $chartViewModel.chartConfig.sliceSortOrder) {
                            ForEach(SliceSortOrder.allCases) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 140)
                    }
                    
                    ToolbarField(label: "Max Slices") {
                        Picker("", selection: $chartViewModel.chartConfig.maxSlices) {
                            ForEach([5, 8, 12, 16, 20, 24], id: \.self) { num in
                                Text("\(num)").tag(num)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 60)
                    }
                    
                    ToolbarField(label: "Group Small (<2%)") {
                        Toggle("", isOn: $chartViewModel.chartConfig.groupSmallSlices)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                    
                    ToolbarField(label: "Explode All") {
                        Toggle("", isOn: $chartViewModel.chartConfig.explodeAll)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                    
                    ToolbarField(label: "Semi-Circle") {
                        Toggle("", isOn: $chartViewModel.chartConfig.semiCircleMode)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                    
                    ToolbarDivider()
                    
                    ToolbarField(label: "Compare With") {
                        Picker("", selection: $chartViewModel.chartConfig.comparisonColumn) {
                            Text("None").tag(String?.none)
                            ForEach(columns) { col in
                                Text(col.name).tag(String?.some(col.name))
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 120)
                    }
                }
                
                // ── Donut-only center text config ──────────────────────
                if chartViewModel.chartConfig.chartType == .donut {
                    ToolbarDivider()
                    
                    ToolbarField(label: "Hole Center Text") {
                        Picker("", selection: $chartViewModel.chartConfig.donutCenterText) {
                            ForEach(DonutCenterContent.allCases) { opt in
                                Text(opt.rawValue).tag(opt)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 120)
                    }
                }
                
                // ── Scatter & Bubble specific controls ─────────────────
                if isScatterOrBubble {
                    // Category coloring
                    ToolbarField(label: "Color By Category") {
                        Picker("", selection: $chartViewModel.chartConfig.seriesColumn) {
                            Text("None").tag(String?.none)
                            ForEach(columns) { col in
                                Text(col.name).tag(String?.some(col.name))
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    
                    // Trendline selector
                    ToolbarField(label: "Trend Line") {
                        Picker("", selection: $chartViewModel.chartConfig.trendLineType) {
                            ForEach(TrendLineType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 140)
                    }
                    
                    // Show Quadrant toggles
                    ToolbarField(label: "Quadrants") {
                        Toggle("", isOn: $chartViewModel.chartConfig.showQuadrantLines)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                    
                    // Zero Origin toggle
                    ToolbarField(label: "Zero Origin") {
                        Toggle("", isOn: $chartViewModel.chartConfig.zeroOrigin)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                }
                
                // ── Bubble Chart specific dimensions ────────────────────
                if chartViewModel.chartConfig.chartType == .bubble {
                    ToolbarDivider()
                    
                    ToolbarField(label: "Bubble Size (3D)") {
                        Picker("", selection: $chartViewModel.chartConfig.bubbleSizeColumn) {
                            Text("Select Size Column").tag(String?.none)
                            ForEach(columns) { col in
                                Text(col.name).tag(String?.some(col.name))
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 130)
                    }
                    
                    ToolbarField(label: "Bubble Color (4D)") {
                        Picker("", selection: $chartViewModel.chartConfig.bubbleColorColumn) {
                            Text("None").tag(String?.none)
                            ForEach(columns) { col in
                                Text(col.name).tag(String?.some(col.name))
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 120)
                    }
                }
                
                // ── Histogram specific settings ─────────────────────────
                if chartViewModel.chartConfig.chartType == .histogram {
                    // Bin selector count slider
                    ToolbarField(label: "Bins count (\(chartViewModel.chartConfig.histogramBinCount))") {
                        Slider(value: Binding(get: {
                            Double(chartViewModel.chartConfig.histogramBinCount)
                        }, set: {
                            chartViewModel.chartConfig.histogramBinCount = Int($0)
                            chartViewModel.chartConfig.useAutoBin = false
                        }), in: 5...50, step: 1)
                        .frame(width: 100)
                    }
                    
                    // Sturges Auto-bin rule checkbox
                    ToolbarField(label: "Sturges Rule") {
                        Toggle("", isOn: $chartViewModel.chartConfig.useAutoBin)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                    
                    // Density percentage vs Frequency count toggle
                    ToolbarField(label: "Metric Type") {
                        Picker("", selection: $chartViewModel.chartConfig.histogramType) {
                            ForEach(HistogramType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 130)
                    }
                    
                    // Show Bell curve
                    ToolbarField(label: "Normal Curve") {
                        Toggle("", isOn: $chartViewModel.chartConfig.showNormalCurve)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                    
                    // Outlier highlight red bins
                    ToolbarField(label: "Outliers Warning") {
                        Toggle("", isOn: $chartViewModel.chartConfig.showOutlierHighlight)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                    
                    // Cumulative sum histograms
                    ToolbarField(label: "Cumulative") {
                        Toggle("", isOn: $chartViewModel.chartConfig.cumulativeHistogram)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                }
                
                // ── Box Plot specific settings ──────────────────────────
                if chartViewModel.chartConfig.chartType == .boxPlot {
                    // Box sorting orders
                    ToolbarField(label: "Sort Boxes By") {
                        Picker("", selection: $chartViewModel.chartConfig.boxSortOrder) {
                            ForEach(BoxSortOrder.allCases) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 130)
                    }
                    
                    // Box orientation layout
                    ToolbarField(label: "Layout") {
                        Picker("", selection: $chartViewModel.chartConfig.boxPlotOrientation) {
                            ForEach(BoxPlotOrientation.allCases) { orient in
                                Text(orient.rawValue).tag(orient)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 110)
                    }
                    
                    // Box notched confidence overlay
                    ToolbarField(label: "Notched Medians") {
                        Toggle("", isOn: $chartViewModel.chartConfig.boxPlotNotched)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                }
                
                // ── Heatmap specific settings ───────────────────────────
                if chartViewModel.chartConfig.chartType == .heatmap {
                    ToolbarField(label: "Color Scale") {
                        Picker("", selection: $chartViewModel.chartConfig.heatmapColorScale) {
                            ForEach(HeatmapColorScale.allCases) { scale in
                                Text(scale.rawValue).tag(scale)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 100)
                    }
                    ToolbarField(label: "Labels") {
                        Toggle("", isOn: $chartViewModel.chartConfig.showCellLabels)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                    ToolbarField(label: "Cluster") {
                        Toggle("", isOn: $chartViewModel.chartConfig.clusterHeatmap)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                }
                
                // ── Treemap specific settings ───────────────────────────
                if chartViewModel.chartConfig.chartType == .treemap {
                    ToolbarField(label: "Depth") {
                        Picker("", selection: $chartViewModel.chartConfig.treemapDepth) {
                            Text("1 - Flat").tag(1)
                            Text("2 - Nested").tag(2)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 90)
                    }
                }
                
                // ── Waterfall specific settings ──────────────────────────
                if chartViewModel.chartConfig.chartType == .waterfall {
                    ToolbarField(label: "Connectors") {
                        Toggle("", isOn: $chartViewModel.chartConfig.showWaterfallConnectors)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                    ToolbarField(label: "Running Total") {
                        Toggle("", isOn: $chartViewModel.chartConfig.showRunningTotalLine)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                    ToolbarField(label: "Total Bar") {
                        Toggle("", isOn: $chartViewModel.chartConfig.showTotalBar)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                }
                
                // ── Funnel specific settings ─────────────────────────────
                if chartViewModel.chartConfig.chartType == .funnel {
                    ToolbarField(label: "Style") {
                        Picker("", selection: $chartViewModel.chartConfig.funnelStyle) {
                            ForEach(FunnelStyle.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 90)
                    }
                    ToolbarField(label: "Labels Inside") {
                        Toggle("", isOn: $chartViewModel.chartConfig.showDataLabels)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                }
                
                // ── Gauge specific settings ──────────────────────────────
                if chartViewModel.chartConfig.chartType == .gauge {
                    ToolbarField(label: "Style") {
                        Picker("", selection: $chartViewModel.chartConfig.gaugeStyle) {
                            ForEach(GaugeStyle.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 100)
                    }
                    
                    ToolbarField(label: "Unit") {
                        TextField("%", text: $chartViewModel.chartConfig.gaugeUnit)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 40)
                    }
                    
                    ToolbarField(label: "Min") {
                        TextField("0", value: $chartViewModel.chartConfig.gaugeMinValue, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 40)
                    }
                    
                    ToolbarField(label: "Max") {
                        TextField("100", value: $chartViewModel.chartConfig.gaugeMaxValue, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 45)
                    }
                }
                
                // ── Ignored Null value warning indicator ───────────────
                if chartViewModel.ignoredNullCount > 0 {
                    ToolbarDivider()
                    
                    VStack(alignment: .center, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color(hex: "#EF4444"))
                                .font(.system(size: 10))
                            Text("\(chartViewModel.ignoredNullCount) Nulls")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(ColorPalette.textPrimary)
                        }
                        Text("Ignored")
                            .font(.system(size: 8))
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    .padding(.horizontal, 8)
                }
                
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 4)
        }
        // Trigger re-aggregation on any axis / config change
        .onChange(of: chartViewModel.chartConfig.xAxisColumn) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.yAxisColumn) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.seriesColumn) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.colorTheme)  { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.stackMode)   { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.sliceSortOrder) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.maxSlices)   { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.groupSmallSlices) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.semiCircleMode) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.comparisonColumn) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.trendLineType) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.showTrendLine) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.bubbleSizeColumn) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.bubbleColorColumn) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.histogramBinCount) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.useAutoBin) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.histogramType) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.boxSortOrder) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.boxPlotOrientation) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.boxPlotNotched) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.showQuadrantLines) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.zeroOrigin) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.heatmapColorScale) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.showCellLabels) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.clusterHeatmap) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.treemapDepth) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.showWaterfallConnectors) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.showRunningTotalLine) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.showTotalBar) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.funnelStyle) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.showDataLabels) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.gaugeStyle) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.gaugeMinValue) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.gaugeMaxValue) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.gaugeTargetValue) { _ in recompute() }
        .onChange(of: chartViewModel.chartConfig.gaugeUnit) { _ in recompute() }
    }
    
    private func recompute() {
        if let dataset = dataViewModel.currentDataSet {
            chartViewModel.prepareChartData(dataset: dataset, config: chartViewModel.chartConfig)
        }
    }
}

// MARK: - Toolbar Field Helper

/// Small labelled column used inside ChartsToolbar.
private struct ToolbarField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(ColorPalette.textSecondary)
            content()
        }
    }
}

/// Thin vertical separator between toolbar groups.
private struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(ColorPalette.border)
            .frame(width: 1, height: 36)
            .opacity(0.6)
    }
}
