import AppKit
import SwiftUI

// MARK: - Image Export Configuration Types

enum ImageFormat: String, CaseIterable, Identifiable, Codable {
    case png  = "PNG"
    case jpg  = "JPG"
    case webp = "WEBP"
    case tiff = "TIFF"

    var id: String { rawValue }

    var fileExtension: String {
        rawValue.lowercased()
    }
}

struct ImageConfig: Codable, Equatable {
    var format: ImageFormat        = .png
    var scale: Double              = 2.0 // 1x, 2x, 3x
    var customWidth: Double?       = nil
    var customHeight: Double?      = nil
    var useDarkBackground: Bool    = true
    var includeWatermark: Bool     = true
    var compressionQuality: Double = 0.9 // for JPG

    init(
        format: ImageFormat = .png,
        scale: Double = 2.0,
        customWidth: Double? = nil,
        customHeight: Double? = nil,
        useDarkBackground: Bool = true,
        includeWatermark: Bool = true,
        compressionQuality: Double = 0.9
    ) {
        self.format = format
        self.scale = scale
        self.customWidth = customWidth
        self.customHeight = customHeight
        self.useDarkBackground = useDarkBackground
        self.includeWatermark = includeWatermark
        self.compressionQuality = compressionQuality
    }
}

// MARK: - ImageExporter Service

final class ImageExporter {

    static let shared = ImageExporter()

    private init() {}

    // MARK: - Export View / Chart to Image

    @MainActor
    func exportChart<Content: View>(
        view: Content,
        title: String,
        config: ImageConfig,
        onProgress: ((Double, String) -> Void)? = nil
    ) async throws -> URL {
        onProgress?(0.2, "Rendering chart layout...")

        let baseSize = CGSize(width: config.customWidth ?? 800, height: config.customHeight ?? 500)
        let image = renderViewToNSImage(view: view, size: baseSize, config: config)

        onProgress?(0.7, "Compressing image (\(config.format.rawValue))...")

        guard let imageData = convertToData(image: image, config: config) else {
            throw NSError(domain: "ImageExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render image format."])
        }

        onProgress?(0.9, "Writing image file to disk...")
        let filename = sanitizeFilename(title.isEmpty ? "chart_export" : title)
        return try saveImageData(data: imageData, filename: filename, extensionStr: config.format.fileExtension)
    }

    // MARK: - Export Dashboard to Image

    @MainActor
    func exportDashboard(
        dashboard: DashboardLayout,
        config: ImageConfig,
        onProgress: ((Double, String) -> Void)? = nil
    ) async throws -> URL {
        onProgress?(0.2, "Rendering dashboard canvas...")

        let canvasSize = CGSize(
            width: config.customWidth ?? dashboard.canvasSize.width,
            height: config.customHeight ?? dashboard.canvasSize.height
        )

        let image = DashboardExporter.generateThumbnail(dashboard: dashboard, size: canvasSize)

        onProgress?(0.7, "Compressing image (\(config.format.rawValue))...")

        guard let imageData = convertToData(image: image, config: config) else {
            throw NSError(domain: "ImageExporter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to render dashboard image."])
        }

        onProgress?(0.9, "Saving image...")
        let filename = sanitizeFilename(dashboard.name)
        return try saveImageData(data: imageData, filename: filename, extensionStr: config.format.fileExtension)
    }

    // MARK: - Copy to Clipboard

    @MainActor
    func copyToClipboard<Content: View>(view: Content, size: CGSize = CGSize(width: 800, height: 500)) {
        let config = ImageConfig(format: .png, scale: 2.0)
        let image = renderViewToNSImage(view: view, size: size, config: config)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    // MARK: - Core Rendering Helper

    @MainActor
    private func renderViewToNSImage<Content: View>(
        view: Content,
        size: CGSize,
        config: ImageConfig
    ) -> NSImage {
        let scaledSize = CGSize(width: size.width * config.scale, height: size.height * config.scale)
        let image = NSImage(size: scaledSize)

        image.lockFocus()
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        // Draw Background
        let bgColor: NSColor
        if config.useDarkBackground {
            bgColor = NSColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0) // #1A1A2E
        } else {
            bgColor = NSColor.white
        }
        bgColor.setFill()
        context.fill(CGRect(origin: .zero, size: scaledSize))

        // Draw SwiftUI View using NSHostingView
        let wrapper = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        wrapper.frame = CGRect(origin: .zero, size: size)

        context.saveGState()
        context.scaleBy(x: config.scale, y: config.scale)
        wrapper.layer?.render(in: context)
        context.restoreGState()

        // Draw Watermark if enabled
        if config.includeWatermark {
            drawWatermark(context: context, size: scaledSize)
        }

        image.unlockFocus()
        return image
    }

    private func drawWatermark(context: CGContext, size: CGSize) {
        let text = "Created with DataLens"
        let font = NSFont.systemFont(ofSize: 12 * (size.width / 800), weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white.withAlphaComponent(0.4)
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let strSize = attrStr.size()

        let rect = CGRect(
            x: size.width - strSize.width - 16,
            y: 12,
            width: strSize.width,
            height: strSize.height
        )

        attrStr.draw(in: rect)
    }

    private func convertToData(image: NSImage, config: ImageConfig) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }

        switch config.format {
        case .png:
            return bitmap.representation(using: .png, properties: [:])
        case .jpg:
            return bitmap.representation(using: .jpeg, properties: [.compressionFactor: config.compressionQuality])
        case .tiff:
            return bitmap.representation(using: .tiff, properties: [:])
        case .webp:
            // Fallback to PNG if WEBP encoder unavailable natively in AppKit
            return bitmap.representation(using: .png, properties: [:])
        }
    }

    private func sanitizeFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }

    private func saveImageData(data: Data, filename: String, extensionStr: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(filename).\(extensionStr)")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
