import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    
    // UserDefaults persisted states
    @AppStorage(Constants.AppStorageKeys.appTheme) var appTheme: String = "Dark"
    @AppStorage(Constants.AppStorageKeys.appLanguage) var appLanguage: String = "English"
    @AppStorage(Constants.AppStorageKeys.defaultDelimiter) var defaultDelimiter: String = ","
    @AppStorage(Constants.AppStorageKeys.defaultEncoding) var defaultEncoding: String = "UTF-8"
    @AppStorage(Constants.AppStorageKeys.defaultColorTheme) var defaultColorTheme: String = "Classic"
    @AppStorage(Constants.AppStorageKeys.chartAnimationSpeed) var chartAnimationSpeed: Double = 0.25
    @AppStorage(Constants.AppStorageKeys.groqAPIKey) var groqAPIKey: String = ""
    @AppStorage(Constants.AppStorageKeys.groqModel) var groqModel: String = "llama3-70b-8192"
    @AppStorage(Constants.AppStorageKeys.defaultExportFormat) var defaultExportFormat: String = "PDF"
    @AppStorage(Constants.AppStorageKeys.defaultExportQuality) var defaultExportQuality: Double = 0.8
    @AppStorage(Constants.AppStorageKeys.enableDebugMode) var enableDebugMode: Bool = false
    @AppStorage(Constants.AppStorageKeys.enablePerformanceHUD) var enablePerformanceHUD: Bool = false
    @AppStorage(Constants.AppStorageKeys.enableReduceMotion) var enableReduceMotion: Bool = false
    
    @State private var activeTab: SettingsSection = .general
    
    enum SettingsSection: String, CaseIterable, Identifiable {
        case general   = "General"
        case data      = "Data"
        case charts    = "Charts"
        case ai        = "AI Insights"
        case export    = "Export"
        case advanced  = "Advanced"
        case about     = "About"
        
        var id: String { rawValue }
        
        var iconName: String {
            switch self {
            case .general:  return "slider.horizontal.3"
            case .data:     return "cylinder.split.1x2"
            case .charts:    return "chart.bar"
            case .ai:        return "sparkles"
            case .export:    return "square.and.arrow.up"
            case .advanced:  return "cpu"
            case .about:     return "info.circle"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Settings Sidebar
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(Constants.Typography.title)
                    .foregroundColor(ColorPalette.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 12)
                
                Divider().background(ColorPalette.border).padding(.horizontal, 16)
                
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(SettingsSection.allCases) { section in
                            Button(action: { activeTab = section }) {
                                HStack(spacing: 12) {
                                    Image(systemName: section.iconName)
                                        .font(.system(size: 13))
                                        .frame(width: 18)
                                    Text(section.rawValue)
                                        .font(Constants.Typography.body)
                                    Spacer()
                                }
                                .foregroundColor(activeTab == section ? .white : ColorPalette.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: Constants.Radius.small)
                                        .fill(activeTab == section ? ColorPalette.accent : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
                
                Spacer()
            }
            .frame(width: 200)
            .background(ColorPalette.sidebar)
            
            Rectangle().fill(ColorPalette.border).frame(width: 1)
            
            // Detail pane
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        detailContent
                    }
                    .padding(32)
                }
                .background(ColorPalette.background)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    @ViewBuilder
    private var detailContent: some View {
        switch activeTab {
        case .general:
            Text("General Settings")
                .font(Constants.Typography.title)
                .foregroundColor(ColorPalette.textPrimary)
            
            Form {
                Picker("Theme", selection: $appTheme) {
                    Text("Dark").tag("Dark")
                    Text("Light").tag("Light")
                    Text("System").tag("System")
                }
                
                Picker("Language", selection: $appLanguage) {
                    Text("English").tag("English")
                    Text("Spanish").tag("Spanish")
                    Text("French").tag("French")
                }
            }
            .pickerStyle(.radioGroup)
            
            Button("Reset to Defaults") {
                appTheme = "Dark"
                appLanguage = "English"
            }
            .buttonStyle(.bordered)
            .padding(.top, 10)
            
        case .data:
            Text("Data Configuration")
                .font(Constants.Typography.title)
                .foregroundColor(ColorPalette.textPrimary)
            
            Form {
                Picker("Default Delimiter", selection: $defaultDelimiter) {
                    Text("Comma ( , )").tag(",")
                    Text("Tab ( \\t )").tag("\t")
                    Text("Semicolon ( ; )").tag(";")
                }
                
                Picker("Default Encoding", selection: $defaultEncoding) {
                    Text("UTF-8").tag("UTF-8")
                    Text("ASCII").tag("ASCII")
                    Text("ISO-8859-1").tag("ISO-8859-1")
                }
            }
            .pickerStyle(.menu)
            
            Button("Reset to Defaults") {
                defaultDelimiter = ","
                defaultEncoding = "UTF-8"
            }
            .buttonStyle(.bordered)
            .padding(.top, 10)
            
        case .charts:
            Text("Chart Visual Defaults")
                .font(Constants.Typography.title)
                .foregroundColor(ColorPalette.textPrimary)
            
            Form {
                Picker("Color Theme", selection: $defaultColorTheme) {
                    Text("Classic").tag("Classic")
                    Text("Vibrant").tag("Vibrant")
                    Text("Monochrome").tag("Monochrome")
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chart Animation Speed: \(chartAnimationSpeed.formatted(decimals: 2))s")
                    Slider(value: $chartAnimationSpeed, in: 0.0...1.0)
                }
            }
            
            Button("Reset to Defaults") {
                defaultColorTheme = "Classic"
                chartAnimationSpeed = 0.25
            }
            .buttonStyle(.bordered)
            .padding(.top, 10)
            
        case .ai:
            Text("AI Insights Setup")
                .font(Constants.Typography.title)
                .foregroundColor(ColorPalette.textPrimary)
            
            Form {
                SecureField("Groq API Key", text: $groqAPIKey)
                    .textFieldStyle(.roundedBorder)
                
                Picker("Model Selection", selection: $groqModel) {
                    Text("llama3-70b-8192").tag("llama3-70b-8192")
                    Text("llama3-8b-8192").tag("llama3-8b-8192")
                }
                .pickerStyle(.menu)
            }
            
            Button("Reset API Config") {
                groqAPIKey = ""
                groqModel = "llama3-70b-8192"
            }
            .buttonStyle(.bordered)
            .padding(.top, 10)
            
        case .export:
            Text("Export Defaults")
                .font(Constants.Typography.title)
                .foregroundColor(ColorPalette.textPrimary)
            
            Form {
                Picker("Default Export Format", selection: $defaultExportFormat) {
                    Text("PDF").tag("PDF")
                    Text("PNG").tag("PNG")
                    Text("CSV").tag("CSV")
                }
                .pickerStyle(.segmented)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("JPEG/Image Quality: \(Int(defaultExportQuality * 100))%")
                    Slider(value: $defaultExportQuality, in: 0.1...1.0)
                }
            }
            
            Button("Reset Export Defaults") {
                defaultExportFormat = "PDF"
                defaultExportQuality = 0.8
            }
            .buttonStyle(.bordered)
            .padding(.top, 10)
            
        case .advanced:
            Text("Advanced & Debug Options")
                .font(Constants.Typography.title)
                .foregroundColor(ColorPalette.textPrimary)
            
            Form {
                Toggle("Enable Developer Debug Mode", isOn: $enableDebugMode)
                Toggle("Show Diagnostics Performance HUD", isOn: $enablePerformanceHUD)
                Toggle("Accessibility Reduce Motion Settings", isOn: $enableReduceMotion)
            }
            .toggleStyle(.checkbox)
            
            Button("Reset Advanced Options") {
                enableDebugMode = false
                enablePerformanceHUD = false
                enableReduceMotion = false
            }
            .buttonStyle(.bordered)
            .padding(.top, 10)
            
        case .about:
            Text("About DataLens")
                .font(Constants.Typography.title)
                .foregroundColor(ColorPalette.textPrimary)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "square.fill.and.line.down.and.arrow.up")
                        .font(.system(size: 40))
                        .foregroundColor(ColorPalette.success)
                    VStack(alignment: .leading) {
                        Text(Constants.App.name)
                            .font(Constants.Typography.headline)
                        Text("Version \(Constants.App.version) (\(Constants.App.buildNumber))")
                            .font(Constants.Typography.caption)
                    }
                }
                
                Text(Constants.App.tagline)
                    .font(Constants.Typography.body)
                    .foregroundColor(ColorPalette.textSecondary)
                
                Text("Designed and built natively for macOS. All data is processed locally on your device for absolute privacy.")
                    .font(Constants.Typography.caption)
                    .foregroundColor(ColorPalette.textSecondary)
            }
            .padding(16)
            .background(ColorPalette.cards)
            .cornerRadius(Constants.Radius.medium)
        }
    }
}
