import AppKit
import SwiftUI

/// Export and Import helper service for Dashboard layouts
final class DashboardExporter {

    /// Schema wrapper for exported JSON files
    struct ExportEnvelope: Codable {
        let schemaVersion: Int
        let exportedAt: Date
        let appVersion: String
        let dashboard: DashboardLayout

        init(dashboard: DashboardLayout) {
            self.schemaVersion = kDashboardSchemaVersion
            self.exportedAt = Date()
            self.appVersion = "1.0.0"
            self.dashboard = dashboard
        }
    }

    /// Export dashboard layout to JSON Data
    static func exportToJSON(dashboard: DashboardLayout) throws -> Data {
        let envelope = ExportEnvelope(dashboard: dashboard)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(envelope)
    }

    /// Import dashboard layout from JSON Data
    static func importFromJSON(data: Data) throws -> DashboardLayout {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Try decoding envelope first, fallback to direct layout
        if let envelope = try? decoder.decode(ExportEnvelope.self, from: data) {
            var layout = envelope.dashboard
            layout.id = UUID() // Assign new ID to prevent collision
            return layout
        }
        
        var layout = try decoder.decode(DashboardLayout.self, from: data)
        layout.id = UUID()
        return layout
    }

    /// Generate a 560x360 @2x thumbnail image of a dashboard layout
    static func generateThumbnail(dashboard: DashboardLayout, size: CGSize = CGSize(width: 560, height: 360)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        // Draw background
        let bgHex = dashboard.backgroundColor
        let bgColor = NSColor(hex: bgHex) ?? NSColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0)
        bgColor.setFill()
        context.fill(CGRect(origin: .zero, size: size))

        // Grid dots preview
        if dashboard.gridEnabled {
            context.setFillColor(NSColor.white.withAlphaComponent(0.08).cgColor)
            let step: CGFloat = 16
            for x in stride(from: 0, to: size.width, by: step) {
                for y in stride(from: 0, to: size.height, by: step) {
                    context.fillEllipse(in: CGRect(x: x, y: y, width: 1.5, height: 1.5))
                }
            }
        }

        // Scale factors mapping 2000x2000 canvas to thumbnail size
        let scaleX = size.width / max(1, dashboard.canvasSize.width)
        let scaleY = size.height / max(1, dashboard.canvasSize.height)

        for card in dashboard.cards {
            let cardRect = CGRect(
                x: card.position.x * scaleX,
                y: size.height - (card.position.y + card.size.height) * scaleY, // NSView flipped coordinates
                width: max(10, card.size.width * scaleX),
                height: max(10, card.size.height * scaleY)
            )

            // Card background (#0F3460)
            let cardBg = NSColor(red: 0.06, green: 0.20, blue: 0.38, alpha: 0.9)
            cardBg.setFill()
            let path = NSBezierPath(roundedRect: cardRect, xRadius: 4, yRadius: 4)
            path.fill()

            // Header accent bar
            let headerColor: NSColor
            switch card.type {
            case .chart:  headerColor = NSColor(red: 0.33, green: 0.20, blue: 0.51, alpha: 1.0)
            case .text:   headerColor = NSColor(red: 0.00, green: 0.71, blue: 0.85, alpha: 1.0)
            case .kpi:    headerColor = NSColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.0)
            case .filter: headerColor = NSColor(red: 0.91, green: 0.47, blue: 0.98, alpha: 1.0)
            }
            headerColor.setFill()
            let headerRect = CGRect(x: cardRect.minX, y: cardRect.maxY - min(8, cardRect.height * 0.25), width: cardRect.width, height: min(8, cardRect.height * 0.25))
            let headerPath = NSBezierPath(rect: headerRect)
            headerPath.fill()

            // Card border (#2A2A4A)
            NSColor(red: 0.16, green: 0.16, blue: 0.29, alpha: 1.0).setStroke()
            path.lineWidth = 1.0
            path.stroke()
        }

        image.unlockFocus()
        return image
    }
}

// MARK: - NSColor Helper for Hex

private extension NSColor {
    convenience init?(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.hasPrefix("#") { cleanHex.removeFirst() }

        guard cleanHex.count == 6, let rgbValue = UInt64(cleanHex, radix: 16) else { return nil }

        let red   = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue  = CGFloat(rgbValue & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
