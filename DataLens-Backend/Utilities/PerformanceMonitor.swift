import Foundation
import SwiftUI
import os.signpost

// MARK: - PerformanceMonitor

/// Reusable diagnostics utility for measuring, throttling, and debugging runtime events.
@MainActor
final class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published var fps: Int = 60
    @Published var memoryMB: Double = 0.0
    @Published var activeOperations: Int = 0
    
    private var lastFPSUpdate = Date()
    private var frameCount = 0
    private var link: CVDisplayLink?
    
    private init() {
        startTracking()
    }
    
    /// Synchronously measure the execution block and issue logs if it exceeds 100ms.
    func measure<T>(label: String, block: () -> T) -> T {
        activeOperations += 1
        let start = DispatchTime.now()
        let result = block()
        let end = DispatchTime.now()
        activeOperations -= 1
        
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000.0
        
        if timeInterval > Constants.Performance.slowOperationThreshold {
            print("⚠️ [DataLens Performance] '\(label)' was slow! Took \(timeInterval.formatted(decimals: 1))ms")
        }
        return result
    }
    
    private func startTracking() {
        // Track memory usage periodically
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryUsage()
            }
        }
        
        // Setup display link for FPS tracking
        var displayLink: CVDisplayLink?
        CVDisplayLinkCreateWithActiveDisplays(&displayLink)
        if let link = displayLink {
            self.link = link
            CVDisplayLinkSetOutputCallback(link, { (_, _, _, _, _, userData) -> CVReturn in
                let mySelf = Unmanaged<PerformanceMonitor>.fromOpaque(userData!).takeUnretainedValue()
                mySelf.tickFrame()
                return kCVReturnSuccess
            }, Unmanaged.passUnretained(self).toOpaque())
            CVDisplayLinkStart(link)
        }
    }
    
    private func tickFrame() {
        frameCount += 1
        let now = Date()
        let elapsed = now.timeIntervalSince(lastFPSUpdate)
        if elapsed >= 1.0 {
            let calculatedFPS = Int(Double(frameCount) / elapsed)
            Task { @MainActor in
                self.fps = calculatedFPS
            }
            frameCount = 0
            lastFPSUpdate = now
        }
    }
    
    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            self.memoryMB = Double(info.resident_size) / 1024.0 / 1024.0
        }
    }
    
    deinit {
        if let link = link {
            CVDisplayLinkStop(link)
        }
    }
}

// MARK: - Performance HUD Overlay

struct PerformanceOverlayView: View {
    @ObservedObject var monitor = PerformanceMonitor.shared
    @AppStorage(Constants.AppStorageKeys.enablePerformanceHUD) var showHUD: Bool = false
    
    var body: some View {
        if showHUD {
            VStack(alignment: .leading, spacing: 6) {
                Text("DIAGNOSTICS")
                    .font(Constants.Typography.eyebrow)
                    .foregroundColor(ColorPalette.success)
                
                HStack(spacing: 12) {
                    Label("\(monitor.fps) FPS", systemImage: "bolt.heart.fill")
                    Label("\(monitor.memoryMB.formatted(decimals: 1)) MB", systemImage: "memorychip")
                    Label("\(monitor.activeOperations) Active Ops", systemImage: "cpu")
                }
                .font(Constants.Typography.small)
                .foregroundColor(ColorPalette.textPrimary)
            }
            .padding(10)
            .background(ColorPalette.cards.opacity(0.85))
            .cornerRadius(Constants.Radius.medium)
            .overlay(RoundedRectangle(cornerRadius: Constants.Radius.medium).stroke(ColorPalette.border, lineWidth: 1))
            .padding(16)
        }
    }
}
