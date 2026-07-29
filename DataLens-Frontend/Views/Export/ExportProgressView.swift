import SwiftUI

// MARK: - ExportProgressView

/// Full-overlay modal showing export progress, success, or error states.
/// Shown on top of any screen during an active export operation.
struct ExportProgressView: View {

    @ObservedObject var exportViewModel: ExportViewModel
    var onDismiss: () -> Void

    @State private var checkmarkScale: CGFloat  = 0.0
    @State private var checkmarkOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {} // Block clicks through backdrop

            // Modal Card
            VStack(spacing: 24) {
                progressGraphic

                Text(exportViewModel.currentStepMessage.isEmpty
                     ? exportViewModel.exportStatus.label
                     : exportViewModel.currentStepMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ColorPalette.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
                    .animation(.easeInOut, value: exportViewModel.currentStepMessage)

                actionButtons
            }
            .padding(32)
            .frame(width: 320)
            .background(ColorPalette.cards)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(ColorPalette.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 8)
        }
        .onChange(of: exportViewModel.exportStatus) { status in
            if case .success = status {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                    checkmarkScale   = 1.0
                    checkmarkOpacity = 1.0
                }
            } else {
                checkmarkScale   = 0.0
                checkmarkOpacity = 0.0
            }
        }
    }

    // MARK: - Progress Graphic

    @ViewBuilder
    private var progressGraphic: some View {
        switch exportViewModel.exportStatus {
        case .success:
            ZStack {
                Circle()
                    .fill(ColorPalette.success.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(ColorPalette.success)
                    .scaleEffect(checkmarkScale)
                    .opacity(checkmarkOpacity)
            }

        case .error:
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.red)
            }

        default:
            ZStack {
                // Track ring
                Circle()
                    .stroke(ColorPalette.border, lineWidth: 6)
                    .frame(width: 80, height: 80)

                // Progress arc
                Circle()
                    .trim(from: 0, to: exportViewModel.exportProgress)
                    .stroke(ColorPalette.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: exportViewModel.exportProgress)

                // Percentage label
                Text("\(Int(exportViewModel.exportProgress * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.accent)
            }
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch exportViewModel.exportStatus {
        case .success(let url):
            VStack(spacing: 10) {
                Button(action: { exportViewModel.presentSavePanel(for: url) }) {
                    Label("Save to Location...", systemImage: "square.and.arrow.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(ColorPalette.accent)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    Button(action: { exportViewModel.openFile(url: url) }) {
                        Label("Open File", systemImage: "arrow.up.right.square")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ColorPalette.success)
                    }
                    .buttonStyle(.plain)

                    Text("·").foregroundColor(ColorPalette.border)

                    Button(action: { exportViewModel.openInFinder(url: url) }) {
                        Label("Show in Finder", systemImage: "folder")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Button("Done") { onDismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(ColorPalette.textSecondary)
            }

        case .error(let msg):
            VStack(spacing: 10) {
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)

                HStack(spacing: 12) {
                    Button("Close") { onDismiss() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ColorPalette.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(ColorPalette.border.opacity(0.4))
                        .cornerRadius(6)
                }
            }

        default:
            Button(action: { exportViewModel.cancelExport(); onDismiss() }) {
                Text("Cancel")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ColorPalette.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(ColorPalette.border.opacity(0.3))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }
}
