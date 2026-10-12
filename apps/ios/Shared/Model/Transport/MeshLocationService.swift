// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import CoreLocation
import Combine
import os

/// Location service that provides the user's current location for geohash-based board filtering.
@MainActor
final class MeshLocationService: NSObject, ObservableObject {
    static let shared = MeshLocationService()

    @Published var currentGeohash: String = ""
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastError: String?
    @Published var isActive: Bool = false

    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 500
    }

    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestAuthorization()
            return
        }
        isActive = true
        locationManager.startUpdatingLocation()
    }

    func stopUpdating() {
        isActive = false
        locationManager.stopUpdatingLocation()
    }

    fileprivate func updateLocation(_ location: CLLocation) {
        let hash = Geohash.encode(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        currentGeohash = hash
    }
}

extension MeshLocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.updateLocation(location)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        os_log(.error, "MeshLocationService location error: %{public}@", error.localizedDescription)
        Task { @MainActor in
            self.lastError = error.localizedDescription
        }
    }
}
