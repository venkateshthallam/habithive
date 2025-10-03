//
//  BeeLogoView.swift
//  HabitHive
//
//  Created by Venkatesh Thallam on 10/1/25.
//

import SwiftUI

struct BeeLogoView: View {
    @State private var leftWingRotation: Double = -20
    @State private var rightWingRotation: Double = 20

    var body: some View {
        ZStack {
            // Hexagon background
            HexagonShape()
                .fill(Color.white.opacity(0.2))
                .aspectRatio(1.0, contentMode: .fit)

            // Bee components
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                let scale = size / 300.0

                ZStack {
                    // Wings - animated
                    LeftWingShape()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 100 * scale, height: 60 * scale)
                        .offset(x: -65 * scale, y: -30 * scale)
                        .rotationEffect(.degrees(leftWingRotation), anchor: .trailing)

                    RightWingShape()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 100 * scale, height: 60 * scale)
                        .offset(x: 65 * scale, y: -30 * scale)
                        .rotationEffect(.degrees(rightWingRotation), anchor: .leading)

                    // Bee body
                    ZStack {
                        // Main body
                        Ellipse()
                            .fill(Color(hex: "2D2D2D"))
                            .frame(width: 150 * scale, height: 180 * scale)

                        // Yellow stripes
                        VStack(spacing: 30 * scale) {
                            RoundedRectangle(cornerRadius: 4 * scale)
                                .fill(Color(hex: "FFD700"))
                                .frame(width: 150 * scale, height: 20 * scale)

                            RoundedRectangle(cornerRadius: 4 * scale)
                                .fill(Color(hex: "FFD700"))
                                .frame(width: 150 * scale, height: 20 * scale)

                            RoundedRectangle(cornerRadius: 4 * scale)
                                .fill(Color(hex: "FFD700"))
                                .frame(width: 150 * scale, height: 20 * scale)
                        }
                        .offset(y: 10 * scale)

                        // Eyes
                        HStack(spacing: 50 * scale) {
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 25 * scale, height: 25 * scale)
                                Circle()
                                    .fill(.black)
                                    .frame(width: 16 * scale, height: 16 * scale)
                            }

                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 25 * scale, height: 25 * scale)
                                Circle()
                                    .fill(.black)
                                    .frame(width: 16 * scale, height: 16 * scale)
                            }
                        }
                        .offset(y: -40 * scale)
                    }

                    // Honey drops
                    HStack(spacing: 170 * scale) {
                        Circle()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 20 * scale, height: 20 * scale)

                        Circle()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 20 * scale, height: 20 * scale)
                    }
                    .offset(y: 120 * scale)
                }
                .frame(width: size, height: size)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .onAppear {
            startWingAnimation()
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

// Reusable flat-top hexagon for brand surfaces.
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let centerX = width / 2
        let centerY = height / 2
        let radius = min(width, height) / 2
        let adjustment = CGFloat.pi / 6 // rotate so flat sides top/bottom

        var path = Path()
        for index in 0..<6 {
            let angle = (CGFloat(index) * .pi / 3) - adjustment
            let point = CGPoint(
                x: centerX + radius * cos(angle),
                y: centerY + radius * sin(angle)
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        BeeLogoView()
            .frame(width: 200, height: 200)
    }
}
