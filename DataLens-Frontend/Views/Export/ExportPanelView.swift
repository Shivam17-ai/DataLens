import SwiftUI

// MARK: - Export Format Tabs

enum ExportFormatTab: String, CaseIterable, Identifiable {
    case csv    = "CSV"
    case image  = "Image"
    case pdf    = "PDF"
    case report = "Report"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .csv:    return "tablecells"
        case .image:  return "photo"
        case .pdf:    return "doc.richtext"
        case .report: return "doc.plaintext.fill"
        }
    }
}

// MARK: - ExportPanelView

/// Context-sensitive 360pt slide-in quick-export panel.
/// Triggered from any share icon in the Charts, Dashboard, or Data toolbar.
struct ExportPanelView: View {

    @ObservedObject var exportViewModel: ExportViewModel

    var dataset: DataSet?
    var filteredRows: [Row]?
    var dashboardLayout: DashboardLayout?
    var chartTitle: String = ""

    var onDismiss: () -> Void

    @State private var selectedTab: ExportFormatTab = .csv
    @State private var showProgress: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider().background(ColorPalette.border)
            formatTabs
            Divider().background(ColorPalette.border)
            ScrollView { optionsBody.padding(16) }
            Divider().background(ColorPalette.border)
            actionBar
        }
        .frame(width: 360)
        .background(ColorPalette.sidebar)
        .overlay(
            ExportProgressView(exportViewModel: exportViewModel, onDismiss: {
                showProgress = false
                exportViewModel.dismissResult()
            })
            .opacity(showProgress ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: showProgress)
        )
        .onChange(of: exportViewModel.isExporting) { active in
            if active { showProgress = true }
        }
        .onChange(of: exportViewModel.exportStatus) { status in
            switch status {
            case .idle:
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { showProgress = false }
            default: break
            }
        }
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack {
            Image(systemName: "square.and.arrow.up.circle.fill")
                .foregroundColor(ColorPalette.accent)
                .font(.system(size: 16))
            Text("Export")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(ColorPalette.textPrimary)

            if let ds = dataset {
                Text("·")
                    .foregroundColor(ColorPalette.border)
                Text(ds.name)
                    .font(.system(size: 11))
                    .foregroundColor(ColorPalette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(ColorPalette.textSecondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(ColorPalette.sidebar)
    }

    // MARK: - Format Tabs

    private var formatTabs: some View {
        HStack(spacing: 4) {
            ForEach(ExportFormatTab.allCases) { tab in
                Button(action: { selectedTab = tab }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon).font(.system(size: 11))
                        Text(tab.rawValue).font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(selectedTab == tab ? .white : ColorPalette.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(selectedTab == tab ? ColorPalette.accent : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ColorPalette.background.opacity(0.4))
    }

    // MARK: - Options Body (dynamic by tab)

    @ViewBuilder
    private var optionsBody: some View {
        switch selectedTab {
        case .csv:    csvOptions
        case .image:  imageOptions
        case .pdf:    pdfOptions
        case .report: reportOptions
        }
    }

    // MARK: CSV Options

    private var csvOptions: some View {
        VStack(alignment: .leading, spacing: 14) {
            optionLabel("EXPORT SCOPE")
            Picker("", selection: $exportViewModel.csvConfig.exportScope) {
                ForEach(ExportScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.radioGroup)

            Divider().background(ColorPalette.border)

            optionLabel("DELIMITER")
            Picker("", selection: $exportViewModel.csvConfig.delimiter) {
                ForEach(CSVDelimiter.allCases) { d in
                    Text(d.label).tag(d)
                }
            }
            .pickerStyle(.menu)

            Divider().background(ColorPalette.border)

            Toggle("Include Column Headers", isOn: $exportViewModel.csvConfig.includeHeaders)
                .font(.system(size: 12))
                .foregroundColor(ColorPalette.textPrimary)
                .toggleStyle(.checkbox)

            Toggle("Include Row Numbers", isOn: $exportViewModel.csvConfig.includeRowNumbers)
                .font(.system(size: 12))
                .foregroundColor(ColorPalette.textPrimary)
                .toggleStyle(.checkbox)

            Divider().background(ColorPalette.border)

            if let ds = dataset {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(ColorPalette.textSecondary)
                        .font(.system(size: 11))
                    let rowCount = (filteredRows?.count ?? ds.rowCount)
                    Text("Will export \(rowCount) rows, \(ds.visibleColumns.count) columns")
                        .font(.system(size: 10))
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }
        }
    }

    // MARK: Image Options

    private var imageOptions: some View {
        VStack(alignment: .leading, spacing: 14) {
            optionLabel("FORMAT")
            HStack(spacing: 6) {
                ForEach(ImageFormat.allCases.filter { $0 != .webp }) { fmt in
                    Button(action: { exportViewModel.imageConfig.format = fmt }) {
                        Text(fmt.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(exportViewModel.imageConfig.format == fmt ? .white : ColorPalette.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(exportViewModel.imageConfig.format == fmt ? ColorPalette.accent : ColorPalette.background.opacity(0.4))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().background(ColorPalette.border)

            optionLabel("RESOLUTION")
            HStack(spacing: 6) {
                ForEach([1.0, 2.0, 3.0], id: \.self) { scale in
                    Button(action: { exportViewModel.imageConfig.scale = scale }) {
                        Text("\(Int(scale))x")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(exportViewModel.imageConfig.scale == scale ? .white : ColorPalette.textSecondary)
                            .frame(width: 36)
                            .padding(.vertical, 5)
                            .background(exportViewModel.imageConfig.scale == scale ? ColorPalette.accent : ColorPalette.background.opacity(0.4))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().background(ColorPalette.border)

            Toggle("Dark Background", isOn: $exportViewModel.imageConfig.useDarkBackground)
                .font(.system(size: 12)).foregroundColor(ColorPalette.textPrimary).toggleStyle(.checkbox)
            Toggle("Include Watermark", isOn: $exportViewModel.imageConfig.includeWatermark)
                .font(.system(size: 12)).foregroundColor(ColorPalette.textPrimary).toggleStyle(.checkbox)

            if exportViewModel.imageConfig.format == .jpg {
                Divider().background(ColorPalette.border)
                optionLabel("JPEG QUALITY")
                Slider(value: $exportViewModel.imageConfig.compressionQuality, in: 0.1...1.0, step: 0.1)
                    .tint(ColorPalette.accent)
                Text("Quality: \(Int(exportViewModel.imageConfig.compressionQuality * 100))%")
                    .font(.system(size: 10)).foregroundColor(ColorPalette.textSecondary)
            }

            Divider().background(ColorPalette.border)
            HStack {
                Image(systemName: "info.circle").foregroundColor(ColorPalette.textSecondary).font(.system(size: 11))
                let dims = "~\(Int(800 * exportViewModel.imageConfig.scale)) × \(Int(500 * exportViewModel.imageConfig.scale)) px"
                Text("Estimated output: \(dims)").font(.system(size: 10)).foregroundColor(ColorPalette.textSecondary)
            }
        }
    }

    // MARK: PDF Options

    private var pdfOptions: some View {
        VStack(alignment: .leading, spacing: 14) {
            optionLabel("PAGE SIZE")
            Picker("", selection: $exportViewModel.pdfConfig.pageSize) {
                ForEach(PDFPageSize.allCases) { sz in Text(sz.rawValue).tag(sz) }
            }
            .pickerStyle(.menu)

            optionLabel("ORIENTATION")
            Picker("", selection: $exportViewModel.pdfConfig.orientation) {
                ForEach(PDFOrientation.allCases) { o in Text(o.rawValue).tag(o) }
            }
            .pickerStyle(.segmented)

            Divider().background(ColorPalette.border)

            optionLabel("QUALITY")
            Picker("", selection: $exportViewModel.pdfConfig.quality) {
                ForEach(PDFQuality.allCases) { q in Text(q.rawValue).tag(q) }
            }
            .pickerStyle(.menu)

            Divider().background(ColorPalette.border)

            Toggle("Include Header", isOn: $exportViewModel.pdfConfig.includeHeader)
                .font(.system(size: 12)).foregroundColor(ColorPalette.textPrimary).toggleStyle(.checkbox)
            Toggle("Include Footer", isOn: $exportViewModel.pdfConfig.includeFooter)
                .font(.system(size: 12)).foregroundColor(ColorPalette.textPrimary).toggleStyle(.checkbox)
            Toggle("Page Numbers", isOn: $exportViewModel.pdfConfig.includePageNumbers)
                .font(.system(size: 12)).foregroundColor(ColorPalette.textPrimary).toggleStyle(.checkbox)
            Toggle("Include Timestamp", isOn: $exportViewModel.pdfConfig.includeTimestamp)
                .font(.system(size: 12)).foregroundColor(ColorPalette.textPrimary).toggleStyle(.checkbox)
        }
    }

    // MARK: Report Options

    private var reportOptions: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text.below.ecg.fill")
                    .font(.system(size: 24))
                    .foregroundColor(ColorPalette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Executive PDF Report")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(ColorPalette.textPrimary)
                    Text("Multi-page professional report with cover page, AI insights, dataset overview, and sample data table.")
                        .font(.system(size: 10))
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }
            .padding(12)
            .background(ColorPalette.accent.opacity(0.08))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ColorPalette.accent.opacity(0.3), lineWidth: 1))

            Divider().background(ColorPalette.border)
            Toggle("Include Page Numbers", isOn: $exportViewModel.pdfConfig.includePageNumbers)
                .font(.system(size: 12)).foregroundColor(ColorPalette.textPrimary).toggleStyle(.checkbox)
            Toggle("Include Timestamp", isOn: $exportViewModel.pdfConfig.includeTimestamp)
                .font(.system(size: 12)).foregroundColor(ColorPalette.textPrimary).toggleStyle(.checkbox)
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("Cancel", action: onDismiss)
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ColorPalette.textSecondary)

            Spacer()

            exportButton
        }
        .padding(14)
        .background(ColorPalette.sidebar)
    }

    @ViewBuilder
    private var exportButton: some View {
        Button(action: triggerExport) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .bold))
                Text("Export \(selectedTab.rawValue)")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(ColorPalette.accent)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(dataset == nil && dashboardLayout == nil)
    }

    // MARK: - Trigger Logic

    private func triggerExport() {
        guard let ds = dataset else { return }
        switch selectedTab {
        case .csv:
            exportViewModel.exportCSV(dataset: ds, filteredRows: filteredRows)
        case .image:
            exportViewModel.exportDashboardImage(dashboard: dashboardLayout ?? DashboardLayout(name: chartTitle))
        case .pdf:
            break // would need a rendered view — handled from chart screen
        case .report:
            exportViewModel.exportDataReport(dataset: ds, charts: [])
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func optionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(ColorPalette.textSecondary)
    }
}
