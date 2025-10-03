#if canImport(UIKit)
import UIKit
#endif
import SwiftUI

// This file now provides an inline "Honey Tap" effect that can be overlaid
// on any tappable target (like the Bee button). It plays a honey fill ripple
// and bursts honey-colored confetti. Keep the type name to avoid breaking imports.

struct HoneyPourAnimationView: View {
    // Backwards-compatible wrapper retained for previews if needed.
    let habit: Habit
    let onComplete: () -> Void

    var body: some View {
        // Present a compact celebratory state for previews; apps should use HoneyTapEffectView inline.
        VStack(spacing: HiveSpacing.md) {
            Text(habit.emoji ?? "🍯").font(.system(size: 40))
            Text("Logged!").font(HiveTypography.headline)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .onAppear { onComplete() }
    }
}

// MARK: - Inline Honey Tap Effect
struct HoneyTapEffectView: View {
    let accentColor: Color
    let size: CGFloat
    @Binding var trigger: Int // increment to play
    var confettiCount: Int = 12

    @State private var play = false
    @State private var ripple = false
    @State private var particles: [HoneyParticle] = []
    @State private var fill: CGFloat = 0

    var body: some View {
        ZStack {
            // Expanding ripple ring
            Circle()
                .stroke(accentColor.opacity(0.25), lineWidth: 3)
                .frame(width: size, height: size)
                .scaleEffect(ripple ? 1.6 : 0.6)
                .opacity(ripple ? 0 : 1)
                .animation(.easeOut(duration: 0.55), value: ripple)

            // Honey wave fill inside the target
            HoneyWaveFill(progress: fill, colorTop: HiveColors.honeyGradientStart, colorBottom: HiveColors.honeyGradientEnd)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .opacity(0.85)

            // Confetti particles
            ZStack {
                ForEach(particles) { p in
                    HoneyParticleView(p: p)
                }
            }
            .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
        .scaleEffect(play ? 1.04 : 1.0)
        .onChange(of: trigger) { _, _ in
            start()
        }
        .onAppear {
            // Initialize as empty state
            fill = 0
        }
    }

    private func start() {
        // Haptics
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        #endif

        // Reset and play
        particles = HoneyParticle.randomBurst(count: confettiCount, radius: size * 0.6, color: accentColor)
        ripple = false
        play = true
        withAnimation(.easeOut(duration: 0.55)) { ripple = true }

        // Wave fill
        fill = 0
        withAnimation(.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.7)) { fill = 1 }

        // Launch particles
        for idx in particles.indices {
            particles[idx].launch()
        }

        // Success haptic a beat later
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        }

        // Clear after a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.2)) {
                play = false
                ripple = false
                particles.removeAll()
                fill = 0
            }
        }
    }
}

// MARK: - Honey Wave Fill (Animatable)
struct HoneyWaveFill: View {
    var progress: CGFloat // 0..1
    var colorTop: Color
    var colorBottom: Color

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let fillHeight = max(0, min(1, progress)) * h
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [colorTop, colorBottom], startPoint: .top, endPoint: .bottom)
                    .mask(
                        VStack(spacing: 0) {
                            Spacer()
                            WaveShape(phase: .pi * 2 * (1 - progress))
                                .fill(Color.white)
                                .frame(height: fillHeight)
                        }
                    )
                    .animation(.easeOut(duration: 0.7), value: progress)
            }
        }
    }
}

struct WaveShape: Shape {
    var phase: CGFloat
    var amplitude: CGFloat = 6
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let midY: CGFloat = 0
        p.move(to: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: 0, y: midY))
        let cycles: CGFloat = 1.5
        for x in stride(from: 0, through: w, by: 2) {
            let relative = x / w
            let y = midY + sin(relative * .pi * 2 * cycles + phase) * amplitude
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        return p
    }
}

// MARK: - Confetti Particles
struct HoneyParticle: Identifiable {
    let id = UUID()
    let angle: CGFloat // radians
    let speed: CGFloat
    let spin: CGFloat
    let color: Color
    let startScale: CGFloat
    let shape: HoneyParticleShape
    var position: CGPoint = .zero
    var life: Double = 1.0

    static func randomBurst(count: Int, radius: CGFloat, color: Color) -> [HoneyParticle] {
        (0..<count).map { _ in
            HoneyParticle(
                angle: CGFloat.random(in: 0..<(2 * .pi)),
                speed: CGFloat.random(in: radius * 0.6...radius * 1.1),
                spin: CGFloat.random(in: -2...2),
                color: [HiveColors.honeyGradientStart, HiveColors.honeyGradientEnd, color].randomElement()!,
                startScale: CGFloat.random(in: 0.6...1.2),
                shape: Bool.random() ? .hex : .circle
            )
        }
    }

    mutating func launch() {
        // No-op placeholder; view drives animation
    }
}

struct HoneyParticleView: View {
    @State var p: HoneyParticle
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 1
    @State private var rotation: Angle = .degrees(0)

    var body: some View {
        GeometryReader { geo in
            Group {
                switch p.shape {
                case .hex:
                    Polygon(sides: 6)
                        .fill(p.color)
                case .circle:
                    Circle()
                        .fill(p.color)
                }
            }
            .scaleEffect(p.startScale)
            .rotationEffect(rotation)
            .opacity(opacity)
            .offset(offset)
            .onAppear { animate(in: geo.size) }
        }
    }

    private func animate(in size: CGSize) {
        let dx = cos(p.angle) * p.speed
        let dy = sin(p.angle) * p.speed * 0.7 + 12 // slight gravity

        withAnimation(.easeOut(duration: 0.8)) {
            offset = CGSize(width: dx, height: -dy)
            rotation = .radians(Double(p.spin))
            opacity = 0
        }
    }
}

enum HoneyParticleShape {
    case hex
    case circle
}

struct Polygon: InsettableShape {
    var sides: Int
    var insetAmount: CGFloat = 0
    func path(in rect: CGRect) -> Path {
        guard sides >= 3 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - insetAmount
        var path = Path()
        for i in 0..<sides {
            let angle = (Double(i) / Double(sides)) * 2 * Double.pi - Double.pi / 2
            let pt = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
    func inset(by amount: CGFloat) -> some InsettableShape { var cp = self; cp.insetAmount += amount; return cp }
}

// Keep a lightweight preview for Xcode canvas
#Preview {
    VStack {
        ZStack {
            Circle().fill(Color.gray.opacity(0.15)).frame(width: 64, height: 64)
            HoneyTapEffectView(accentColor: Color(hex: "#FFB703"), size: 64, trigger: .constant(0))
        }
        Text("Tap effect sits here")
    }
}
