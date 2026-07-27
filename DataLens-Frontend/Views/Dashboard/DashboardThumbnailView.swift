import SwiftUI
import AppKit

/// Rendered mini preview thumbnail card for a dashboard item (280x180pt)
struct DashboardThumbnailView: View {
    let dashboard: DashboardLayout
    let onOpen: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onExport: () -> Void

    @State private var isHovered: Bool = false
    @State private var thumbnailImage: NSImage? = nil
    @State private var isLoading: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Thumbnail Graphic Area (280x180pt) ─────────────────
            ZStack {
                Color(hex: dashboard.backgroundColor) ?? ColorPalette.background

                if let img = thumbnailImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if isLoading {
                    shimmerPlaceholder
                } else {
                    proportionalMiniCanvas
                }

                // Hover Actions Overlay
                if isHovered {
                    Color.black.opacity(0.5)
                        .transition(.opacity)

                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Button(action: onOpen) {
                                Label("Open", systemImage: "arrow.up.forward.app.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(ColorPalette.accent)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Button(action: onDuplicate) {
                                Image(systemName: "plus.square.on.square")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(ColorPalette.cards)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .help("Duplicate")

                            Button(action: onExport) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(ColorPalette.cards)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .help("Export JSON")

                            Button(action: onDelete) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(ColorPalette.warning)
                                    .frame(width: 28, height: 28)
                                    .background(ColorPalette.cards)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .help("Delete")
                        }
                    }
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .frame(width: 280, height: 180)
            .clipped()

            // ── Footer Info ───────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(dashboard.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(ColorPalette.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    // Card Count Badge
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 9))
                        Text("\(dashboard.cards.count)")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(ColorPalette.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(ColorPalette.background.opacity(0.6))
                    .cornerRadius(4)
                }

                HStack {
                    Text("Modified \(formattedDate(dashboard.updatedAt))")
                        .font(.system(size: 10))
                        .foregroundColor(ColorPalette.textSecondary)

                    Spacer()
                }

                // Tags
                if !dashboard.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(dashboard.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(ColorPalette.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ColorPalette.accent.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(12)
            .background(ColorPalette.sidebar)
        }
        .frame(width: 280)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHovered ? ColorPalette.accent : ColorPalette.border, lineWidth: isHovered ? 1.5 : 1)
        )
        .shadow(
            color: isHovered ? ColorPalette.accent.opacity(0.25) : .black.opacity(0.3),
            radius: isHovered ? 12 : 6,
            x: 0,
            y: isHovered ? 6 : 3
        )
        .offset(y: isHovered ? -4 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            renderThumbnailInBackground()
        }
    }

    // MARK: - Subviews & Helpers

    private var shimmerPlaceholder: some View {
        Rectangle()
            .fill(ColorPalette.cards.opacity(0.6))
            .overlay(
                ProgressView()
                    .scaleEffect(0.8)
            )
    }

    private var proportionalMiniCanvas: some View {
        GeometryReader { geo in
            let scaleX = geo.size.width / max(1, dashboard.canvasSize.width)
            let scaleY = geo.size.height / max(1, dashboard.canvasSize.height)

            ZStack(alignment: .topLeading) {
                ForEach(dashboard.cards) { card in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(cardColor(card.type).opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                        .frame(
                            width: max(8, card.size.width * scaleX),
                            height: max(6, card.size.height * scaleY)
                        )
                        .position(
                            x: (card.position.x + card.size.width / 2) * scaleX,
                            y: (card.position.y + card.size.height / 2) * scaleY
                        )
                }
            }
        }
    }

    private func renderThumbnailInBackground() {
        if let tData = dashboard.thumbnailData, let img = NSImage(data: tData) {
            self.thumbnailImage = img
            self.isLoading = false
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let img = DashboardExporter.generateThumbnail(dashboard: dashboard)
            DispatchQueue.main.async {
                self.thumbnailImage = img
                self.isLoading = false
            }
        }
    }

    private func cardColor(_ type: CardType) -> Color {
        switch type {
        case .chart:  return ColorPalette.accent
        case .text:   return ColorPalette.success
        case .kpi:    return ColorPalette.warning
        case .filter: return Color(hex: "#E879F9") ?? ColorPalette.accent
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
