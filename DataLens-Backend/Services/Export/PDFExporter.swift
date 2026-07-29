import AppKit
import PDFKit
import SwiftUI

// MARK: - PDF Export Configuration Types

enum PDFPageSize: String, CaseIterable, Identifiable, Codable {
    case a4     = "A4"
    case letter = "Letter"
    case a3     = "A3"
    case custom = "Custom"

    var id: String { rawValue }

    var dimensionsPoints: CGSize {
        switch self {
        case .a4:     return CGSize(width: 595.2, height: 841.8)
        case .letter: return CGSize(width: 612.0, height: 792.0)
        case .a3:     return CGSize(width: 841.8, height: 1190.5)
        case .custom: return CGSize(width: 800.0, height: 1000.0)
        }
    }
}

enum PDFOrientation: String, CaseIterable, Identifiable, Codable {
    case portrait  = "Portrait"
    case landscape = "Landscape"

    var id: String { rawValue }
}

enum PDFQuality: String, CaseIterable, Identifiable, Codable {
    case standard = "Standard (72 DPI)"
    case high     = "High (150 DPI)"
    case print    = "Print (300 DPI)"

    var id: String { rawValue }
}

struct PDFConfig: Codable, Equatable {
    var pageSize: PDFPageSize         = .a4
    var orientation: PDFOrientation   = .portrait
    var marginTop: Double            = 36.0
    var marginBottom: Double         = 36.0
    var marginLeft: Double           = 36.0
    var marginRight: Double          = 36.0
    var includeHeader: Bool          = true
    var includeFooter: Bool          = true
    var headerText: String           = "DataLens Executive Analytics Report"
    var footerText: String           = "Confidential — Internal Analytics"
    var includePageNumbers: Bool     = true
    var includeTimestamp: Bool       = true
    var includeLogo: Bool            = true
    var quality: PDFQuality          = .high

    var effectivePageSize: CGSize {
        let base = pageSize.dimensionsPoints
        if orientation == .landscape {
            return CGSize(width: base.height, height: base.width)
        }
        return base
    }
}

// MARK: - PDFExporter Service

final class PDFExporter {

    static let shared = PDFExporter()

    private init() {}

    // MARK: - Single Chart PDF Export

    @MainActor
    func exportChart<Content: View>(
        view: Content,
        title: String,
        config: PDFConfig,
        onProgress: ((Double, String) -> Void)? = nil
    ) async throws -> URL {
        onProgress?(0.2, "Preparing PDF page layout...")

        let pdfData = NSMutableData()
        let pageSize = config.effectivePageSize
        var mediaBox = CGRect(origin: .zero, size: pageSize)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "PDFExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize PDF Graphics Context."])
        }

        onProgress?(0.5, "Rendering chart to vector PDF...")
        context.beginPDFPage(nil)

        // Draw Background
        NSColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0).setFill()
        context.fill(mediaBox)

        // Draw Header & Footer
        drawHeaderFooter(context: context, pageRect: mediaBox, pageNum: 1, totalPages: 1, config: config, docTitle: title)

        // Render Chart in Bounds
        let chartArea = CGRect(
            x: config.marginLeft,
            y: config.marginBottom + 30,
            width: pageSize.width - config.marginLeft - config.marginRight,
            height: pageSize.height - config.marginTop - config.marginBottom - 60
        )

        let hostingView = NSHostingView(rootView: view.frame(width: chartArea.width, height: chartArea.height))
        hostingView.frame = chartArea

        context.saveGState()
        context.translateBy(x: chartArea.minX, y: chartArea.minY)
        hostingView.layer?.render(in: context)
        context.restoreGState()

        context.endPDFPage()
        context.closePDF()

        onProgress?(0.9, "Writing PDF document...")
        let filename = sanitizeFilename(title.isEmpty ? "chart_report" : title)
        return try savePDFData(data: pdfData as Data, filename: filename)
    }

    // MARK: - Full Dashboard PDF Export

    @MainActor
    func exportDashboard(
        dashboard: DashboardLayout,
        config: PDFConfig,
        onProgress: ((Double, String) -> Void)? = nil
    ) async throws -> URL {
        onProgress?(0.2, "Generating multi-page dashboard PDF...")

        let pdfData = NSMutableData()
        let pageSize = config.effectivePageSize
        var mediaBox = CGRect(origin: .zero, size: pageSize)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "PDFExporter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize PDF Context."])
        }

        let totalPages = max(1, dashboard.cards.count + 1) // Cover page + card pages

        // Page 1: Cover Page
        onProgress?(0.3, "Rendering Cover Page...")
        context.beginPDFPage(nil)
        drawCoverPage(context: context, pageRect: mediaBox, title: dashboard.name, subtitle: dashboard.description)
        context.endPDFPage()

        // Card Pages
        for (idx, card) in dashboard.cards.enumerated() {
            let pNum = idx + 2
            onProgress?(0.3 + 0.6 * (Double(idx) / Double(dashboard.cards.count)), "Rendering card \(idx + 1) of \(dashboard.cards.count)...")

            context.beginPDFPage(nil)
            NSColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0).setFill()
            context.fill(mediaBox)

            drawHeaderFooter(context: context, pageRect: mediaBox, pageNum: pNum, totalPages: totalPages, config: config, docTitle: dashboard.name)

            // Card Title Header
            let font = NSFont.systemFont(ofSize: 18, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
            let str = NSAttributedString(string: "Card: \(card.title)", attributes: attrs)
            str.draw(at: CGPoint(x: config.marginLeft, y: mediaBox.height - config.marginTop - 24))

            context.endPDFPage()
        }

        context.closePDF()

        onProgress?(0.95, "Finalizing PDF file...")
        return try savePDFData(data: pdfData as Data, filename: sanitizeFilename(dashboard.name))
    }

    // MARK: - Executive Data Report PDF Export

    @MainActor
    func exportDataReport(
        dataset: DataSet,
        charts: [ChartConfig],
        aiInsightsText: String? = nil,
        config: PDFConfig,
        onProgress: ((Double, String) -> Void)? = nil
    ) async throws -> URL {
        onProgress?(0.1, "Initializing Executive PDF Report...")

        let pdfData = NSMutableData()
        let pageSize = config.effectivePageSize
        var mediaBox = CGRect(origin: .zero, size: pageSize)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "PDFExporter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize PDF Context."])
        }

        let totalPages = 4

        // 1. Cover Page
        onProgress?(0.25, "Building Cover Page...")
        context.beginPDFPage(nil)
        drawCoverPage(context: context, pageRect: mediaBox, title: "Executive Data Report", subtitle: "Dataset: \(dataset.name)")
        context.endPDFPage()

        // 2. Executive Summary & AI Insights
        onProgress?(0.50, "Generating Executive Summary...")
        context.beginPDFPage(nil)
        NSColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0).setFill()
        context.fill(mediaBox)
        drawHeaderFooter(context: context, pageRect: mediaBox, pageNum: 2, totalPages: totalPages, config: config, docTitle: "Executive Summary")
        drawSummaryPage(context: context, pageRect: mediaBox, dataset: dataset, aiText: aiInsightsText, config: config)
        context.endPDFPage()

        // 3. Data Overview & Column Metrics
        onProgress?(0.75, "Formatting Data Structure Table...")
        context.beginPDFPage(nil)
        NSColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0).setFill()
        context.fill(mediaBox)
        drawHeaderFooter(context: context, pageRect: mediaBox, pageNum: 3, totalPages: totalPages, config: config, docTitle: "Dataset Schema & Overview")
        drawSchemaPage(context: context, pageRect: mediaBox, dataset: dataset, config: config)
        context.endPDFPage()

        // 4. Raw Sample Data Table
        onProgress?(0.90, "Rendering Sample Data Table...")
        context.beginPDFPage(nil)
        NSColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0).setFill()
        context.fill(mediaBox)
        drawHeaderFooter(context: context, pageRect: mediaBox, pageNum: 4, totalPages: totalPages, config: config, docTitle: "Sample Raw Data (First 50 Rows)")
        drawDataTablePage(context: context, pageRect: mediaBox, dataset: dataset, config: config)
        context.endPDFPage()

        context.closePDF()

        onProgress?(0.98, "Writing Report to disk...")
        return try savePDFData(data: pdfData as Data, filename: sanitizeFilename("\(dataset.name)_report"))
    }

    // MARK: - Page Renderers

    private func drawCoverPage(context: CGContext, pageRect: CGRect, title: String, subtitle: String) {
        NSColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0).setFill()
        context.fill(pageRect)

        // Accent Banner
        NSColor(red: 0.33, green: 0.20, blue: 0.51, alpha: 1.0).setFill()
        context.fill(CGRect(x: 0, y: pageRect.height - 180, width: pageRect.width, height: 180))

        // App Branding
        let brandAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28, weight: .black),
            .foregroundColor: NSColor.white
        ]
        let brandStr = NSAttributedString(string: "DataLens Analytics", attributes: brandAttrs)
        brandStr.draw(at: CGPoint(x: 40, y: pageRect.height - 100))

        // Document Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let titleStr = NSAttributedString(string: title, attributes: titleAttrs)
        titleStr.draw(at: CGPoint(x: 40, y: pageRect.height - 300))

        // Subtitle
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.7)
        ]
        let subStr = NSAttributedString(string: subtitle, attributes: subAttrs)
        subStr.draw(at: CGPoint(x: 40, y: pageRect.height - 340))

        // Timestamp
        let dateForm = DateFormatter()
        dateForm.dateStyle = .long
        dateForm.timeStyle = .short
        let dateStr = NSAttributedString(string: "Generated on: \(dateForm.string(from: Date()))", attributes: subAttrs)
        dateStr.draw(at: CGPoint(x: 40, y: 60))
    }

    private func drawHeaderFooter(
        context: CGContext,
        pageRect: CGRect,
        pageNum: Int,
        totalPages: Int,
        config: PDFConfig,
        docTitle: String
    ) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.5)
        ]

        if config.includeHeader {
            let hdrStr = NSAttributedString(string: config.headerText.isEmpty ? docTitle : config.headerText, attributes: attrs)
            hdrStr.draw(at: CGPoint(x: config.marginLeft, y: pageRect.height - config.marginTop + 10))
        }

        if config.includeFooter {
            var ftrText = config.footerText
            if config.includePageNumbers {
                ftrText += " | Page \(pageNum) of \(totalPages)"
            }
            let ftrStr = NSAttributedString(string: ftrText, attributes: attrs)
            ftrStr.draw(at: CGPoint(x: config.marginLeft, y: config.marginBottom - 20))
        }
    }

    private func drawSummaryPage(context: CGContext, pageRect: CGRect, dataset: DataSet, aiText: String?, config: PDFConfig) {
        let startY = pageRect.height - config.marginTop - 40

        let titleAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 18, weight: .bold), .foregroundColor: NSColor.white]
        NSAttributedString(string: "Key Platform Metrics", attributes: titleAttrs).draw(at: CGPoint(x: config.marginLeft, y: startY))

        let bodyAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12, weight: .regular), .foregroundColor: NSColor.white.withAlphaComponent(0.9)]
        let statsText = "• Total Rows: \(dataset.rowCount)\n• Total Columns: \(dataset.columnCount)\n• Visible Columns: \(dataset.visibleColumns.count)\n• Created: \(dataset.importedAt.formatted())"
        NSAttributedString(string: statsText, attributes: bodyAttrs).draw(at: CGPoint(x: config.marginLeft, y: startY - 80))

        if let ai = aiText, !ai.isEmpty {
            NSAttributedString(string: "AI Findings & Executive Insights", attributes: titleAttrs).draw(at: CGPoint(x: config.marginLeft, y: startY - 180))
            let aiAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .regular), .foregroundColor: NSColor.white.withAlphaComponent(0.85)]
            NSAttributedString(string: String(ai.prefix(800)), attributes: aiAttrs).draw(in: CGRect(x: config.marginLeft, y: startY - 450, width: pageRect.width - config.marginLeft - config.marginRight, height: 250))
        }
    }

    private func drawSchemaPage(context: CGContext, pageRect: CGRect, dataset: DataSet, config: PDFConfig) {
        let startY = pageRect.height - config.marginTop - 40
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 16, weight: .bold), .foregroundColor: NSColor.white]
        NSAttributedString(string: "Dataset Column Schema", attributes: titleAttrs).draw(at: CGPoint(x: config.marginLeft, y: startY))

        var curY = startY - 40
        let rowAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .regular), .foregroundColor: NSColor.white.withAlphaComponent(0.9)]

        for col in dataset.columns.prefix(20) {
            let colLine = "• \(col.name)  —  Type: \(col.type.rawValue)"
            NSAttributedString(string: colLine, attributes: rowAttrs).draw(at: CGPoint(x: config.marginLeft + 10, y: curY))
            curY -= 24
        }
    }

    private func drawDataTablePage(context: CGContext, pageRect: CGRect, dataset: DataSet, config: PDFConfig) {
        let startY = pageRect.height - config.marginTop - 40
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14, weight: .bold), .foregroundColor: NSColor.white]
        NSAttributedString(string: "Sample Raw Rows", attributes: titleAttrs).draw(at: CGPoint(x: config.marginLeft, y: startY))

        var curY = startY - 30
        let cellAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9, design: .monospaced), .foregroundColor: NSColor.white.withAlphaComponent(0.8)]

        let visibleCols = Array(dataset.visibleColumns.prefix(5))
        for (rowIdx, r) in dataset.rows.prefix(25).enumerated() {
            let rowVals = visibleCols.map { "\($0.name): \(r.values[$0.name] ?? "")" }.joined(separator: " | ")
            NSAttributedString(string: "[\(rowIdx + 1)] \(rowVals)", attributes: cellAttrs).draw(at: CGPoint(x: config.marginLeft, y: curY))
            curY -= 18
        }
    }

    // MARK: - Helpers

    private func sanitizeFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }

    private func savePDFData(data: Data, filename: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(filename).pdf")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
