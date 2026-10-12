// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import Combine

/// Manages cyber/native theme toggle and active art piece background.
@MainActor
final class CyberThemeManager: ObservableObject {
    static let shared = CyberThemeManager()

    @Published var isCyberMode: Bool = false
    @Published var activeArtPiece: ArtPiece? = nil
    @Published var activeArtImage: UIImage? = nil

    private let userDefaults = UserDefaults.standard
    private let cyberModeKey = "im.popopx.cyberMode"
    private let activePieceIdKey = "im.popopx.activeArtPieceId"

    private init() {
        self.isCyberMode = userDefaults.bool(forKey: cyberModeKey)
        if let pieceIdString = userDefaults.string(forKey: activePieceIdKey),
           let pieceId = UUID(uuidString: pieceIdString) {
            // Try to find the piece in vault
            if let piece = ArtVault.shared.pieces.first(where: { $0.id == pieceId }) {
                self.activeArtPiece = piece
                loadArtImage(for: piece)
            }
        }
    }

    /// Toggle between native and cyber mode.
    func toggleCyberMode() {
        isCyberMode.toggle()
        userDefaults.set(isCyberMode, forKey: cyberModeKey)
    }

    /// Set cyber mode explicitly.
    func setCyberMode(_ enabled: Bool) {
        isCyberMode = enabled
        userDefaults.set(isCyberMode, forKey: cyberModeKey)
    }

    /// Set active art piece as chat background.
    func setActiveArtPiece(_ piece: ArtPiece?) {
        activeArtPiece = piece
        if let piece = piece {
            userDefaults.set(piece.id.uuidString, forKey: activePieceIdKey)
            loadArtImage(for: piece)
        } else {
            activeArtImage = nil
            userDefaults.removeObject(forKey: activePieceIdKey)
        }
    }

    /// Load art image from vault for background use.
    private func loadArtImage(for piece: ArtPiece) {
        Task {
            do {
                let image = try await ArtVault.shared.load(piece)
                await MainActor.run {
                    self.activeArtImage = image
                }
            } catch {
                await MainActor.run {
                    self.activeArtImage = nil
                }
            }
        }
    }
}

// MARK: - Background View Modifier

struct CyberBackgroundModifier: ViewModifier {
    @ObservedObject var themeManager = CyberThemeManager.shared

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    if let image = themeManager.activeArtImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .opacity(0.15)
                            .blur(radius: 20)
                            .transition(.opacity)
                    } else {
                        Color(.systemBackground)
                    }
                }
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: themeManager.activeArtPiece)
            )
    }
}

extension View {
    func cyberBackground() -> some View {
        modifier(CyberBackgroundModifier())
    }
}
