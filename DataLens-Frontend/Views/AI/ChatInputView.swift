import SwiftUI

struct ChatInputView: View {

    @Binding var text: String
    var isLoading: Bool
    var onSend: () -> Void

    @State private var includeDatasetContext: Bool = true
    @State private var includeChartContext: Bool = true
    @State private var includeFilterContext: Bool = true

    private let maxCharacters = 2000

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // ── Context Pills ─────────────────────────────────────────────
            HStack(spacing: 8) {
                contextPill(title: "Dataset Context", icon: "tablecells", isSelected: $includeDatasetContext)
                contextPill(title: "Chart Context", icon: "chart.bar", isSelected: $includeChartContext)
                contextPill(title: "Filter Context", icon: "line.3.horizontal.decrease.circle", isSelected: $includeFilterContext)

                Spacer()

                // Character Counter
                Text("\(text.count)/\(maxCharacters)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(text.count > maxCharacters ? ColorPalette.warning : ColorPalette.textSecondary)
            }

            // ── Input Box & Send Button ────────────────────────────────────
            HStack(alignment: .bottom, spacing: 10) {

                // TextEditor / TextField Container
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Ask anything about your data... (Shift+Enter for new line)")
                            .font(.system(size: 12))
                            .foregroundColor(ColorPalette.textSecondary.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    }

                    TextEditor(text: $text)
                        .font(.system(size: 12))
                        .foregroundColor(ColorPalette.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 38, maxHeight: 120)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .onChange(of: text) { newValue in
                            if newValue.count > maxCharacters {
                                text = String(newValue.prefix(maxCharacters))
                            }
                        }
                }
                .background(ColorPalette.background.opacity(0.6))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ColorPalette.border, lineWidth: 1))

                // Send Button
                Button(action: onSend) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(canSend ? ColorPalette.accent : ColorPalette.border)
                            .frame(width: 38, height: 38)

                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSend || isLoading)
            }
        }
        .padding(12)
        .background(ColorPalette.cards)
        .overlay(Rectangle().frame(height: 1).foregroundColor(ColorPalette.border), alignment: .top)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count <= maxCharacters
    }

    @ViewBuilder
    private func contextPill(title: String, icon: String, isSelected: Binding<Bool>) -> some View {
        Button(action: { isSelected.wrappedValue.toggle() }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(isSelected.wrappedValue ? .white : ColorPalette.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected.wrappedValue ? ColorPalette.accent.opacity(0.8) : ColorPalette.background.opacity(0.4))
            .cornerRadius(12)
            .overlay(
                Capsule()
                    .stroke(isSelected.wrappedValue ? ColorPalette.accent : ColorPalette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
