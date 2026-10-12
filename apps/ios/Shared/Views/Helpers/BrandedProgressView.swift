//
//  BrandedProgressView.swift
//  POPOPX
//
//  Branded loading indicator with theme-aware colors and smooth animations.
//  Replaces generic ProgressView spinners throughout the app.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct BrandedProgressView: View {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var text: String? = nil
    var size: CGFloat = 32
    
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            ZStack {
                Circle()
                    .strokeBorder(theme.colors.primary.opacity(0.15), lineWidth: 2)
                    .frame(width: size, height: size)
                
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                theme.colors.primary.opacity(0.3),
                                theme.colors.primary,
                                theme.colors.primary.opacity(0.8)
                            ]),
                            center: .center,
                            startAngle: .degrees(rotation),
                            endAngle: .degrees(rotation + 270)
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(rotation))
            }
            .onAppear {
                if reduceMotion { return }
                withAnimation(
                    .linear(duration: 1.2)
                    .repeatForever(autoreverses: false)
                ) {
                    rotation = 360
                }
            }
            
            // Optional loading text
            if let text = text {
                Text(text)
                    .font(DesignTokens.fontCaption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .popopxBranded()
    }
}

// MARK: - Compact variant for inline usage

struct BrandedProgressViewCompact: View {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var size: CGFloat = 20
    
    @State private var rotation: Double = 0
    
    var body: some View {
        Circle()
            .strokeBorder(
                LinearGradient(
                    colors: [theme.colors.primary.opacity(0.3), theme.colors.primary],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 2
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                if reduceMotion { return }
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Preview

struct BrandedProgressView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BrandedProgressView(text: "Loading...")
                .previewLayout(.sizeThatFits)
                .padding()
            
            BrandedProgressViewCompact()
                .previewLayout(.sizeThatFits)
                .padding()
            
            BrandedProgressView(size: 48)
                .previewLayout(.sizeThatFits)
                .padding()
        }
        .background(Color.black.opacity(0.1))
    }
}
