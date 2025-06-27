import Foundation
import CoreLocation
import MapKit
import os

/// Error types for location operations
public enum LocationError: Error, LocalizedError {
    case invalidAction
    case authorizationDenied
    case authorizationNotDetermined
    case locationUnavailable
    case missingAddress
    case missingCoordinates
    case geocodingFailed
    case reverseGeocodingFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidAction:
            return "Invalid action. Use 'current', 'geocode', 'reverse', or 'distance'."
        case .authorizationDenied:
            return "Location access denied. Please grant permission in Settings."
        case .authorizationNotDetermined:
            return "Location permission not yet determined. Please grant permission when prompted."
        case .locationUnavailable:
            return "Current location is unavailable."
        case .missingAddress:
            return "Address is required for geocoding."
        case .missingCoordinates:
            return "Latitude and longitude are required."
        case .geocodingFailed:
            return "Failed to find location for the given address."
        case .reverseGeocodingFailed:
            return "Failed to find address for the given coordinates."
        }
    }
}

/// Input for location operations
public struct LocationInput: Codable, Sendable {
    public let action: String
    public let address: String?
    public let latitude: Double?
    public let longitude: Double?
    public let latitude2: Double?
    public let longitude2: Double?
    
    public init(
        action: String,
        address: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        latitude2: Double? = nil,
        longitude2: Double? = nil
    ) {
        self.action = action
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.latitude2 = latitude2
        self.longitude2 = longitude2
    }
}

/// Output for location operations
public struct LocationOutput: Codable, Sendable {
    public let status: String
    public let message: String
    public let latitude: Double?
    public let longitude: Double?
    public let address: String?
    public let distance: String?
    
    public init(
        status: String,
        message: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String? = nil,
        distance: String? = nil
    ) {
        self.status = status
        self.message = message
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.distance = distance
    }
}

/// Manager for location operations using CoreLocation
@MainActor
public class LocationManager: NSObject {
    public static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MLXTools", category: "LocationManager")
    
    private override init() {
        super.init()
        locationManager.delegate = self
        logger.info("LocationManager initialized")
    }
    
    /// Main entry point for location operations
    public func performAction(_ input: LocationInput) async throws -> LocationOutput {
        logger.info("Performing location action: \(input.action)")
        
        switch input.action.lowercased() {
        case "current":
            return try await getCurrentLocation()
        case "geocode":
            return try await geocodeAddress(address: input.address)
        case "reverse":
            return try await reverseGeocode(latitude: input.latitude, longitude: input.longitude)
        case "distance":
            return try calculateDistance(input: input)
        default:
            throw LocationError.invalidAction
        }
    }
    
    private func getCurrentLocation() async throws -> LocationOutput {
        // Check authorization status
        let authStatus = locationManager.authorizationStatus
        
        #if os(visionOS)
        guard authStatus == .authorizedWhenInUse else {
            if authStatus == .notDetermined {
                throw LocationError.authorizationNotDetermined
            }
            throw LocationError.authorizationDenied
        }
        #elseif os(macOS)
        guard authStatus == .authorizedAlways else {
            if authStatus == .notDetermined {
                throw LocationError.authorizationNotDetermined
            }
            throw LocationError.authorizationDenied
        }
        #else
        guard authStatus == .authorizedAlways || authStatus == .authorizedWhenInUse else {
            if authStatus == .notDetermined {
                throw LocationError.authorizationNotDetermined
            }
            throw LocationError.authorizationDenied
        }
        #endif
        
        // Get current location
        guard let location = locationManager.location else {
            throw LocationError.locationUnavailable
        }
        
        // Reverse geocode to get address
        do {
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let address = formatAddress(placemark: placemarks.first)
            
            return LocationOutput(
                status: "success",
                message: "Current location: \(address)",
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                address: address
            )
        } catch {
            // Return location without address if geocoding fails
            return LocationOutput(
                status: "success",
                message: "Current location retrieved",
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                address: "Unknown location"
            )
        }
    }
    
    private func geocodeAddress(address: String?) async throws -> LocationOutput {
        guard let address = address, !address.isEmpty else {
            throw LocationError.missingAddress
        }
        
        do {
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.geocodeAddressString(address)
            
            guard let placemark = placemarks.first,
                  let location = placemark.location else {
                throw LocationError.geocodingFailed
            }
            
            let formattedAddress = formatAddress(placemark: placemark)
            
            return LocationOutput(
                status: "success",
                message: "Location found: \(formattedAddress)",
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                address: formattedAddress
            )
        } catch {
            logger.error("Geocoding failed: \(error)")
            throw LocationError.geocodingFailed
        }
    }
    
    private func reverseGeocode(latitude: Double?, longitude: Double?) async throws -> LocationOutput {
        guard let latitude = latitude,
              let longitude = longitude else {
            throw LocationError.missingCoordinates
        }
        
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        do {
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            
            guard let placemark = placemarks.first else {
                throw LocationError.reverseGeocodingFailed
            }
            
            let address = formatAddress(placemark: placemark)
            
            return LocationOutput(
                status: "success",
                message: "Address: \(address)",
                latitude: latitude,
                longitude: longitude,
                address: address
            )
        } catch {
            logger.error("Reverse geocoding failed: \(error)")
            throw LocationError.reverseGeocodingFailed
        }
    }
    
    private func calculateDistance(input: LocationInput) throws -> LocationOutput {
        guard let lat1 = input.latitude,
              let lon1 = input.longitude,
              let lat2 = input.latitude2,
              let lon2 = input.longitude2 else {
            throw LocationError.missingCoordinates
        }
        
        let location1 = CLLocation(latitude: lat1, longitude: lon1)
        let location2 = CLLocation(latitude: lat2, longitude: lon2)
        
        let distance = location1.distance(from: location2)
        
        // Calculate bearing
        let bearing = calculateBearing(from: location1, to: location2)
        let direction = compassDirection(from: bearing)
        
        let formattedDistance = formatDistance(distance)
        
        return LocationOutput(
            status: "success",
            message: "Distance: \(formattedDistance) \(direction)",
            distance: formattedDistance
        )
    }
    
    private func formatAddress(placemark: CLPlacemark?) -> String {
        guard let placemark = placemark else { return "Unknown location" }
        
        var components: [String] = []
        
        if let name = placemark.name {
            components.append(name)
        }
        if let street = placemark.thoroughfare {
            components.append(street)
        }
        if let city = placemark.locality {
            components.append(city)
        }
        if let state = placemark.administrativeArea {
            components.append(state)
        }
        if let country = placemark.country {
            components.append(country)
        }
        
        return components.joined(separator: ", ")
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0f meters", meters)
        } else if meters < 10000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return String(format: "%.0f km", meters / 1000)
        }
    }
    
    private func calculateBearing(from: CLLocation, to: CLLocation) -> Double {
        let lat1 = from.coordinate.latitude.degreesToRadians
        let lon1 = from.coordinate.longitude.degreesToRadians
        let lat2 = to.coordinate.latitude.degreesToRadians
        let lon2 = to.coordinate.longitude.degreesToRadians
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        let radiansBearing = atan2(y, x)
        let degreesBearing = radiansBearing.radiansToDegrees
        
        return (degreesBearing + 360).truncatingRemainder(dividingBy: 360)
    }
    
    private func compassDirection(from bearing: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((bearing + 11.25) / 22.5) % 16
        return directions[index]
    }
    
    public func requestLocationAuthorization() {
        logger.info("Requesting location authorization")
        #if os(macOS)
        // On macOS, just start monitoring which will trigger permission dialog
        locationManager.startUpdatingLocation()
        locationManager.stopUpdatingLocation()
        #else
        locationManager.requestWhenInUseAuthorization()
        #endif
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus.rawValue
        Task { @MainActor in
            logger.info("Location authorization changed: \(status)")
        }
    }
    
    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Handle location updates if needed
    }
    
    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let errorDescription = error.localizedDescription
        Task { @MainActor in
            logger.error("Location error: \(errorDescription)")
        }
    }
}

// MARK: - Helper Extensions
extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
    var radiansToDegrees: Double { self * 180 / .pi }
}