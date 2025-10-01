import SwiftUI

struct HoneyPourAnimationView: View {
    let habit: Habit
    let onComplete: () -> Void

    @State private var honeyDropOffset: CGFloat = -200
    @State private var hexagonBounce: CGFloat = 0
    @State private var pourProgress: CGFloat = 0
    @State private var showCheckmark = false
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
                Spacer()

                // Hexagon container with honey drop animation
                ZStack {
                    // Falling honey drop
                    if honeyDropOffset > -200 && honeyDropOffset < 50 {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [HiveColors.honeyGradientStart, HiveColors.honeyGradientEnd],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 30, height: 30)
                                .shadow(color: HiveColors.honeyGradientEnd.opacity(0.5), radius: 8, x: 0, y: 4)

                            Text("🍯")
                                .font(.system(size: 24))
                        }
                        .offset(y: honeyDropOffset)
                    }

                    // Background hexagon
                    HexagonShape()
                        .stroke(habit.color.opacity(0.3), lineWidth: 4)
                        .frame(width: 150, height: 150)

                    // Filling hexagon (honey pour effect)
                    HexagonShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    HiveColors.honeyGradientStart.opacity(0.8),
                                    HiveColors.honeyGradientEnd
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
                .offset(y: hexagonBounce)


                // Completion text
                VStack(spacing: HiveSpacing.xs) {
                    Text(showCheckmark ? "Great job!" : "Logging...")
                        .font(HiveTypography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(HiveColors.beeBlack)

                    if habit.type == .counter {
                        Text("\(habit.targetPerDay) / \(habit.targetPerDay)")
                            .font(HiveTypography.body)
                            .foregroundColor(HiveColors.slateText)
                    }
                }

                Spacer()
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
        // Step 1: Honey drop falls from top (0 to 0.6s)
        withAnimation(.easeIn(duration: 0.6)) {
            honeyDropOffset = 0
        }

        // Step 2: Impact and hexagon bounce (at 0.6s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Haptic feedback on impact
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

            // Hexagon bounces down and back up
            withAnimation(.easeOut(duration: 0.15)) {
                hexagonBounce = 8
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    hexagonBounce = 0
                }
            }

            // Honey fills the hexagon
            withAnimation(.easeOut(duration: 0.8)) {
                pourProgress = 1.0
            }
        }

        // Step 3: Show completion (at 1.6s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showCheckmark = true
            }

            // Success haptic
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)

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