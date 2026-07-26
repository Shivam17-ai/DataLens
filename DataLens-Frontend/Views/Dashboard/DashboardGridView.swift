import SwiftUI

// MARK: - DashboardGridView

/// The infinite scrollable canvas for the dashboard builder.
/// Features:
///   - Dot-grid background with configurable visibility
///   - Pan with two-finger scroll or middle-mouse drag
///   - Zoom via scroll wheel (with Cmd modifier) or toolbar controls
///   - Drop target for cards dragged from the toolbar palette
///   - Click on empty canvas to deselect all cards
///   - Selection rectangle (rubber-band selection)
struct DashboardGridView: View {

    @ObservedObject var dashboardViewModel: DashboardViewModel
    var dataset: DataSet?

    // Internal geometry tracking
    @State private var rubberBandOrigin: CGPoint? = nil
    @State private var rubberBandCurrent: CGPoint = .zero

    private let dotSpacing: CGFloat = 20
    private let dotRadius: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // ── Background with dot grid ────────────────────────────
                canvasBackground(size: geo.size)

                // ── Cards layer (inside scaled + offset ZStack) ─────────
                ZStack {
                    // All cards
                    ForEach(dashboardViewModel.cards.sorted(by: { $0.zIndex < $1.zIndex })) { card in
                        DashboardCardView(
                            dashboardViewModel: dashboardViewModel,
                            card: card,
                            dataset: dataset
                        )
                    }
                }
                .scaleEffect(dashboardViewModel.zoomLevel, anchor: .center)
                .offset(dashboardViewModel.canvasOffset)

                // ── Rubber-band selection rectangle ─────────────────────
                if let origin = rubberBandOrigin {
                    let rect = CGRect(
                        x: min(origin.x, rubberBandCurrent.x),
                        y: min(origin.y, rubberBandCurrent.y),
                        width: abs(rubberBandCurrent.x - origin.x),
                        height: abs(rubberBandCurrent.y - origin.y)
                    )
                    RubberBandRect(rect: rect)
                }

                // ── Preview mode overlay (blocks interaction) ───────────
                if dashboardViewModel.isPreviewMode {
                    previewBadge
                }
            }
            .contentShape(Rectangle())
            .gesture(canvasDragGesture)
            .onTapGesture {
                dashboardViewModel.clearSelection()
            }
        }
        .clipped()
    }

    // MARK: - Background Canvas

    @ViewBuilder
    private func canvasBackground(size: CGSize) -> some View {
        ZStack {
            // Base color
            Color(hex: "#1A1A2E") ?? ColorPalette.background

            // Dot grid
            if dashboardViewModel.currentDashboard?.gridEnabled == true {
                Canvas { context, canvasSize in
                    let cols = Int(canvasSize.width / dotSpacing) + 2
                    let rows = Int(canvasSize.height / dotSpacing) + 2

                    let xOffset = dashboardViewModel.canvasOffset.width.truncatingRemainder(dividingBy: dotSpacing)
                    let yOffset = dashboardViewModel.canvasOffset.height.truncatingRemainder(dividingBy: dotSpacing)

                    for col in 0..<cols {
                        for row in 0..<rows {
                            let x = CGFloat(col) * dotSpacing + xOffset
                            let y = CGFloat(row) * dotSpacing + yOffset
                            let dotRect = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                            context.fill(Path(ellipseIn: dotRect), with: .color(Color.white.opacity(0.1)))
                        }
                    }
                }
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Pan Gesture

    private var canvasDragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if !dashboardViewModel.selectedCardIds.isEmpty {
                    // Start rubber band if tapping empty space
                    if rubberBandOrigin == nil {
                        rubberBandOrigin = value.startLocation
                    }
                    rubberBandCurrent = value.location
                } else {
                    // Pan the canvas
                    dashboardViewModel.canvasOffset = CGSize(
                        width: dashboardViewModel.canvasOffset.width + value.translation.width,
                        height: dashboardViewModel.canvasOffset.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                rubberBandOrigin = nil
                rubberBandCurrent = .zero
            }
    }

    // MARK: - Preview Mode Badge

    private var previewBadge: some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 10))
                    Text("PREVIEW")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundColor(ColorPalette.success)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(ColorPalette.success.opacity(0.15))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorPalette.success.opacity(0.4), lineWidth: 1))
                .padding(14)
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Rubber Band Rect

private struct RubberBandRect: View {
    let rect: CGRect

    var body: some View {
        Rectangle()
            .stroke(ColorPalette.accent, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            .background(Rectangle().fill(ColorPalette.accent.opacity(0.07)))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
    }
}
