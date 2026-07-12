import SwiftUI
import UniformTypeIdentifiers

/// ImportView handles uploading or dragging CSV files into the application
struct ImportView: View {
    @EnvironmentObject var dataViewModel: DataViewModel
    @ObservedObject var navigationViewModel: NavigationViewModel
    
    @State private var isTargeted = false
    @State private var isGlowAnimating = false
    @State private var isButtonHovered = false
    
    var body: some View {
        Group {
            if dataViewModel.currentDataSet != nil {
                // If a dataset is loaded, automatically show the grid table view
                DataTableView(navigationViewModel: navigationViewModel)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
            } else {
                VStack(spacing: 0) {
                    // Error state banner
                    if let error = dataViewModel.errorMessage {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                            
                            Text(error)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    dataViewModel.errorMessage = nil
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.25), lineWidth: 1)
                        )
                        .padding([.horizontal, .top], 24)
                    }
                    
                    Spacer()
                    
                    if dataViewModel.isLoading {
                        // Loading spinner state (in Accent color)
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                                .scaleEffect(1.5)
                            
                            Text("Parsing CSV dataset...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)
                        }
                    } else if dataViewModel.isImportSuccess {
                        // Success state green checkmark
                        VStack(spacing: 20) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(AppColors.success)
                                .shadow(color: AppColors.success.opacity(0.4), radius: 8, x: 0, y: 4)
                            
                            Text("Import successful!")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppColors.textPrimary)
                        }
                    } else {
                        // Standard drag and drop zone
                        VStack(spacing: 24) {
                            Image(systemName: "cloud.arrow.up.fill")
                                .font(.system(size: 60))
                                .foregroundColor(isTargeted ? AppColors.success : AppColors.accent)
                                .shadow(color: isTargeted ? AppColors.success.opacity(0.4) : AppColors.accent.opacity(0.2), radius: 8, x: 0, y: 4)
                            
                            VStack(spacing: 8) {
                                Text("Drag and drop your CSV file here")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("or")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Button(action: selectFile) {
                                Text("Browse Files")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isButtonHovered ? AppColors.accent.opacity(0.85) : AppColors.accent)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                    .shadow(color: AppColors.accent.opacity(0.3), radius: 6, x: 0, y: 3)
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isButtonHovered = hovering
                                }
                            }
                        }
                        .frame(maxWidth: 600, maxHeight: 400)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppColors.cards)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(
                                    isTargeted ? AppColors.success : AppColors.accent,
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .bevel, miterLimit: 10, dash: [8, 6], dashPhase: 0)
                                )
                        )
                        .shadow(
                            color: isTargeted ? AppColors.success.opacity(0.6) : (isGlowAnimating ? AppColors.accent.opacity(0.15) : AppColors.accent.opacity(0.35)),
                            radius: isTargeted ? 16 : (isGlowAnimating ? 12 : 8),
                            x: 0,
                            y: 0
                        )
                        .contentShape(Rectangle())
                        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
                            guard let provider = providers.first else { return false }
                            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                                var resolvedURL: URL?
                                if let data = item as? Data {
                                    resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
                                } else if let url = item as? URL {
                                    resolvedURL = url
                                } else if let string = item as? String {
                                    resolvedURL = URL(string: string)
                                }
                                
                                if let url = resolvedURL {
                                    DispatchQueue.main.async {
                                        dataViewModel.importCSV(url: url)
                                    }
                                }
                            }
                            return true
                        }
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.background)
                .onAppear {
                    // Activate pulsing animation when idle
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        isGlowAnimating = true
                    }
                }
            }
        }
    }
    
    /// Triggers the native NSOpenPanel for selecting a file
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                dataViewModel.importCSV(url: url)
            }
        }
    }
}
