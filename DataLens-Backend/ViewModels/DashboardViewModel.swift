import SwiftUI
import Combine

/// Manages interactive dashboard canvas layouts, persistence, multiple open tabs, templates, auto-saving, and export/import.
final class DashboardViewModel: ObservableObject {
    
    // MARK: - Published State (Canvas & Selection)
    @Published var currentDashboard: DashboardLayout?
    @Published var cards: [DashboardCard] = []
    @Published var selectedCardIds: Set<UUID> = []
    @Published var isPreviewMode: Bool = false
    @Published var zoomLevel: Double = 1.0 // 1.0 = 100%, range 0.5 to 2.0
    @Published var canvasOffset: CGSize = .zero
    
    // MARK: - Published State (Multiple Dashboards & Persistence)
    @Published var allDashboards: [DashboardLayout] = []
    @Published var openTabs: [DashboardLayout] = []
    @Published var activeTabId: UUID? = nil
    @Published var hasUnsavedChanges: Bool = false
    @Published var lastSavedAt: Date? = nil
    @Published var isSaving: Bool = false
    @Published var showSaveDialog: Bool = false
    @Published var showTemplateSelector: Bool = false
    @Published var toastMessage: String? = nil
    @Published var searchQuery: String = ""
    @Published var sortOption: SortOption = .lastModified
    
    enum SortOption: String, CaseIterable, Identifiable {
        case lastModified = "Last Modified"
        case createdDate  = "Created Date"
        case name         = "Name"
        var id: String { rawValue }
    }
    
    private var maxZIndex: Int = 0
    private var cancellables = Set<AnyCancellable>()
    private var autoSaveTimer: AnyCancellable?
    
    // MARK: - Init
    
    init() {
        Task {
            await loadAllDashboards()
        }
        setupAutoSave()
    }
    
    // MARK: - Auto Save & Dirty Tracking
    
    private func setupAutoSave() {
        autoSaveTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.hasUnsavedChanges, self.currentDashboard != nil else { return }
                Task {
                    try? await self.saveCurrent()
                }
            }
    }
    
    func markDirty() {
        hasUnsavedChanges = true
        updateCurrentDashboard()
    }
    
    // MARK: - Dashboard Management API
    
    @MainActor
    func loadAllDashboards() async {
        do {
            let loaded = try CoreDataManager.shared.loadAllDashboards()
            self.allDashboards = loaded
        } catch {
            showToast("Failed to load dashboards")
        }
    }
    
    @MainActor
    func openDashboard(id: UUID) {
        if let existingTab = openTabs.first(where: { $0.id == id }) {
            switchTab(to: existingTab.id)
            return
        }
        
        guard let layout = allDashboards.first(where: { $0.id == id }) ?? (try? CoreDataManager.shared.loadDashboard(id: id)) else {
            return
        }
        
        if openTabs.count >= 5 {
            showToast("Maximum 5 open tabs allowed")
            return
        }
        
        openTabs.append(layout)
        switchTab(to: layout.id)
    }
    
    @MainActor
    func newDashboard(from template: DashboardTemplate = .blank) {
        if openTabs.count >= 5 {
            showToast("Maximum 5 open tabs allowed")
            return
        }
        
        let initialCards = template.makeCards()
        let name = template == .blank ? "Untitled Dashboard" : "\(template.rawValue)"
        
        var layout = DashboardLayout(
            name: name,
            description: template.description,
            tags: template == .blank ? [] : [template.rawValue.lowercased()],
            cards: initialCards
        )
        
        // Generate initial thumbnail
        let thumbnail = DashboardExporter.generateThumbnail(dashboard: layout)
        if let tData = thumbnail.tiffRepresentation {
            layout.thumbnailData = tData
        }
        
        openTabs.append(layout)
        switchTab(to: layout.id)
        hasUnsavedChanges = true
        
        if template == .blank {
            showSaveDialog = true
        }
    }
    
    @MainActor
    func switchTab(to id: UUID) {
        saveTabState()
        
        guard let tab = openTabs.first(where: { $0.id == id }) else { return }
        activeTabId = id
        currentDashboard = tab
        cards = tab.cards
        zoomLevel = tab.canvasZoom
        canvasOffset = CGSize(width: tab.canvasOffsetX, height: tab.canvasOffsetY)
        maxZIndex = tab.cards.map { $0.zIndex }.max() ?? 0
        selectedCardIds.removeAll()
    }
    
    @MainActor
    func closeTab(id: UUID) {
        guard let index = openTabs.firstIndex(where: { $0.id == id }) else { return }
        openTabs.remove(at: index)
        
        if activeTabId == id {
            if let nextTab = openTabs.last {
                switchTab(to: nextTab.id)
            } else {
                activeTabId = nil
                currentDashboard = nil
                cards = []
            }
        }
    }
    
    @MainActor
    func saveCurrent() async throws {
        guard var layout = currentDashboard else { return }
        
        isSaving = true
        layout.cards = cards
        layout.canvasZoom = zoomLevel
        layout.canvasOffsetX = canvasOffset.width
        layout.canvasOffsetY = canvasOffset.height
        layout.updatedAt = Date()
        
        // Generate fresh thumbnail
        let thumb = DashboardExporter.generateThumbnail(dashboard: layout)
        if let tData = thumb.tiffRepresentation {
            layout.thumbnailData = tData
        }
        
        try CoreDataManager.shared.saveDashboard(layout)
        
        currentDashboard = layout
        lastSavedAt = Date()
        hasUnsavedChanges = false
        isSaving = false
        
        // Update in openTabs and allDashboards
        if let tIdx = openTabs.firstIndex(where: { $0.id == layout.id }) {
            openTabs[tIdx] = layout
        }
        
        await loadAllDashboards()
        showToast("Dashboard Saved")
    }
    
    @MainActor
    func deleteDashboard(id: UUID) async {
        do {
            try CoreDataManager.shared.deleteDashboard(id: id)
            closeTab(id: id)
            await loadAllDashboards()
            showToast("Dashboard Deleted")
        } catch {
            showToast("Failed to delete dashboard")
        }
    }
    
    @MainActor
    func duplicateDashboard(id: UUID) async {
        do {
            let dup = try CoreDataManager.shared.duplicateDashboard(id: id)
            await loadAllDashboards()
            openDashboard(id: dup.id)
            showToast("Dashboard Duplicated")
        } catch {
            showToast("Failed to duplicate dashboard")
        }
    }
    
    @MainActor
    func exportDashboard(id: UUID) -> URL? {
        guard let layout = allDashboards.first(where: { $0.id == id }) ?? (try? CoreDataManager.shared.loadDashboard(id: id)) else { return nil }
        
        do {
            let data = try DashboardExporter.exportToJSON(dashboard: layout)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(layout.name).datalens")
            try data.write(to: tempURL)
            return tempURL
        } catch {
            showToast("Export failed")
            return nil
        }
    }
    
    @MainActor
    func importDashboard(from url: URL) async {
        do {
            let data = try Data(contentsOf: url)
            let layout = try DashboardExporter.importFromJSON(data: data)
            try CoreDataManager.shared.saveDashboard(layout)
            await loadAllDashboards()
            openDashboard(id: layout.id)
            showToast("Dashboard Imported")
        } catch {
            showToast("Import failed: Invalid file format")
        }
    }
    
    // MARK: - Toast Notification Helper
    
    @MainActor
    func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.toastMessage == message {
                self?.toastMessage = nil
            }
        }
    }
    
    // MARK: - Internal Layout Modifiers
    
    private func saveTabState() {
        guard let activeId = activeTabId, let idx = openTabs.firstIndex(where: { $0.id == activeId }) else { return }
        openTabs[idx].cards = cards
        openTabs[idx].canvasZoom = zoomLevel
        openTabs[idx].canvasOffsetX = canvasOffset.width
        openTabs[idx].canvasOffsetY = canvasOffset.height
    }
    
    private func updateCurrentDashboard() {
        currentDashboard?.cards = cards
        currentDashboard?.updatedAt = Date()
    }
    
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
        markDirty()
        selectedCardIds = [newCard.id]
    }

    func moveCard(id: UUID, to point: CGPoint) {
        if let index = cards.firstIndex(where: { $0.id == id }) {
            var targetPoint = point
            if let snap = currentDashboard?.snapToGrid, snap {
                let gridSpacing: CGFloat = 20.0
                targetPoint.x = round(targetPoint.x / gridSpacing) * gridSpacing
                targetPoint.y = round(targetPoint.y / gridSpacing) * gridSpacing
            }
            cards[index].position = targetPoint
            markDirty()
        }
    }

    func resizeCard(id: UUID, to size: CGSize) {
        if let index = cards.firstIndex(where: { $0.id == id }) {
            var targetSize = size
            targetSize.width = max(200, targetSize.width)
            targetSize.height = max(150, targetSize.height)

            if let snap = currentDashboard?.snapToGrid, snap {
                let gridSpacing: CGFloat = 20.0
                targetSize.width = round(targetSize.width / gridSpacing) * gridSpacing
                targetSize.height = round(targetSize.height / gridSpacing) * gridSpacing
            }

            cards[index].size = targetSize
            markDirty()
        }
    }

    func deleteCard(id: UUID) {
        cards.removeAll { $0.id == id }
        selectedCardIds.remove(id)
        markDirty()
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
        markDirty()
    }

    func bringToFront(id: UUID) {
        if let index = cards.firstIndex(where: { $0.id == id }) {
            maxZIndex += 1
            cards[index].zIndex = maxZIndex
            markDirty()
        }
    }

    func sendToBack(id: UUID) {
        if let index = cards.firstIndex(where: { $0.id == id }) {
            let minZ = cards.map { $0.zIndex }.min() ?? 0
            cards[index].zIndex = minZ - 1
            markDirty()
        }
    }

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
}
