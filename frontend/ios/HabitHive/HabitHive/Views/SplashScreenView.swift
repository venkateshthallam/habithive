//
//  SplashScreenView.swift
//  HabitHive
//
//  Created by Venkatesh Thallam on 10/1/25.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var leftWingRotation: Double = -20
    @State private var rightWingRotation: Double = 20
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Animated bee logo
                ZStack {
                    // Hexagon background
                    HexagonShape()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 300, height: 300)

                    // Bee components
                    ZStack {
                        // Wings - animated
                        LeftWingShape()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 100, height: 60)
                            .offset(x: -65, y: -30)
                            .rotationEffect(.degrees(leftWingRotation), anchor: .trailing)

                        RightWingShape()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 100, height: 60)
                            .offset(x: 65, y: -30)
                            .rotationEffect(.degrees(rightWingRotation), anchor: .leading)

                        // Bee body
                        ZStack {
                            // Main body
                            Ellipse()
                                .fill(Color(hex: "2D2D2D"))
                                .frame(width: 150, height: 180)

                            // Yellow stripes
                            VStack(spacing: 30) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "FFD700"))
                                    .frame(width: 150, height: 20)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "FFD700"))
                                    .frame(width: 150, height: 20)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "FFD700"))
                                    .frame(width: 150, height: 20)
                            }
                            .offset(y: 10)

                            // Eyes
                            HStack(spacing: 50) {
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 25, height: 25)
                                    Circle()
                                        .fill(.black)
                                        .frame(width: 16, height: 16)
                                }

                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 25, height: 25)
                                    Circle()
                                        .fill(.black)
                                        .frame(width: 16, height: 16)
                                }
                            }
                            .offset(y: -40)
                        }

                        // Honey drops
                        HStack(spacing: 170) {
                            Circle()
                                .fill(Color.white.opacity(0.4))
                                .frame(width: 20, height: 20)

                            Circle()
                                .fill(Color.white.opacity(0.4))
                                .frame(width: 20, height: 20)
                        }
                        .offset(y: 120)
                    }
                }
                .frame(width: 300, height: 300)

                // App name
                Text("HabitHive")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(isAnimating ? 1 : 0)
            }
        }
        .onAppear {
            startWingAnimation()
            withAnimation(.easeIn(duration: 0.5).delay(0.3)) {
                isAnimating = true
            }
        }
    }

    private func startWingAnimation() {
        withAnimation(
            .easeInOut(duration: 0.3)
            .repeatForever(autoreverses: true)
        ) {
            leftWingRotation = -50
            rightWingRotation = 50
        }
    }
}

// MARK: - Custom Shapes

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

struct LeftWingShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect)
        return path
    }
}

struct RightWingShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect)
        return path
    }
}

#Preview {
    SplashScreenView()
}
