import SwiftUI
import Combine
import AppKit

// MARK: - Export Status

enum ExportStatus: Equatable {
    case idle
    case preparing
    case rendering
    case generating
    case saving
    case success(URL)
    case error(String)

    var label: String {
        switch self {
        case .idle:        return "Ready"
        case .preparing:   return "Preparing data..."
        case .rendering:   return "Rendering charts..."
        case .generating:  return "Generating file..."
        case .saving:      return "Saving to disk..."
        case .success:     return "Export complete!"
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var isActive: Bool {
        switch self {
        case .idle, .success, .error: return false
        default: return true
        }
    }
}

// MARK: - Recent Export Item

struct RecentExportItem: Identifiable, Codable, Equatable {
    let id: UUID
    let filename: String
    let format: String
    let exportedAt: Date
    let fileSizeBytes: Int
    let fileURL: URL

    var fileSizeLabel: String {
        if fileSizeBytes < 1024 {
            return "\(fileSizeBytes) B"
        } else if fileSizeBytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(fileSizeBytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(fileSizeBytes) / (1024.0 * 1024.0))
        }
    }
}

// MARK: - ExportViewModel

@MainActor
final class ExportViewModel: ObservableObject {

    // MARK: Published State

    @Published var isExporting: Bool          = false
    @Published var exportProgress: Double     = 0.0
    @Published var currentStepMessage: String = ""
    @Published var exportStatus: ExportStatus = .idle
    @Published var recentExports: [RecentExportItem] = []

    // CSV Config
    @Published var csvConfig: CSVConfig = CSVConfig()

    // Image Config
    @Published var imageConfig: ImageConfig = ImageConfig()

    // PDF Config
    @Published var pdfConfig: PDFConfig = PDFConfig()

    // MARK: Private

    private var activeTask: Task<Void, Never>?
    private let recentExportsKey = "datalens_recent_exports"

    init() {
        loadRecentExports()
    }

    // MARK: - CSV Export

    func exportCSV(
        dataset: DataSet,
        filteredRows: [Row]? = nil
    ) {
        cancelExport()
        activeTask = Task {
            exportStatus = .preparing
            isExporting  = true
            exportProgress = 0.0

            do {
                let url: URL
                if let rows = filteredRows, csvConfig.exportScope == .filteredData {
                    url = try await CSVExporter.shared.exportFilteredData(
                        dataset: dataset,
                        filteredRows: rows,
                        config: csvConfig,
                        onProgress: { [weak self] p, msg in
                            Task { @MainActor in
                                self?.exportProgress = p
                                self?.currentStepMessage = msg
                            }
                        }
                    )
                } else {
                    url = try await CSVExporter.shared.exportDataSet(
                        dataset: dataset,
                        config: csvConfig,
                        onProgress: { [weak self] p, msg in
                            Task { @MainActor in
                                self?.exportProgress = p
                                self?.currentStepMessage = msg
                            }
                        }
                    )
                }

                await handleSuccess(url: url, format: "CSV")
            } catch {
                await handleError(error.localizedDescription)
            }
        }
    }

    func exportCSVChartData(chartData: ChartData, chartTitle: String) {
        cancelExport()
        activeTask = Task {
            exportStatus = .preparing
            isExporting  = true
            exportProgress = 0.0

            do {
                let url = try await CSVExporter.shared.exportChartData(
                    chartData: chartData,
                    chartTitle: chartTitle,
                    config: csvConfig,
                    onProgress: { [weak self] p, msg in
                        Task { @MainActor in
                            self?.exportProgress = p
                            self?.currentStepMessage = msg
                        }
                    }
                )
                await handleSuccess(url: url, format: "CSV")
            } catch {
                await handleError(error.localizedDescription)
            }
        }
    }

    // MARK: - Image Export

    func exportImage<Content: View>(
        view: Content,
        title: String
    ) {
        cancelExport()
        activeTask = Task {
            exportStatus   = .rendering
            isExporting    = true
            exportProgress = 0.0

            do {
                let url = try await ImageExporter.shared.exportChart(
                    view: view,
                    title: title,
                    config: imageConfig,
                    onProgress: { [weak self] p, msg in
                        Task { @MainActor in
                            self?.exportProgress = p
                            self?.currentStepMessage = msg
                        }
                    }
                )
                await handleSuccess(url: url, format: imageConfig.format.rawValue)
            } catch {
                await handleError(error.localizedDescription)
            }
        }
    }

    func exportDashboardImage(dashboard: DashboardLayout) {
        cancelExport()
        activeTask = Task {
            exportStatus   = .rendering
            isExporting    = true
            exportProgress = 0.0

            do {
                let url = try await ImageExporter.shared.exportDashboard(
                    dashboard: dashboard,
                    config: imageConfig,
                    onProgress: { [weak self] p, msg in
                        Task { @MainActor in
                            self?.exportProgress = p
                            self?.currentStepMessage = msg
                        }
                    }
                )
                await handleSuccess(url: url, format: imageConfig.format.rawValue)
            } catch {
                await handleError(error.localizedDescription)
            }
        }
    }

    // MARK: - PDF Export

    func exportPDF<Content: View>(view: Content, title: String) {
        cancelExport()
        activeTask = Task {
            exportStatus   = .generating
            isExporting    = true
            exportProgress = 0.0

            do {
                let url = try await PDFExporter.shared.exportChart(
                    view: view,
                    title: title,
                    config: pdfConfig,
                    onProgress: { [weak self] p, msg in
                        Task { @MainActor in
                            self?.exportProgress = p
                            self?.currentStepMessage = msg
                        }
                    }
                )
                await handleSuccess(url: url, format: "PDF")
            } catch {
                await handleError(error.localizedDescription)
            }
        }
    }

    func exportDataReport(
        dataset: DataSet,
        charts: [ChartConfig],
        aiInsightsText: String? = nil
    ) {
        cancelExport()
        activeTask = Task {
            exportStatus   = .generating
            isExporting    = true
            exportProgress = 0.0
            currentStepMessage = "Building Executive Report..."

            do {
                let url = try await PDFExporter.shared.exportDataReport(
                    dataset: dataset,
                    charts: charts,
                    aiInsightsText: aiInsightsText,
                    config: pdfConfig,
                    onProgress: { [weak self] p, msg in
                        Task { @MainActor in
                            self?.exportProgress = p
                            self?.currentStepMessage = msg
                        }
                    }
                )
                await handleSuccess(url: url, format: "PDF Report")
            } catch {
                await handleError(error.localizedDescription)
            }
        }
    }

    // MARK: - Native Save Panel

    func presentSavePanel(for url: URL) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = url.lastPathComponent
        panel.allowedContentTypes = []
        panel.prompt = "Save Export"

        if panel.runModal() == .OK, let dest = panel.url {
            try? FileManager.default.copyItem(at: url, to: dest)
        }
    }

    func openInFinder(url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }

    func openFile(url: URL) {
        NSWorkspace.shared.open(url)
    }

    // MARK: - Cancellation

    func cancelExport() {
        activeTask?.cancel()
        activeTask = nil
        isExporting    = false
        exportProgress = 0.0
        exportStatus   = .idle
    }

    func dismissResult() {
        exportStatus   = .idle
        isExporting    = false
        exportProgress = 0.0
    }

    // MARK: - History Persistence

    private func handleSuccess(url: URL, format: String) async {
        exportProgress = 1.0
        exportStatus   = .success(url)
        isExporting    = false

        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size  = attrs?[.size] as? Int ?? 0

        let item = RecentExportItem(
            id: UUID(),
            filename: url.lastPathComponent,
            format: format,
            exportedAt: Date(),
            fileSizeBytes: size,
            fileURL: url
        )
        recentExports.insert(item, at: 0)
        if recentExports.count > 5 { recentExports = Array(recentExports.prefix(5)) }
        saveRecentExports()

        // Auto-dismiss after 2s
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        if case .success = exportStatus { exportStatus = .idle }
    }

    private func handleError(_ message: String) async {
        exportStatus   = .error(message)
        isExporting    = false
        exportProgress = 0.0
    }

    private func saveRecentExports() {
        guard let data = try? JSONEncoder().encode(recentExports) else { return }
        UserDefaults.standard.set(data, forKey: recentExportsKey)
    }

    private func loadRecentExports() {
        guard let data = UserDefaults.standard.data(forKey: recentExportsKey),
              let decoded = try? JSONDecoder().decode([RecentExportItem].self, from: data) else { return }
        recentExports = decoded
    }
}
