import SwiftUI

// MARK: - Toast Types

enum ToastType {
    case success
    case error
    case warning
    case info
    
    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error:   return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return ColorPalette.success
        case .error:   return ColorPalette.error
        case .warning: return ColorPalette.warning
        case .info:    return ColorPalette.info
        }
    }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: ToastType
    
    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Toast Manager

/// Global state manager orchestrating active system toast notifications.
/// Available app-wide as an @EnvironmentObject.
class ToastManager: ObservableObject {
    @Published var toasts: [Toast] = []
    
    /// Displays a new toast message. Capped at maximum 3 visible notifications.
    func show(message: String, type: ToastType) {
        let toast = Toast(message: message, type: type)
        
        // Cap visible toasts at 3
        if toasts.count >= 3 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                toasts.removeFirst()
            }
        }
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            toasts.append(toast)
        }
        
        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            if let index = self.toasts.firstIndex(where: { $0.id == toast.id }) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    self.toasts.remove(at: index)
                }
            }
        }
    }
}

// MARK: - Toast View Component

/// Individual notification banner presenting status icon, feedback message, and semantic styling.
struct ToastView: View {
    let toast: Toast
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.type.iconName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(toast.type.color)
            
            Text(toast.message)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ColorPalette.textPrimary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ColorPalette.cards)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ColorPalette.border, lineWidth: 1)
        )
    }
}

// MARK: - Toast Presenter Overlay

/// Container rendering the stack of toasts aligned at the bottom center.
struct ToastOverlayContainer: View {
    @EnvironmentObject var manager: ToastManager
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(manager.toasts) { toast in
                ToastView(toast: toast)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal:   .scale(scale: 0.9).combined(with: .opacity)
                        )
                    )
            }
        }
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false) // Let mouse click through to underlying cells
    }
}
