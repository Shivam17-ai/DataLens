import SwiftUI

@main
struct DataLensApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Force the macOS window resizing system to respect the bounds of ContentView (min 1200x800)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
