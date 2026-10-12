// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import Combine

struct GlobalSquareView: View {
    @ObservedObject private var manager = GlobalBroadcastManager.shared
    @State private var showComposer = false
    @State private var composeText = ""
    @State private var tickerDate = Date()

    // Callback to navigate back to home (chats tab)
    var onBackToHome: (() -> Void)? = nil
    var embedded: Bool = false

    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if embedded {
                contentView
            } else {
                NavigationStack {
                    contentView
                }
            }
        }
        .popopxBranded()
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            if !embedded {
                HStack {
                    Button {
                        onBackToHome?()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            ZStack {
                if manager.feedItems.isEmpty {
                    emptyStateView
                } else {
                    feedListView
                }
            }
        }
        .navigationTitle(NSLocalizedString("GlobalSquare.Title", comment: "Global square navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showComposer = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .sheet(isPresented: $showComposer) {
            BroadcastComposerView { text in
                try await manager.publish(content: text)
            }
        }
        .onAppear {
            manager.startSubscription()
        }
        .onDisappear {
            manager.stopSubscription()
        }
        .onReceive(ticker) { date in
            tickerDate = date
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor.opacity(0.5))

            Text(NSLocalizedString("GlobalSquare.Empty.Title", comment: "Global square empty state title"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(NSLocalizedString("GlobalSquare.Empty.Subtitle", comment: "Global square empty state subtitle"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showComposer = true
            } label: {
                Text(NSLocalizedString("GlobalSquare.Empty.Action", comment: "Global square empty state action button"))
                    .font(.headline)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 20)
        }
    }

    private var feedListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(manager.feedItems) { item in
                    BroadcastCardView(item: item, tickerDate: tickerDate)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .padding()
        }
    }
}
