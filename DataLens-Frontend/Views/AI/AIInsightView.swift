import SwiftUI
import AppKit

// MARK: - AIInsightView

struct AIInsightView: View {

    @StateObject private var aiViewModel = AIViewModel()
    @State private var inputText: String = ""
    @State private var apiKeyInput: String = ""
    @State private var isValidatingKey: Bool = false
    @State private var showSettingsModal: Bool = false

    // Optional environment dataset / filters
    var dataset: DataSet? = nil
    var filters: FilterState? = nil

    var body: some View {
        VStack(spacing: 0) {
            if !aiViewModel.apiKeyConfigured {
                apiKeySetupCard
            } else {
                mainAIInterface
            }
        }
        .background(ColorPalette.background)
        .sheet(isPresented: $showSettingsModal) {
            apiKeySettingsSheet
        }
        .onAppear {
            if aiViewModel.chartSuggestions.isEmpty && dataset != nil {
                Task {
                    await aiViewModel.generateChartSuggestions(dataset: dataset)
                }
            }
        }
    }

    // MARK: - API Key Setup Screen (First Time)

    private var apiKeySetupCard: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(ColorPalette.accent.opacity(0.15))
                    .frame(width: 90, height: 90)
                Image(systemName: "key.fill")
                    .font(.system(size: 40))
                    .foregroundColor(ColorPalette.accent)
            }

            VStack(spacing: 8) {
                Text("Connect Groq AI")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(ColorPalette.textPrimary)

                Text("Add your free Groq API key to unlock AI powered insights, automated chart suggestions, and natural language analytics.")
                    .font(.system(size: 13))
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundColor(ColorPalette.accent)
                    TextField("Enter your Groq API key (gsk_...)", text: $apiKeyInput)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(ColorPalette.textPrimary)
                        .textFieldStyle(.plain)
                }
                .padding(12)
                .background(ColorPalette.background)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ColorPalette.border, lineWidth: 1))

                HStack {
                    Button(action: openGroqConsole) {
                        HStack(spacing: 4) {
                            Text("Get Free API Key")
                                .font(.system(size: 11, weight: .semibold))
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(ColorPalette.success)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if let err = aiViewModel.error {
                        Text(err)
                            .font(.system(size: 10))
                            .foregroundColor(ColorPalette.warning)
                    }
                }
            }
            .frame(maxWidth: 420)

            Button(action: validateAndSaveKey) {
                HStack(spacing: 8) {
                    if isValidatingKey {
                        ProgressView().scaleEffect(0.7).tint(.white)
                    }
                    Text(isValidatingKey ? "Validating..." : "Save and Continue")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty ? ColorPalette.border : ColorPalette.accent)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty || isValidatingKey)

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Main AI Interface (Split Screen)

    private var mainAIInterface: some View {
        VStack(spacing: 0) {
            // Top Toolbar
            topToolbar

            Divider().background(ColorPalette.border)

            HStack(spacing: 0) {
                // Left Panel: Insight Categories, History & Suggestions
                leftPanel
                    .frame(width: 280)

                Divider().background(ColorPalette.border)

                // Right Panel: Chat Stream & Messages
                rightPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Top Toolbar

    private var topToolbar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(ColorPalette.accent)
                    .font(.system(size: 16))
                Text("DataLens AI Insights")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ColorPalette.textPrimary)

                Text("llama3-70b-8192")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.success)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(ColorPalette.success.opacity(0.15))
                    .cornerRadius(4)
            }

            Spacer()

            HStack(spacing: 12) {
                // Key Settings Button
                Button(action: { showSettingsModal = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .buttonStyle(.plain)
                .help("API Key Settings")

                // Export Conversation Button
                Button(action: exportConversation) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13))
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Export Conversation")

                // Clear Conversation Button
                Button(action: { aiViewModel.clearConversation() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Clear History")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ColorPalette.sidebar)
    }

    // MARK: - Left Panel (Categories, History & Suggestions)

    private var leftPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // ── Quick Insights ───────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Text("QUICK INSIGHTS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorPalette.textSecondary)

                    VStack(spacing: 6) {
                        ForEach(InsightType.allCases) { type in
                            Button(action: {
                                Task {
                                    await aiViewModel.runQuickInsight(type, dataset: dataset, filters: filters)
                                }
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: type.iconName)
                                        .font(.system(size: 12))
                                        .foregroundColor(ColorPalette.accent)
                                        .frame(width: 20)
                                    Text(type.rawValue)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(ColorPalette.textPrimary)
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(ColorPalette.background.opacity(0.5))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorPalette.border.opacity(0.5), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider().background(ColorPalette.border)

                // ── Smart Chart Suggestions ──────────────────────────────
                if !aiViewModel.chartSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SMART CHART SUGGESTIONS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(ColorPalette.textSecondary)

                        ForEach(aiViewModel.chartSuggestions) { suggestion in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(ColorPalette.success)
                                    Text(suggestion.chartType.rawValue)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(ColorPalette.textPrimary)
                                }
                                Text(suggestion.reasoning)
                                    .font(.system(size: 10))
                                    .foregroundColor(ColorPalette.textSecondary)
                                    .lineLimit(3)
                            }
                            .padding(10)
                            .background(ColorPalette.cards)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorPalette.border, lineWidth: 1))
                        }
                    }

                    Divider().background(ColorPalette.border)
                }

                // ── Recent Queries History ──────────────────────────────
                if !aiViewModel.queryHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("RECENT QUERIES")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(ColorPalette.textSecondary)
                            Spacer()
                        }

                        VStack(spacing: 4) {
                            ForEach(aiViewModel.queryHistory, id: \.self) { query in
                                Button(action: {
                                    Task {
                                        await aiViewModel.sendMessage(query, dataset: dataset, filters: filters)
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 10))
                                            .foregroundColor(ColorPalette.textSecondary)
                                        Text(query)
                                            .font(.system(size: 10))
                                            .foregroundColor(ColorPalette.textPrimary)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(14)
        }
        .background(ColorPalette.sidebar)
    }

    // MARK: - Right Panel (Chat Interface & Streaming)

    private var rightPanel: some View {
        VStack(spacing: 0) {

            // Pinned Messages Banner (if any)
            if !aiViewModel.pinnedMessages.isEmpty {
                pinnedBanner
            }

            // Message Scroll View
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        if aiViewModel.messages.isEmpty {
                            emptyChatState
                        } else {
                            ForEach(aiViewModel.messages) { msg in
                                chatMessageBubble(msg)
                                    .id(msg.id)
                            }

                            // 3 Dots Typing Indicator while waiting for response
                            if aiViewModel.isLoading && aiViewModel.streamingText.isEmpty {
                                typingIndicatorBubble
                            }
                        }
                    }
                    .padding(20)
                }
                .onChange(of: aiViewModel.messages.count) { _ in
                    if let lastId = aiViewModel.messages.last?.id {
                        withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                    }
                }
                .onChange(of: aiViewModel.streamingText) { _ in
                    if let lastId = aiViewModel.messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }

            // Input View
            ChatInputView(
                text: $inputText,
                isLoading: aiViewModel.isLoading,
                onSend: {
                    let msg = inputText
                    inputText = ""
                    Task {
                        await aiViewModel.sendMessage(msg, dataset: dataset, filters: filters)
                    }
                }
            )
        }
    }

    // MARK: - Chat Message Bubbles

    @ViewBuilder
    private func chatMessageBubble(_ msg: AIMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {

            if msg.role == .user {
                Spacer()
            } else {
                // AI Brain Icon
                ZStack {
                    Circle()
                        .fill(ColorPalette.accent.opacity(0.2))
                        .frame(width: 28, height: 28)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14))
                        .foregroundColor(ColorPalette.accent)
                }
            }

            VStack(alignment: msg.role == .user ? .trailing : .leading, spacing: 4) {
                Text(msg.content.isEmpty ? "Thinking..." : msg.content)
                    .font(.system(size: 12))
                    .foregroundColor(msg.role == .user ? .white : ColorPalette.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(msg.role == .user ? ColorPalette.accent : ColorPalette.cards)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(msg.isPinned ? Color(hex: "#F59E0B") ?? ColorPalette.warning : ColorPalette.border.opacity(0.4), lineWidth: msg.isPinned ? 2 : 1)
                    )

                // Timestamp & Hover Action Buttons
                HStack(spacing: 8) {
                    Text(msg.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 9))
                        .foregroundColor(ColorPalette.textSecondary.opacity(0.7))

                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(msg.content, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy message")

                    Button(action: { aiViewModel.pinMessage(id: msg.id) }) {
                        Image(systemName: msg.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 9))
                            .foregroundColor(msg.isPinned ? Color(hex: "#F59E0B") ?? ColorPalette.warning : ColorPalette.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Pin message")
                }
            }

            if msg.role == .assistant {
                Spacer()
            }
        }
    }

    // MARK: - 3-Dot Typing Indicator

    private var typingIndicatorBubble: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(ColorPalette.accent.opacity(0.2))
                    .frame(width: 28, height: 28)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14))
                    .foregroundColor(ColorPalette.accent)
            }

            HStack(spacing: 4) {
                ForEach(0..<3) { idx in
                    Circle()
                        .fill(ColorPalette.accent)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(ColorPalette.cards)
            .cornerRadius(16)

            Spacer()
        }
    }

    // MARK: - Pinned Banner

    private var pinnedBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(aiViewModel.pinnedMessages) { msg in
                HStack(spacing: 8) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#F59E0B") ?? ColorPalette.warning)
                    Text(msg.content)
                        .font(.system(size: 10))
                        .foregroundColor(ColorPalette.textPrimary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "#F59E0B")?.opacity(0.1) ?? ColorPalette.warning.opacity(0.1))
                .border(Color(hex: "#F59E0B") ?? ColorPalette.warning, width: 1)
            }
        }
    }

    private var emptyChatState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(ColorPalette.accent.opacity(0.6))
            Text("Ask DataLens AI Anything")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ColorPalette.textPrimary)
            Text("Select a Quick Insight from the left sidebar or type a custom question below.")
                .font(.system(size: 12))
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Spacer()
        }
    }

    // MARK: - Settings Modal Sheet

    private var apiKeySettingsSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(ColorPalette.accent)
                Text("Groq API Key Settings")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ColorPalette.textPrimary)
                Spacer()
                Button("Done") { showSettingsModal = false }
                    .buttonStyle(.plain)
                    .foregroundColor(ColorPalette.accent)
            }

            Divider().background(ColorPalette.border)

            TextField("gsk_...", text: $apiKeyInput)
                .font(.system(size: 12, design: .monospaced))
                .padding(8)
                .background(ColorPalette.background)
                .cornerRadius(6)

            HStack {
                Button("Clear Key") {
                    aiViewModel.saveApiKey("")
                    showSettingsModal = false
                }
                .foregroundColor(ColorPalette.warning)
                .buttonStyle(.plain)

                Spacer()

                Button("Update Key") {
                    validateAndSaveKey()
                    showSettingsModal = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(ColorPalette.accent)
                .cornerRadius(6)
            }
        }
        .padding(20)
        .frame(width: 380, height: 220)
        .background(ColorPalette.cards)
    }

    // MARK: - Helpers

    private func openGroqConsole() {
        if let url = URL(string: "https://console.groq.com/keys") {
            NSWorkspace.shared.open(url)
        }
    }

    private func validateAndSaveKey() {
        isValidatingKey = true
        Task {
            let valid = await aiViewModel.validateApiKey(apiKeyInput)
            isValidatingKey = false
            if valid {
                aiViewModel.saveApiKey(apiKeyInput)
            } else {
                aiViewModel.error = "Failed to validate API Key. Please check the key and internet connection."
            }
        }
    }

    private func exportConversation() {
        let text = aiViewModel.exportConversation()
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "datalens_ai_export.md"
        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
