import SwiftUI

/// Onboarding screen displaying walkthrough guides upon the app's first execution.
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @State private var currentPage = 0
    
    // Animation trigger flags
    @State private var logoScale = 0.5
    @State private var importOffset: CGFloat = 50
    @State private var chartsOffset: CGFloat = 60
    @State private var rocketOffset: CGFloat = 80
    
    var body: some View {
        ZStack {
            // Animated Gradient Background
            ColorPalette.onboardingBackground
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                // Top Header actions
                HStack {
                    Spacer()
                    if currentPage < 3 {
                        Button(action: { finishOnboarding() }) {
                            Text(Constants.Onboarding.skipButton)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(ColorPalette.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Tab View supporting swiping slides
                TabView(selection: $currentPage) {
                    // Slide 1: Welcome
                    VStack(spacing: 24) {
                        Image(systemName: "circle.grid.3x3.fill")
                            .font(.system(size: 80))
                            .foregroundColor(ColorPalette.success)
                            .scaleEffect(logoScale)
                            .onAppear {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                    logoScale = 1.0
                                }
                            }
                        
                        VStack(spacing: 8) {
                            Text(Constants.Onboarding.slide1Title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(ColorPalette.textPrimary)
                            Text(Constants.Onboarding.slide1Subtitle)
                                .font(.system(size: 15))
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                    }
                    .tag(0)
                    
                    // Slide 2: Import Files preview
                    VStack(spacing: 24) {
                        VStack(spacing: 0) {
                            // Mini illustration representing drag and drop
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6]))
                                    .foregroundColor(ColorPalette.accent)
                                    .frame(width: 180, height: 120)
                                
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(ColorPalette.success)
                                    .offset(y: importOffset)
                            }
                            .frame(height: 140)
                            .onAppear {
                                withAnimation(.spring(response: 0.8, dampingFraction: 0.65)) {
                                    importOffset = 0
                                }
                            }
                        }
                        
                        VStack(spacing: 8) {
                            Text(Constants.Onboarding.slide2Title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(ColorPalette.textPrimary)
                            Text(Constants.Onboarding.slide2Subtitle)
                                .font(.system(size: 14))
                                .foregroundColor(ColorPalette.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 340)
                        }
                    }
                    .tag(1)
                    
                    // Slide 3: Visualize charts flying in
                    VStack(spacing: 24) {
                        HStack(alignment: .bottom, spacing: 12) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ColorPalette.success)
                                .frame(width: 16, height: 60)
                                .offset(y: chartsOffset)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ColorPalette.accent)
                                .frame(width: 16, height: 100)
                                .offset(y: chartsOffset * 0.5)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ColorPalette.warning)
                                .frame(width: 16, height: 40)
                                .offset(y: chartsOffset * 0.8)
                        }
                        .frame(height: 120)
                        .onAppear {
                            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                                chartsOffset = 0
                            }
                        }
                        
                        VStack(spacing: 8) {
                            Text(Constants.Onboarding.slide3Title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(ColorPalette.textPrimary)
                            Text(Constants.Onboarding.slide3Subtitle)
                                .font(.system(size: 14))
                                .foregroundColor(ColorPalette.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 340)
                        }
                    }
                    .tag(2)
                    
                    // Slide 4: Done rocket lift off
                    VStack(spacing: 24) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 64))
                            .foregroundColor(ColorPalette.success)
                            .rotationEffect(.degrees(45))
                            .offset(y: rocketOffset)
                            .onAppear {
                                withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                                    rocketOffset = 0
                                }
                            }
                        
                        VStack(spacing: 8) {
                            Text(Constants.Onboarding.slide4Title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(ColorPalette.textPrimary)
                            Text(Constants.Onboarding.slide4Subtitle)
                                .font(.system(size: 14))
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                        
                        Button(action: { finishOnboarding() }) {
                            Text(Constants.Onboarding.doneButton)
                                .padding(.horizontal, 24)
                        }
                        .primaryStyle()
                        .padding(.top, 10)
                    }
                    .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                Spacer()
                
                // Bottom indicator dots and navigation actions
                HStack {
                    // Dot indicators
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? ColorPalette.success : ColorPalette.textSecondary.opacity(0.4))
                                .frame(width: 8, height: 8)
                                .scaleEffect(currentPage == index ? 1.2 : 1.0)
                                .animation(.spring(), value: currentPage)
                        }
                    }
                    
                    Spacer()
                    
                    if currentPage < 3 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: Constants.Animation.standard)) {
                                currentPage += 1
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text("Next")
                                    .font(.system(size: 13, weight: .bold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(ColorPalette.accent))
                            .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .frame(width: 600, height: 450)
        .background(ColorPalette.background)
    }
    
    private func finishOnboarding() {
        withAnimation(.easeInOut(duration: Constants.Animation.standard)) {
            hasCompletedOnboarding = true
        }
    }
}
