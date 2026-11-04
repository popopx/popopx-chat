// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct LoadingAnimationView: View {
    @State private var isAnimating = false
    @State private var rotationAngle = 0.0
    @State private var scale: CGFloat = 1.0
    
    var message: String = "Loading..."
    var showProgress: Bool = false
    @Binding var progress: Double
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated logo/indicator
            ZStack {
                // Outer ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                QuantumColors.accent.opacity(0.3),
                                QuantumColors.accentSecondary.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(rotationAngle))
                
                // Inner pulsing circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                QuantumColors.accent,
                                QuantumColors.accentSecondary
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .scaleEffect(scale)
                    .opacity(0.8)
                
                // Center icon
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            // Message text
            Text(message)
                .font(QuantumFonts.body)
                .foregroundColor(QuantumColors.textSecondary)
                .opacity(0.9)
            
            // Progress bar (optional)
            if showProgress {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(QuantumColors.surfaceElevated)
                            .frame(height: 8)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        QuantumColors.accent,
                                        QuantumColors.accentSecondary
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 8)
                .frame(maxWidth: 200)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Rotation animation
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        // Pulse animation
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            scale = 1.2
        }
    }
}

// MARK: - Splash Screen Loading View

struct SplashScreenLoadingView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    @State private var rotationAngle = 0.0
    
    var body: some View {
        ZStack {
            // Background
            QuantumColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Animated logo
                ZStack {
                    // Rotating ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    QuantumColors.accent.opacity(0.4),
                                    QuantumColors.accentSecondary.opacity(0.4),
                                    QuantumColors.accent.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(rotationAngle))
                    
                    // Logo
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    QuantumColors.accent,
                                    QuantumColors.accentSecondary
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                }
                
                // App name
                VStack(spacing: 8) {
                    Text("POPOPX")
                        .font(QuantumFonts.display)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    QuantumColors.accent,
                                    QuantumColors.accentSecondary
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(textOpacity)
                    
                    Text("Secure Messaging")
                        .font(QuantumFonts.body)
                        .foregroundColor(QuantumColors.textSecondary)
                        .opacity(textOpacity)
                }
                
                Spacer()
                
                // Loading indicator
                LoadingDotsView()
                    .opacity(textOpacity)
                    .padding(.bottom, 60)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Logo fade in and scale
        withAnimation(.easeOut(duration: 0.6)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }
        
        // Text fade in (delayed)
        withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
            textOpacity = 1.0
        }
        
        // Continuous rotation
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }
}

// MARK: - Loading Dots Animation

struct LoadingDotsView: View {
    @State private var dot1Opacity: Double = 0.3
    @State private var dot2Opacity: Double = 0.3
    @State private var dot3Opacity: Double = 0.3
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(QuantumColors.accent)
                .frame(width: 8, height: 8)
                .opacity(dot1Opacity)
            
            Circle()
                .fill(QuantumColors.accent)
                .frame(width: 8, height: 8)
                .opacity(dot2Opacity)
            
            Circle()
                .fill(QuantumColors.accent)
                .frame(width: 8, height: 8)
                .opacity(dot3Opacity)
        }
        .onAppear {
            startDotAnimations()
        }
    }
    
    private func startDotAnimations() {
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            dot1Opacity = 1.0
        }
        
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.2)) {
            dot2Opacity = 1.0
        }
        
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.4)) {
            dot3Opacity = 1.0
        }
    }
}

// MARK: - Progress Indicator

struct ProgressIndicatorView: View {
    var progress: Double
    var message: String = "Initializing..."
    
    var body: some View {
        VStack(spacing: 16) {
            // Circular progress
            ZStack {
                Circle()
                    .stroke(QuantumColors.surfaceElevated, lineWidth: 8)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [
                                QuantumColors.accent,
                                QuantumColors.accentSecondary
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)
                
                Text("\(Int(progress * 100))%")
                    .font(QuantumFonts.caption)
                    .foregroundColor(QuantumColors.textPrimary)
            }
            
            Text(message)
                .font(QuantumFonts.body)
                .foregroundColor(QuantumColors.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview("Loading Animation") {
    LoadingAnimationView(
        message: "Initializing database...",
        showProgress: true,
        progress: .constant(0.6)
    )
    .preferredColorScheme(.dark)
}

#Preview("Splash Screen") {
    SplashScreenLoadingView()
        .preferredColorScheme(.dark)
}

#Preview("Progress Indicator") {
    ProgressIndicatorView(progress: 0.75, message: "Loading messages...")
        .preferredColorScheme(.dark)
}
