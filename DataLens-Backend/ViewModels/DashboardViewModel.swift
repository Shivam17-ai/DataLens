import SwiftUI
import Combine

/// Manages interactive dashboard canvas layouts, dragging, resizing, duplication, Z-ordering, card selection, and config synchronization.
final class DashboardViewModel: ObservableObject {
    @Published var currentDashboard: DashboardLayout?
    @Published var cards: [DashboardCard] = []
    @Published var selectedCardIds: Set<UUID> = []
    @Published var isPreviewMode: Bool = false
    @Published var zoomLevel: Double = 1.0 // 1.0 = 100%, range 0.5 to 2.0
    @Published var canvasOffset: CGSize = .zero
    
    private var maxZIndex: Int = 0

    init() {
        // Initialize an empty dashboard
        let defaultLayout = DashboardLayout()
        self.currentDashboard = defaultLayout
        self.cards = defaultLayout.cards
        self.maxZIndex = defaultLayout.cards.map { $0.zIndex }.max() ?? 0
    }

    // MARK: - Layout Modifiers

    func addCard(type: CardType, at point: CGPoint) {
        maxZIndex += 1
        var newTitle = ""
        var defaultSize = CGSize(width: 400, height: 300)
        var chartConf: ChartConfig? = nil
        var kpiConf: KPIConfig? = nil
        var textCont: String? = nil

        switch type {
        case .chart:
            newTitle = "New Chart Card"
            chartConf = ChartConfig(
                id: UUID(),
                chartType: .bar,
                title: "Chart Widget",
                xAxisColumn: nil,
                yAxisColumn: nil,
                colorTheme: .ocean,
                showLegend: true,
                showGrid: true,
                showTooltips: true,
                showDataLabels: false,
                animationDuration: 0.5
            )
        case .text:
            newTitle = "Text Widget"
            defaultSize = CGSize(width: 300, height: 200)
            textCont = "Type something here..."
        case .kpi:
            newTitle = "KPI Metric"
            defaultSize = CGSize(width: 240, height: 160)
            kpiConf = KPIConfig()
        case .filter:
            newTitle = "Category Filter"
            defaultSize = CGSize(width: 240, height: 100)
        }

        let newCard = DashboardCard(
            id: UUID(),
            type: type,
            position: point,
            size: defaultSize,
            zIndex: maxZIndex,
            chartConfig: chartConf,
            textContent: textCont,
            kpiConfig: kpiConf,
            isMinimized: false,
            title: newTitle
        )

        cards.append(newCard)
        updateCurrentDashboard()
        
        // Auto select the newly added card
        selectedCardIds = [newCard.id]
    }

    func moveCard(id: UUID, to point: CGPoint) {
        if let index = cards.firstIndex(where: { $0.id == id }) {
            var targetPoint = point
            if let snap = currentDashboard?.snapToGrid, snap {
                // Snap to nearest 20pt position
                let gridSpacing: CGFloat = 20.0
                targetPoint.x = round(targetPoint.x / gridSpacing) * gridSpacing
                targetPoint.y = round(targetPoint.y / gridSpacing) * gridSpacing
            }
            cards[index].position = targetPoint
            updateCurrentDashboard()
        }
    }

    func resizeCard(id: UUID, to size: CGSize) {
        if let index = cards.firstIndex(where: { $0.id == id }) {
            var targetSize = size
            
            // Respect minimum width and height constraints
            targetSize.width = max(200, targetSize.width)
            targetSize.height = max(150, targetSize.height)

            if let snap = currentDashboard?.snapToGrid, snap {
                let gridSpacing: CGFloat = 20.0
                targetSize.width = round(targetSize.width / gridSpacing) * gridSpacing
                targetSize.height = round(targetSize.height / gridSpacing) * gridSpacing
            }

            cards[index].size = targetSize
            updateCurrentDashboard()
        }
    }

    func deleteCard(id: UUID) {
        cards.removeAll { $0.id == id }
        selectedCardIds.remove(id)
        updateCurrentDashboard()
    }

    func duplicateCard(id: UUID) {
        guard let origin = cards.first(where: { $0.id == id }) else { return }
        maxZIndex += 1
        let newCard = DashboardCard(
            id: UUID(),
            type: origin.type,
            position: CGPoint(x: origin.position.x + 30, y: origin.position.y + 30),
            size: origin.size,
            zIndex: maxZIndex,
            chartConfig: origin.chartConfig,
            textContent: origin.textContent,
            kpiConfig: origin.kpiConfig,
            isMinimized: origin.isMinimized,
            title: origin.title + " (Copy)"
        )
        cards.append(newCard)
        selectedCardIds = [newCard.id]
        updateCurrentDashboard()
    }

    func bringToFront(id: UUID) {
        if let index = cards.firstIndex(where: { $0.id == id }) {
            maxZIndex += 1
            cards[index].zIndex = maxZIndex
            updateCurrentDashboard()
        }
    }

    func sendToBack(id: UUID) {
        if let index = cards.firstIndex(where: { $0.id == id }) {
            let minZ = cards.map { $0.zIndex }.min() ?? 0
            cards[index].zIndex = minZ - 1
            updateCurrentDashboard()
        }
    }

    // MARK: - Card Selection

    func selectCard(id: UUID, adding: Bool) {
        if adding {
            if selectedCardIds.contains(id) {
                selectedCardIds.remove(id)
            } else {
                selectedCardIds.insert(id)
            }
        } else {
            selectedCardIds = [id]
        }
    }

    func clearSelection() {
        selectedCardIds.removeAll()
    }

    func groupSelected() {
        // Aesthetic / placeholder helper for card grouping
    }

    // MARK: - Helper Updates

    private func updateCurrentDashboard() {
        currentDashboard?.cards = cards
        currentDashboard?.updatedAt = Date()
    }
}
