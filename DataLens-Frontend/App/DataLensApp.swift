import SwiftUI

@main
struct DataLensApp: App {
    @StateObject private var dataViewModel = DataViewModel()
    @StateObject private var toastManager = ToastManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataViewModel)
                .environmentObject(toastManager)
        }
        // Force the macOS window resizing system to respect the bounds of ContentView (min 1200x800)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
