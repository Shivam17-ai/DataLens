import SwiftUI

@main
struct DataLensApp: App {
    @StateObject private var dataViewModel = DataViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataViewModel)
        }
        // Force the macOS window resizing system to respect the bounds of ContentView (min 1200x800)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
