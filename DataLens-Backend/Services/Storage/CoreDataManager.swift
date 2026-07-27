import Foundation

/// Manages persistence of dashboards. Provides a CoreData-compatible API
/// using JSON file storage in Application Support / DataLens / Dashboards.
final class CoreDataManager {
    
    static let shared = CoreDataManager()
    
    private let fileManager = FileManager.default
    private let storageDirectory: URL
    
    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDirectory = appSupport.appendingPathComponent("DataLens/Dashboards", isDirectory: true)
        
        try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true, attributes: nil)
    }
    
    // MARK: - CoreData-compatible API Methods
    
    /// Save or update a dashboard layout
    func saveDashboard(_ layout: DashboardLayout) throws {
        var updatedLayout = layout
        updatedLayout.updatedAt = Date()
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(updatedLayout)
        let fileURL = storageDirectory.appendingPathComponent("\(layout.id.uuidString).json")
        try data.write(to: fileURL, options: .atomic)
    }
    
    /// Load a single dashboard layout by ID
    func loadDashboard(id: UUID) throws -> DashboardLayout? {
        let fileURL = storageDirectory.appendingPathComponent("\(id.uuidString).json")
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DashboardLayout.self, from: data)
    }
    
    /// Load all saved dashboard layouts, sorted by updatedAt descending
    func loadAllDashboards() throws -> [DashboardLayout] {
        guard fileManager.fileExists(atPath: storageDirectory.path) else { return [] }
        
        let fileURLs = try fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        var layouts: [DashboardLayout] = []
        for url in fileURLs {
            if let data = try? Data(contentsOf: url),
               let layout = try? decoder.decode(DashboardLayout.self, from: data) {
                layouts.append(layout)
            }
        }
        
        return layouts.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    /// Delete a dashboard layout by ID
    func deleteDashboard(id: UUID) throws {
        let fileURL = storageDirectory.appendingPathComponent("\(id.uuidString).json")
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    /// Duplicate a dashboard layout by ID
    func duplicateDashboard(id: UUID) throws -> DashboardLayout {
        guard let original = try loadDashboard(id: id) else {
            throw NSError(domain: "DataLens", code: 404, userInfo: [NSLocalizedDescriptionKey: "Dashboard not found"])
        }
        
        var duplicate = original
        duplicate.id = UUID()
        duplicate.name = "\(original.name) (Copy)"
        duplicate.createdAt = Date()
        duplicate.updatedAt = Date()
        
        try saveDashboard(duplicate)
        return duplicate
    }
    
    /// Search dashboards by name or tags
    func searchDashboards(query: String) throws -> [DashboardLayout] {
        let all = try loadAllDashboards()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty { return all }
        
        return all.filter { dashboard in
            dashboard.name.lowercased().contains(trimmed) ||
            dashboard.description.lowercased().contains(trimmed) ||
            dashboard.tags.contains { $0.lowercased().contains(trimmed) }
        }
    }
    
    /// Update thumbnail data for a dashboard
    func updateDashboardThumbnail(id: UUID, thumbnail: Data) throws {
        guard var layout = try loadDashboard(id: id) else { return }
        layout.thumbnailData = thumbnail
        try saveDashboard(layout)
    }
}
