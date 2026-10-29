//
//  LocationSharing.swift
//  POPOPX (iOS)
//
//  Location picker (map + current location) and the received-location chat bubble.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
@preconcurrency import MapKit
@preconcurrency import CoreLocation
import POPOPXSwitch

// MARK: - Location manager

@MainActor
final class ShareLocationManager: NSObject, @preconcurrency CLLocationManagerDelegate, ObservableObject {
    private let manager = CLLocationManager()
    @Published var lastCoordinate: CLLocationCoordinate2D?
    @Published var authorized: Bool = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func stop() { manager.stopUpdatingLocation() }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        authorized = status == .authorizedWhenInUse || status == .authorizedAlways
        if authorized { manager.startUpdatingLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last { lastCoordinate = loc.coordinate }
    }
}

// MARK: - Location picker

struct LocationPickerView: View {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager = ShareLocationManager()
    var onPick: (SharedLocation) -> Void

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    )
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    @State private var placeName: String = ""
    @State private var didCenter = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition) {
                    UserAnnotation()
                }
                    .ignoresSafeArea()
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 36))
                    .foregroundStyle(quantumGradient)
                    .shadow(radius: 4)
                    .offset(y: -18)

                VStack(spacing: 10) {
                    if !placeName.isEmpty {
                        Text(placeName)
                            .font(.subheadline).bold()
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    GradientButton(title: LocalizedStringKey(NSLocalizedString("location_send_this", comment: "button to send selected location")), systemImage: "paperplane.fill") {
                        let c = region.center
                        onPick(SharedLocation(lat: c.latitude, lng: c.longitude, name: placeName))
                        dismiss()
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle(NSLocalizedString("location_share_title", comment: "navigation title for location sharing picker"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(NSLocalizedString("Cancel", comment: "")) { dismiss() } } }
            .onAppear { locationManager.request() }
            .onDisappear { locationManager.stop() }
            .onChange(of: coordinateKey(locationManager.lastCoordinate)) {_, _ in
                if !didCenter, let c = locationManager.lastCoordinate {
                    didCenter = true
                    let newRegion = MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                    cameraPosition = .region(newRegion)
                    region = newRegion
                }
            }
            .onChange(of: coordinateKey(region.center)) {_, _ in reverseGeocode(region.center) }
        }
    }

    private func coordinateKey(_ c: CLLocationCoordinate2D?) -> String {
        guard let c else { return "" }
        return String(format: "%.4f,%.4f", c.latitude, c.longitude)
    }

    private func reverseGeocode(_ c: CLLocationCoordinate2D) {
        Task {
            do {
                let location = CLLocation(latitude: c.latitude, longitude: c.longitude)
                guard let request = MKReverseGeocodingRequest(location: location) else { return }
                let mapItems = try await request.mapItems
                if let item = mapItems.first {
                    let parts = [item.name, item.address?.shortAddress].compactMap { $0 }
                    self.placeName = parts.first ?? ""
                }
            } catch {
                logger.debug("reverseGeocode error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Location chat bubble

struct CILocationView: View {
    @EnvironmentObject var theme: AppTheme
    var location: SharedLocation
    var maxWidth: CGFloat = .infinity

    @State private var snapshot: UIImage?

    private var cardWidth: CGFloat { maxWidth == .infinity ? 260 : min(maxWidth, 260) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                if let snapshot {
                    Image(uiImage: snapshot).resizable().scaledToFill()
                } else {
                    Rectangle().fill(theme.colors.secondary.opacity(0.2))
                }
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(quantumGradient)
            }
            .frame(width: cardWidth, height: 140)
            .clipped()

            HStack(spacing: 8) {
                Image(systemName: "location.fill").foregroundStyle(quantumGradient)
                Text(location.name.isEmpty ? NSLocalizedString("location_shared_location", comment: "Shared location fallback") : location.name)
                    .font(.subheadline).bold()
                    .lineLimit(1)
                Spacer()
            }
            .padding(10)
        }
        .frame(width: cardWidth)
        .background(theme.appColors.receivedMessage)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: isInDarkTheme()
                        ? [darkThemeAccentColor().opacity(0.3), neonGradientSecondary().opacity(0.15)]
                        : [Color.white.opacity(0.5), Color.white.opacity(0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(0.15) : .clear, radius: 8, x: 0, y: 4)
        .onTapGesture { openInMaps() }
        .task { await loadSnapshot() }
    }

    private func openInMaps() {
        if let url = URL(string: "https://maps.apple.com/?ll=\(location.lat),\(location.lng)") {
            UIApplication.shared.open(url)
        }
    }

    private func loadSnapshot() async {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: location.lat, longitude: location.lng),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        options.size = CGSize(width: cardWidth, height: 140)
        let snapshotter = MKMapSnapshotter(options: options)
        if let result = try? await snapshotter.start() {
            snapshot = result.image
        }
    }
}
