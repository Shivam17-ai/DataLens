import SwiftUI

@main
struct DataLensApp: App {
    @StateObject private var dataViewModel      = DataViewModel()
    @StateObject private var toastManager       = ToastManager()
    @StateObject private var crossFilterManager = CrossFilterManager()
    @StateObject private var keyboardManager    = KeyboardShortcutsManager()
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataViewModel)
                .environmentObject(toastManager)
                .environmentObject(crossFilterManager)
                .environmentObject(keyboardManager)
                .environmentObject(accessibilityManager)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            // macOS File Menu integration
            CommandGroup(replacing: .newItem) {
                Button("New Dashboard") {
                    keyboardManager.onNewDashboard?()
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Open Dashboard...") {
                    keyboardManager.onOpenDashboard?()
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Divider()
                
                Button("Save Dashboard") {
                    keyboardManager.onSaveDashboard?()
                }
                .keyboardShortcut("s", modifiers: .command)
            }
            
            CommandGroup(replacing: .importExport) {
                Button("Export Current View...") {
                    keyboardManager.onExport?()
                }
                .keyboardShortcut("e", modifiers: .command)
            }
            
            // macOS View Menu integration
            CommandGroup(before: .sidebar) {
                Button("Search and Focus") {
                    keyboardManager.onFocusSearch?()
                }
                .keyboardShortcut("f", modifiers: .command)
                
                Divider()
            }
            
            // macOS Help Menu integration
            CommandGroup(replacing: .help) {
                Button("DataLens Help") {
                    if let url = URL(string: Constants.App.githubURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Button("Keyboard Shortcuts") {
                    keyboardManager.showShortcutsPanel = true
                }
                .keyboardShortcut("?", modifiers: [])
                
                Button("Report a Bug...") {
                    if let url = URL(string: "\(Constants.App.githubURL)/issues") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
