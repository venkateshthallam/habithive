import SwiftUI

struct WelcomeView: View {
    @State private var showAuth = false
    @State private var animateBlobs = false
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                themeManager.currentTheme.primaryGradient
                    .ignoresSafeArea()
                
                // Floating blobs animation
                FloatingBlobsView()
                    .opacity(0.3)
                
                VStack(spacing: HiveSpacing.xl) {
                    Spacer()
                    
                    // Logo
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 120, height: 120)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        Image(systemName: "hexagon.fill")
                            .font(.system(size: 60))
                            .foregroundColor(HiveColors.honeyGradientEnd)
                            .overlay(
                                Text("🐝")
                                    .font(.system(size: 40))
                            )
                    }
                    .scaleEffect(animateBlobs ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateBlobs)
                    
                    VStack(spacing: HiveSpacing.md) {
                        Text("Welcome to")
                            .font(HiveTypography.title2)
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("HabitHive")
                            .font(HiveTypography.largeTitle)
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    }
                    
                    Text("Build better habits with your personal\nbee colony. Track, grow, and thrive\ntogether!")
                        .font(HiveTypography.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, HiveSpacing.lg)
                    
                    Spacer()
                    
                    // Get Started Button
                    Button(action: { showAuth = true }) {
                        HStack {
                            Text("Get Started")
                                .font(HiveTypography.headline)
                                .foregroundColor(.white)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HiveSpacing.md)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                                .background(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, HiveSpacing.lg)
                    .padding(.bottom, HiveSpacing.xl)
                }
            }
            .navigationDestination(isPresented: $showAuth) { OnboardingFlowView() }
        }
        .onAppear {
            animateBlobs = true
        }
    }
}

// MARK: - Floating Blobs Animation
struct FloatingBlobsView: View {
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<6) { index in
                BlobShape()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: CGFloat.random(in: 60...120),
                           height: CGFloat.random(in: 60...120))
                    .position(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height)
                    )
                    .offset(
                        x: animate ? CGFloat.random(in: -30...30) : 0,
                        y: animate ? CGFloat.random(in: -30...30) : 0
                    )
                    .animation(
                        .easeInOut(duration: Double.random(in: 3...6))
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}

struct BlobShape: Shape {
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: 0.5 * width, y: 0))
        path.addCurve(
            to: CGPoint(x: width, y: 0.5 * height),
            controlPoint1: CGPoint(x: 0.9 * width, y: 0),
            controlPoint2: CGPoint(x: width, y: 0.1 * height)
        )
        path.addCurve(
            to: CGPoint(x: 0.5 * width, y: height),
            controlPoint1: CGPoint(x: width, y: 0.9 * height),
            controlPoint2: CGPoint(x: 0.9 * width, y: height)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: 0.5 * height),
            controlPoint1: CGPoint(x: 0.1 * width, y: height),
            controlPoint2: CGPoint(x: 0, y: 0.9 * height)
        )
        path.addCurve(
            to: CGPoint(x: 0.5 * width, y: 0),
            controlPoint1: CGPoint(x: 0, y: 0.1 * height),
            controlPoint2: CGPoint(x: 0.1 * width, y: 0)
        )
        
        return Path(path.cgPath)
    }
}


#Preview {
    WelcomeView()
}
