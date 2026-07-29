import SwiftUI

// MARK: - ExportView

/// Full-screen Export Hub showing all available export options,
/// recent exports history, and format configuration.
struct ExportView: View {

    @EnvironmentObject var dataViewModel: DataViewModel
    @StateObject private var exportViewModel = ExportViewModel()

    @State private var selectedDataset: DataSet?
    @State private var showProgressOverlay: Bool = false
    @State private var hoveredFormat: ExportFormatTab? = nil
    @State private var appearAnimation: Bool = false

    var body: some View {
        ZStack {
            ColorPalette.background.ignoresSafeArea()

            HStack(spacing: 0) {
                // Left: dataset picker + recent exports
                leftSidebar

                // Divider
                Rectangle().fill(ColorPalette.border).frame(width: 1)

                // Right: format cards + quick actions
                mainContent
            }

            // Progress overlay
            if showProgressOverlay {
                ExportProgressView(exportViewModel: exportViewModel) {
                    showProgressOverlay = false
                    exportViewModel.dismissResult()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .onChange(of: exportViewModel.isExporting) { active in
            withAnimation { showProgressOverlay = active }
        }
        .onAppear {
            selectedDataset = dataViewModel.datasets.first
            withAnimation(.easeOut(duration: 0.5)) { appearAnimation = true }
        }
    }

    // MARK: - Left Sidebar

    private var leftSidebar: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Export Hub")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ColorPalette.textPrimary)
                Text("Choose a dataset and export format")
                    .font(.system(size: 11))
                    .foregroundColor(ColorPalette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            Divider().background(ColorPalette.border)

            // Dataset Picker
            VStack(alignment: .leading, spacing: 10) {
                Text("DATASET")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.textSecondary)

                if dataViewModel.datasets.isEmpty {
                    emptyDatasetPrompt
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(dataViewModel.datasets) { ds in
                                datasetRow(ds)
                            }
                        }
                    }
                }
            }
            .padding(16)

            Divider().background(ColorPalette.border)

            // Recent Exports
            VStack(alignment: .leading, spacing: 10) {
                Text("RECENT EXPORTS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.textSecondary)

                if exportViewModel.recentExports.isEmpty {
                    Text("No exports yet")
                        .font(.system(size: 11))
                        .foregroundColor(ColorPalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 10)
                } else {
                    ForEach(exportViewModel.recentExports) { item in
                        recentExportRow(item)
                    }
                }
            }
            .padding(16)

            Spacer()
        }
        .frame(width: 260)
        .background(ColorPalette.sidebar)
        .opacity(appearAnimation ? 1 : 0)
        .offset(x: appearAnimation ? 0 : -20)
    }

    // MARK: - Main Content (Format Cards)

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Choose Export Format")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ColorPalette.textPrimary)

                // Format cards grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(ExportFormatTab.allCases) { fmt in
                        formatCard(fmt)
                    }
                }

                // Config section
                if let ds = selectedDataset {
                    Divider().background(ColorPalette.border)
                    configSection(dataset: ds)
                }
            }
            .padding(24)
        }
        .background(ColorPalette.background)
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
    }

    // MARK: - Format Card

    @ViewBuilder
    private func formatCard(_ fmt: ExportFormatTab) -> some View {
        let isHovered = hoveredFormat == fmt
        Button(action: { triggerExport(format: fmt) }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: fmt.icon)
                        .font(.system(size: 22))
                        .foregroundColor(isHovered ? .white : ColorPalette.accent)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundColor(isHovered ? .white.opacity(0.7) : ColorPalette.textSecondary.opacity(0))
                }

                Text(formatTitle(fmt))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isHovered ? .white : ColorPalette.textPrimary)

                Text(formatDescription(fmt))
                    .font(.system(size: 10))
                    .foregroundColor(isHovered ? .white.opacity(0.75) : ColorPalette.textSecondary)
                    .lineLimit(2)

                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(isHovered ? ColorPalette.accent : ColorPalette.cards)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? ColorPalette.accent : ColorPalette.border, lineWidth: 1)
            )
            .shadow(color: isHovered ? ColorPalette.accent.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hoveredFormat = $0 ? fmt : nil }
        .disabled(selectedDataset == nil)
    }

    // MARK: - Config Section

    @ViewBuilder
    private func configSection(dataset: DataSet) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Quick Configuration")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ColorPalette.textPrimary)
                Spacer()
                Text(dataset.name)
                    .font(.system(size: 11))
                    .foregroundColor(ColorPalette.textSecondary)
            }

            HStack(alignment: .top, spacing: 20) {
                // CSV quick options
                VStack(alignment: .leading, spacing: 8) {
                    Text("CSV")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorPalette.textSecondary)
                    Picker("Delimiter", selection: $exportViewModel.csvConfig.delimiter) {
                        ForEach(CSVDelimiter.allCases) { d in Text(d.label).tag(d) }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                    Toggle("Headers", isOn: $exportViewModel.csvConfig.includeHeaders)
                        .font(.system(size: 11)).foregroundColor(ColorPalette.textPrimary).toggleStyle(.checkbox)
                }

                Divider().background(ColorPalette.border)

                // Image quick options
                VStack(alignment: .leading, spacing: 8) {
                    Text("IMAGE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorPalette.textSecondary)
                    Picker("Format", selection: $exportViewModel.imageConfig.format) {
                        ForEach(ImageFormat.allCases) { f in Text(f.rawValue).tag(f) }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    Toggle("Dark BG", isOn: $exportViewModel.imageConfig.useDarkBackground)
                        .font(.system(size: 11)).foregroundColor(ColorPalette.textPrimary).toggleStyle(.checkbox)
                }

                Divider().background(ColorPalette.border)

                // PDF quick options
                VStack(alignment: .leading, spacing: 8) {
                    Text("PDF")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorPalette.textSecondary)
                    Picker("Page Size", selection: $exportViewModel.pdfConfig.pageSize) {
                        ForEach(PDFPageSize.allCases) { s in Text(s.rawValue).tag(s) }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    Toggle("Page Numbers", isOn: $exportViewModel.pdfConfig.includePageNumbers)
                        .font(.system(size: 11)).foregroundColor(ColorPalette.textPrimary).toggleStyle(.checkbox)
                }
            }
            .padding(16)
            .background(ColorPalette.cards)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(ColorPalette.border, lineWidth: 1))
        }
    }

    // MARK: - Dataset Row

    @ViewBuilder
    private func datasetRow(_ ds: DataSet) -> some View {
        let selected = selectedDataset?.id == ds.id
        Button(action: { selectedDataset = ds }) {
            HStack(spacing: 10) {
                Image(systemName: "cylinder.split.1x2.fill")
                    .foregroundColor(selected ? ColorPalette.accent : ColorPalette.textSecondary)
                    .font(.system(size: 13))
                VStack(alignment: .leading, spacing: 1) {
                    Text(ds.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ColorPalette.textPrimary)
                    Text("\(ds.rowCount) rows")
                        .font(.system(size: 10))
                        .foregroundColor(ColorPalette.textSecondary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ColorPalette.accent)
                        .font(.system(size: 12))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(selected ? ColorPalette.accent.opacity(0.12) : Color.clear)
            .cornerRadius(7)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(selected ? ColorPalette.accent.opacity(0.4) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent Export Row

    @ViewBuilder
    private func recentExportRow(_ item: RecentExportItem) -> some View {
        Button(action: { exportViewModel.openFile(url: item.fileURL) }) {
            HStack(spacing: 10) {
                Image(systemName: formatIcon(item.format))
                    .foregroundColor(ColorPalette.success)
                    .font(.system(size: 13))
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.filename)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ColorPalette.textPrimary)
                        .lineLimit(1)
                    Text("\(item.fileSizeLabel)  ·  \(item.exportedAt, style: .time)")
                        .font(.system(size: 9))
                        .foregroundColor(ColorPalette.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(ColorPalette.textSecondary)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty Placeholder

    private var emptyDatasetPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "cylinder.split.1x2")
                .font(.system(size: 24))
                .foregroundColor(ColorPalette.textSecondary.opacity(0.4))
            Text("No datasets loaded")
                .font(.system(size: 11))
                .foregroundColor(ColorPalette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Trigger Export

    private func triggerExport(format: ExportFormatTab) {
        guard let ds = selectedDataset else { return }
        switch format {
        case .csv:
            exportViewModel.exportCSV(dataset: ds)
        case .image:
            exportViewModel.exportDashboardImage(dashboard: DashboardLayout(name: ds.name))
        case .pdf:
            exportViewModel.exportDataReport(dataset: ds, charts: [])
        case .report:
            exportViewModel.exportDataReport(dataset: ds, charts: [], aiInsightsText: nil)
        }
    }

    // MARK: - Helpers

    private func formatTitle(_ fmt: ExportFormatTab) -> String {
        switch fmt {
        case .csv:    return "CSV / TSV File"
        case .image:  return "PNG / JPEG Image"
        case .pdf:    return "Single Chart PDF"
        case .report: return "Executive Report"
        }
    }

    private func formatDescription(_ fmt: ExportFormatTab) -> String {
        switch fmt {
        case .csv:    return "Export raw dataset or filtered rows with configurable delimiter"
        case .image:  return "High-resolution chart image with transparency support"
        case .pdf:    return "Print-ready single-page PDF of current chart"
        case .report: return "Full multi-page PDF with cover page, AI insights, and data tables"
        }
    }

    private func formatIcon(_ fmt: String) -> String {
        switch fmt.uppercased() {
        case "CSV":    return "tablecells"
        case "PNG", "JPEG", "JPG", "WEBP": return "photo"
        case "PDF", "PDF REPORT": return "doc.richtext"
        default: return "arrow.up.right.square"
        }
    }
}
