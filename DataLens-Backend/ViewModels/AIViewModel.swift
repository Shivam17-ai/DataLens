import SwiftUI
import Combine

// MARK: - Message Role Enum

enum MessageRole: String, Codable {
    case system
    case user
    case assistant
}

// MARK: - AI Message Model

struct AIMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        isPinned: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isPinned = isPinned
    }
}

// MARK: - Chart Suggestion Model

struct ChartSuggestion: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let chartType: ChartType
    let reasoning: String
    let suggestedXColumn: String?
    let suggestedYColumn: String?
}

// MARK: - Pre-built Insight Types

enum InsightType: String, CaseIterable, Identifiable {
    case summarizeData      = "Summarise My Data"
    case findAnomalies      = "Find Anomalies"
    case showKeyTrends      = "Show Key Trends"
    case compareCategories  = "Compare Categories"
    case predictNextValues  = "Predict Next Values"
    case findCorrelations   = "Find Correlations"
    case dataQualityReport  = "Data Quality Report"
    case topPerformers      = "Top Performers"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .summarizeData:     return "doc.text.magnifyingglass"
        case .findAnomalies:     return "exclamationmark.triangle"
        case .showKeyTrends:     return "chart.line.uptrend.xyaxis"
        case .compareCategories: return "chart.bar.doc.horizontal"
        case .predictNextValues: return "sparkles"
        case .findCorrelations:  return "point.3.connected.trianglepath.dotted"
        case .dataQualityReport: return "checkmark.shield"
        case .topPerformers:     return "trophy.fill"
        }
    }

    var promptText: String {
        switch self {
        case .summarizeData:
            return "Provide a comprehensive summary of this dataset. Include: key statistics, distribution of main columns, notable patterns, and 3 key takeaways."
        case .findAnomalies:
            return "Analyse this dataset for anomalies and outliers. Identify unusual values, unexpected patterns, and data quality issues. Be specific about which rows and columns are affected."
        case .showKeyTrends:
            return "Identify the key trends in this dataset. Look for patterns over time if date columns exist, growth rates, seasonal patterns, and correlations between columns."
        case .compareCategories:
            return "Compare the different categories in this dataset. Which categories perform best? Which underperform? What are the key differences between them?"
        case .predictNextValues:
            return "Based on the patterns in this data, what are your predictions for future values? Identify the trend direction and provide estimated ranges."
        case .findCorrelations:
            return "Identify correlations between columns in this dataset. Which variables are strongly related? Are there surprising relationships?"
        case .dataQualityReport:
            return "Generate a data quality report for this dataset. Check for: missing values, duplicates, outliers, inconsistent formats, and data integrity issues."
        case .topPerformers:
            return "Identify the top performing items in this dataset across all relevant metrics. Provide a ranked list with specific values."
        }
    }
}

// MARK: - AIViewModel

final class AIViewModel: ObservableObject {

    // MARK: Published State

    @Published var messages: [AIMessage] = []
    @Published var isLoading: Bool = false
    @Published var isStreaming: Bool = false
    @Published var streamingText: String = ""
    @Published var apiKeyConfigured: Bool = false
    @Published var error: String? = nil
    @Published var pinnedMessages: [AIMessage] = []
    @Published var queryHistory: [String] = []
    @Published var chartSuggestions: [ChartSuggestion] = []

    // MARK: Private Storage Keys

    private let apiKeyStorageKey = "groq_api_key"
    private let historyStorageKey = "datalens_query_history"

    // MARK: Init

    init() {
        checkApiKey()
        loadQueryHistory()
    }

    // MARK: - API Key Management

    func checkApiKey() {
        if let key = loadApiKey(), !key.trimmingCharacters(in: .whitespaces).isEmpty {
            apiKeyConfigured = true
        } else {
            apiKeyConfigured = false
        }
    }

    func loadApiKey() -> String? {
        if let stored = UserDefaults.standard.string(forKey: apiKeyStorageKey),
           !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return stored
        }

        // Fallback: Read from .env file in working directory or bundle
        let envPaths = [
            Bundle.main.bundlePath + "/.env",
            FileManager.default.currentDirectoryPath + "/.env",
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".env").path
        ]

        for path in envPaths {
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                let lines = content.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("GROQ_API_KEY=") {
                        let val = String(trimmed.dropFirst("GROQ_API_KEY=".count))
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'\n\r\t "))
                        if !val.isEmpty && val != "your_groq_api_key_here" {
                            return val
                        }
                    }
                }
            }
        }

        return nil
    }

    func saveApiKey(_ key: String) {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(clean, forKey: apiKeyStorageKey)
        apiKeyConfigured = !clean.isEmpty
        error = nil
    }

    func validateApiKey(_ key: String) async -> Bool {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }

        do {
            let testMessage = [GroqMessage(role: "user", content: "Hello")]
            _ = try await GroqService.shared.sendMessage(
                messages: testMessage,
                systemPrompt: "You are a test assistant. Reply 'OK'.",
                apiKey: clean,
                maxRetries: 1
            )
            return true
        } catch {
            return false
        }
    }

    // MARK: - System Prompt Construction

    func buildSystemPrompt(
        dataset: DataSet?,
        filters: FilterState? = nil,
        chartConfig: ChartConfig? = nil
    ) -> String {
        var context = "You are DataLens AI, an expert data analyst assistant.\n"

        guard let ds = dataset else {
            context += "No dataset is currently loaded. Provide general data analytics guidance."
            return context
        }

        context += "\n--- DATASET CONTEXT ---\n"
        context += "Dataset Name: \(ds.name)\n"
        context += "Total Rows: \(ds.rowCount), Total Columns: \(ds.columnCount)\n\n"

        context += "Columns:\n"
        for col in ds.columns {
            context += "- \(col.name) (\(col.type.rawValue))\n"
        }

        // Summary stats for numeric columns
        context += "\nNumeric Column Summary:\n"
        for col in ds.columns where col.type == .number {
            let vals = ds.rows.compactMap { Double("\($0.values[col.name] ?? "")") }
            if !vals.isEmpty {
                let minV = vals.min() ?? 0
                let maxV = vals.max() ?? 0
                let avgV = vals.reduce(0, +) / Double(vals.count)
                context += "- \(col.name): min=\(String(format: "%.2f", minV)), max=\(String(format: "%.2f", maxV)), avg=\(String(format: "%.2f", avgV))\n"
            }
        }

        // Active filters
        if let f = filters {
            context += "\n--- ACTIVE FILTERS ---\n"
            if let dr = f.dateRange {
                context += "- Date Range on \(dr.columnName): \(dr.from) to \(dr.to)\n"
            }
            if !f.searchText.isEmpty {
                context += "- Search Text: '\(f.searchText)'\n"
            }
            for (col, vals) in f.selectedCategories where !vals.isEmpty {
                context += "- Category filter on \(col): [\(vals.joined(separator: ", "))]\n"
            }
        }

        // Chart config context if present
        if let c = chartConfig {
            context += "\n--- CURRENT CHART CONFIGURATION ---\n"
            context += "Chart Type: \(c.chartType.rawValue), Title: '\(c.title)'\n"
            context += "X-Axis: \(c.xAxisColumn ?? "none"), Y-Axis: \(c.yAxisColumn ?? "none")\n"
        }

        // Sample data (first 10 rows)
        context += "\n--- SAMPLE DATA (First 10 Rows) ---\n"
        let sampleRows = ds.rows.prefix(10)
        for (idx, r) in sampleRows.enumerated() {
            let rowDict = r.values.map { "\($0.key): \($0.value)" }.joined(separator: " | ")
            context += "Row \(idx + 1): \(rowDict)\n"
        }

        context += "\nAlways provide specific, actionable insights based on the actual data. Format responses clearly with bullet points where appropriate."
        return context
    }

    // MARK: - Send Message / Stream

    @MainActor
    func sendMessage(
        _ text: String,
        dataset: DataSet? = nil,
        filters: FilterState? = nil,
        chartConfig: ChartConfig? = nil
    ) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let apiKey = loadApiKey(), !apiKey.isEmpty else {
            error = "Please configure your Groq API key in settings."
            return
        }

        // Record User Message
        let userMsg = AIMessage(role: .user, content: trimmed)
        messages.append(userMsg)
        addToHistory(trimmed)

        isLoading = true
        isStreaming = true
        streamingText = ""
        error = nil

        let systemPrompt = buildSystemPrompt(dataset: dataset, filters: filters, chartConfig: chartConfig)
        let groqMessages = messages.map { GroqMessage(role: $0.role.rawValue, content: $0.content) }

        // Placeholder AI Message
        let aiMsgId = UUID()
        let placeholderMsg = AIMessage(id: aiMsgId, role: .assistant, content: "")
        messages.append(placeholderMsg)

        do {
            try await GroqService.shared.streamMessage(
                messages: groqMessages,
                systemPrompt: systemPrompt,
                apiKey: apiKey
            ) { [weak self] chunk in
                Task { @MainActor in
                    self?.streamingText += chunk
                    if let idx = self?.messages.firstIndex(where: { $0.id == aiMsgId }) {
                        self?.messages[idx].content = self?.streamingText ?? ""
                    }
                }
            }

            isLoading = false
            isStreaming = false

        } catch {
            isLoading = false
            isStreaming = false
            self.error = error.localizedDescription
            if let idx = messages.firstIndex(where: { $0.id == aiMsgId }) {
                messages[idx].content = "⚠️ Error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Quick Insight Action

    @MainActor
    func runQuickInsight(
        _ type: InsightType,
        dataset: DataSet?,
        filters: FilterState? = nil
    ) async {
        await sendMessage(type.promptText, dataset: dataset, filters: filters)
    }

    // MARK: - Smart Chart Suggestions

    @MainActor
    func generateChartSuggestions(dataset: DataSet?) async {
        guard let ds = dataset, let apiKey = loadApiKey(), !apiKey.isEmpty else { return }

        let prompt = """
        Analyze this dataset structure and suggest up to 3 best chart visualizations.
        Columns: \(ds.columns.map { "\($0.name) (\($0.type.rawValue))" }.joined(separator: ", "))

        Respond strictly in valid JSON format:
        [
          {
            "chartType": "Bar",
            "reasoning": "Reason here",
            "suggestedXColumn": "ColName",
            "suggestedYColumn": "ColName"
          }
        ]
        Valid chartTypes: Bar, Line, Pie, Area, Scatter, Heatmap, Treemap, Waterfall, Funnel, Gauge.
        """

        do {
            let res = try await GroqService.shared.sendMessage(
                messages: [GroqMessage(role: "user", content: prompt)],
                systemPrompt: "You are a JSON chart recommendation engine. Output raw JSON only.",
                apiKey: apiKey
            )

            // Clean json response
            var jsonStr = res.trimmingCharacters(in: .whitespacesAndNewlines)
            if jsonStr.hasPrefix("```json") { jsonStr = String(jsonStr.dropFirst(7)) }
            if jsonStr.hasSuffix("```") { jsonStr = String(jsonStr.dropLast(3)) }

            if let data = jsonStr.data(using: .utf8),
               let items = try? JSONDecoder().decode([ChartSuggestionDTO].self, from: data) {
                self.chartSuggestions = items.compactMap { dto in
                    guard let type = ChartType(rawValue: dto.chartType) else { return nil }
                    return ChartSuggestion(
                        chartType: type,
                        reasoning: dto.reasoning,
                        suggestedXColumn: dto.suggestedXColumn,
                        suggestedYColumn: dto.suggestedYColumn
                    )
                }
            }
        } catch {
            print("Chart suggestion parse error: \(error)")
        }
    }

    // MARK: - Chart Insight Generator

    @MainActor
    func generateChartInsight(for config: ChartConfig, dataset: DataSet?) async -> String {
        guard let apiKey = loadApiKey(), !apiKey.isEmpty else {
            return "Please set your Groq API key in settings."
        }

        let systemPrompt = buildSystemPrompt(dataset: dataset, chartConfig: config)
        let prompt = "Explain what this chart '\(config.title)' shows, highlight key findings, and suggest 2 potential actions or improvements."

        do {
            return try await GroqService.shared.sendMessage(
                messages: [GroqMessage(role: "user", content: prompt)],
                systemPrompt: systemPrompt,
                apiKey: apiKey
            )
        } catch {
            return "Error generating chart insight: \(error.localizedDescription)"
        }
    }

    // MARK: - History & Pinning

    func clearConversation() {
        messages.removeAll()
        pinnedMessages.removeAll()
        error = nil
    }

    func pinMessage(id: UUID) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].isPinned.toggle()
            if messages[idx].isPinned {
                if !pinnedMessages.contains(where: { $0.id == id }) {
                    pinnedMessages.append(messages[idx])
                }
            } else {
                pinnedMessages.removeAll(where: { $0.id == id })
            }
        }
    }

    func exportConversation() -> String {
        var export = "# DataLens AI Conversation Export\n"
        export += "Date: \(Date())\n\n"

        for msg in messages {
            let roleLabel = msg.role == .user ? "User" : "DataLens AI"
            export += "### \(roleLabel) (\(msg.timestamp.formatted()))\n"
            export += "\(msg.content)\n\n"
        }
        return export
    }

    private func addToHistory(_ query: String) {
        queryHistory.removeAll(where: { $0 == query })
        queryHistory.insert(query, at: 0)
        if queryHistory.count > 10 { queryHistory.removeLast() }
        saveQueryHistory()
    }

    private func saveQueryHistory() {
        UserDefaults.standard.set(queryHistory, forKey: historyStorageKey)
    }

    private func loadQueryHistory() {
        queryHistory = UserDefaults.standard.stringArray(forKey: historyStorageKey) ?? []
    }
}

// MARK: - DTO for JSON Decoding Chart Suggestions

private struct ChartSuggestionDTO: Decodable {
    let chartType: String
    let reasoning: String
    let suggestedXColumn: String?
    let suggestedYColumn: String?
}
