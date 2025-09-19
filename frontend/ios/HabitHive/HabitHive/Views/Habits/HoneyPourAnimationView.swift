import SwiftUI

struct HoneyPourAnimationView: View {
    let habit: Habit
    let onComplete: () -> Void
    
    @State private var pourProgress: CGFloat = 0
    @State private var showCheckmark = false
    @State private var beeRotation: Double = 0
    @State private var honeyDrops: [HoneyDrop] = []
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // Allow tap to dismiss after animation
                    if showCheckmark {
                        onComplete()
                    }
                }
            
            VStack(spacing: HiveSpacing.xl) {
                // Animated Bee
                Text("🐝")
                    .font(.system(size: 80))
                    .rotationEffect(.degrees(beeRotation))
                    .offset(y: showCheckmark ? -20 : 0)
                    .animation(.easeInOut(duration: 0.5), value: showCheckmark)
                
                // Hexagon container
                ZStack {
                    // Background hexagon
                    HexagonShape()
                        .stroke(habit.color.opacity(0.3), lineWidth: 4)
                        .frame(width: 150, height: 150)
                    
                    // Filling hexagon (honey pour effect)
                    HexagonShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    habit.color.opacity(0.8),
                                    habit.color
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 150, height: 150)
                        .mask(
                            VStack {
                                Spacer()
                                Rectangle()
                                    .frame(height: 150 * pourProgress)
                            }
                        )
                    
                    // Habit emoji
                    Text(habit.emoji ?? "✨")
                        .font(.system(size: 60))
                        .scaleEffect(showCheckmark ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showCheckmark)
                    
                    // Checkmark overlay
                    if showCheckmark {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(HiveColors.mintSuccess)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                // Honey drops animation
                ZStack {
                    ForEach(honeyDrops) { drop in
                        HoneyDropView(drop: drop)
                    }
                }
                .frame(height: 100)
                
                // Completion text
                VStack(spacing: HiveSpacing.xs) {
                    Text(showCheckmark ? "Great job!" : "Logging...")
                        .font(HiveTypography.headline)
                        .foregroundColor(.white)
                    
                    if habit.type == .counter {
                        Text("\(habit.targetPerDay) / \(habit.targetPerDay)")
                            .font(HiveTypography.body)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(HiveSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.xlarge)
                    .fill(Color.white)
                    .shadow(radius: 20)
            )
            .scaleEffect(showCheckmark ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showCheckmark)
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Bee rotation animation
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            beeRotation = 360
        }
        
        // Pour animation
        withAnimation(.easeInOut(duration: 1.5)) {
            pourProgress = 1.0
        }
        
        // Generate honey drops
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                let drop = HoneyDrop(
                    id: UUID(),
                    startX: CGFloat.random(in: -30...30),
                    delay: Double(i) * 0.1
                )
                honeyDrops.append(drop)
            }
        }
        
        // Show completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring()) {
                showCheckmark = true
            }
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Auto dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                onComplete()
            }
        }
    }
}

// MARK: - Honey Drop
struct HoneyDrop: Identifiable {
    let id: UUID
    let startX: CGFloat
    let delay: Double
}

struct HoneyDropView: View {
    let drop: HoneyDrop
    @State private var offsetY: CGFloat = 0
    @State private var opacity: Double = 1
    
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [HiveColors.honeyGradientStart, HiveColors.honeyGradientEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 8, height: 8)
            .offset(x: drop.startX, y: offsetY)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 1.0).delay(drop.delay)) {
                    offsetY = 100
                    opacity = 0
                }
            }
    }
}

// MARK: - Hexagon Shape
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let centerX = width / 2
        let centerY = height / 2
        let radius = min(width, height) / 2
        
        var path = Path()
        
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 6
            let x = centerX + radius * cos(angle)
            let y = centerY + radius * sin(angle)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}

#Preview {
    HoneyPourAnimationView(
        habit: Habit(
            id: "1",
            userId: "1",
            name: "Drink Water",
            emoji: "💧",
            colorHex: "#34C8ED",
            type: .counter,
            targetPerDay: 8,
            scheduleDaily: true,
            scheduleWeekmask: 127,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        ),
        onComplete: {}
    )
}