import SwiftUI
import UniformTypeIdentifiers

// Custom UTType for .xlsx (Open XML spreadsheet)
extension UTType {
    static let xlsx = UTType(importedAs: "org.openxmlformats.spreadsheetml.sheet")
}

/// ImportView handles uploading or dragging CSV and Excel files into DataLens
struct ImportView: View {
    @EnvironmentObject var dataViewModel: DataViewModel
    @ObservedObject var navigationViewModel: NavigationViewModel

    @State private var isTargeted      = false
    @State private var isGlowAnimating = false
    @State private var isButtonHovered = false

    var body: some View {
        Group {
            if dataViewModel.currentDataSet != nil {
                // Dataset ready — show data table
                DataTableView(navigationViewModel: navigationViewModel)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal:   .opacity.combined(with: .move(edge: .leading))
                    ))
            } else {
                dropZoneBody
            }
        }
    }

    // MARK: - Drop Zone Screen

    private var dropZoneBody: some View {
        VStack(spacing: 0) {
            // Auto-dismiss error banner — slides in from top
            if let error = dataViewModel.errorMessage {
                ErrorBanner(message: error) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dataViewModel.errorMessage = nil
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal:   .move(edge: .top).combined(with: .opacity)
                ))
                .padding([.horizontal, .top], 24)
            }

            Spacer()

            if dataViewModel.isLoading {
                loadingState
            } else if dataViewModel.isImportSuccess {
                successState
            } else {
                dropZoneCard
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isGlowAnimating = true
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                .scaleEffect(1.5)

            Text(dataViewModel.currentFileType == .csv
                 ? "Parsing CSV dataset…"
                 : "Parsing Excel workbook…")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
        }
    }

    // MARK: - Success State

    private var successState: some View {
        VStack(spacing: 20) {
            Image(systemName: dataViewModel.currentFileType.iconName)
                .font(.system(size: 60))
                .foregroundColor(AppColors.success)
                .shadow(color: AppColors.success.opacity(0.4), radius: 8, x: 0, y: 4)

            Text(dataViewModel.successMessage ?? "Import successful!")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Main Drop Zone Card

    private var dropZoneCard: some View {
        VStack(spacing: 28) {
            // Upload cloud icon
            Image(systemName: "cloud.arrow.up.fill")
                .font(.system(size: 60))
                .foregroundColor(isTargeted ? AppColors.success : AppColors.accent)
                .shadow(
                    color: isTargeted
                        ? AppColors.success.opacity(0.4)
                        : AppColors.accent.opacity(0.2),
                    radius: 8, x: 0, y: 4
                )

            VStack(spacing: 6) {
                Text("Drag and drop your CSV or Excel file here")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                // Accepted file type badges
                HStack(spacing: 8) {
                    FileTypeBadge(label: "CSV",  color: AppColors.success)
                    FileTypeBadge(label: "XLSX", color: AppColors.success)
                }

                Text("or")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.top, 4)
            }

            // Browse Files button
            Button(action: selectFile) {
                Text("Browse Files")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isButtonHovered
                                  ? AppColors.accent.opacity(0.85)
                                  : AppColors.accent)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: AppColors.accent.opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) { isButtonHovered = hovering }
            }

            // Sheet picker — only visible when a multi-sheet Excel is loaded
            if dataViewModel.availableSheets.count > 1 {
                SheetPickerView()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(40)
        .frame(maxWidth: 620)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.cards))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isTargeted ? AppColors.success : AppColors.accent,
                    style: StrokeStyle(
                        lineWidth: 2, lineCap: .round, lineJoin: .bevel,
                        miterLimit: 10, dash: [8, 6], dashPhase: 0
                    )
                )
        )
        .shadow(
            color: isTargeted
                ? AppColors.success.opacity(0.6)
                : (isGlowAnimating ? AppColors.accent.opacity(0.15) : AppColors.accent.opacity(0.35)),
            radius: isTargeted ? 16 : (isGlowAnimating ? 12 : 8),
            x: 0, y: 0
        )
        .contentShape(Rectangle())
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                var resolvedURL: URL?
                if let data   = item as? Data   { resolvedURL = URL(dataRepresentation: data, relativeTo: nil) }
                else if let u = item as? URL    { resolvedURL = u }
                else if let s = item as? String { resolvedURL = URL(string: s) }

                if let url = resolvedURL {
                    DispatchQueue.main.async { dataViewModel.importFile(url: url) }
                }
            }
            return true
        }
    }

    // MARK: - File Picker (NSOpenPanel)

    /// Opens a native file-open panel accepting CSV and XLSX files
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories    = false
        panel.canChooseFiles          = true
        panel.allowedContentTypes     = [
            .commaSeparatedText,
            .xlsx,
            UTType(filenameExtension: "xlsx") ?? .data
        ]
        panel.message = "Choose a CSV or Excel (.xlsx) file to import"

        if panel.runModal() == .OK, let url = panel.url {
            dataViewModel.importFile(url: url)
        }
    }
}

// MARK: - Supporting Subviews

/// Pill-shaped badge displaying accepted file format labels
struct FileTypeBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(color.opacity(0.4), lineWidth: 1)
            )
    }
}

/// Sliding red error banner with optional close action and 4-second auto-dismiss
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15))
                .foregroundColor(.red)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.red.opacity(0.10))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.25), lineWidth: 1)
        )
    }
}
