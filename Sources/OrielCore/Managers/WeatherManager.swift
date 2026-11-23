import Foundation
import CoreLocation
import Combine

@MainActor
public final class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = WeatherManager()

    @Published public var authorizationStatus: CLAuthorizationStatus
    @Published public var weather: WeatherSnapshot?

    private let locationManager = CLLocationManager()
    private var lastFetchLocation: CLLocation?
    private var refreshTimer: Timer?

    private override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer

        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorized {
            locationManager.requestLocation()
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshWeatherIfAuthorized()
            }
        }
    }

    public func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }

    public func refreshWeatherIfAuthorized() {
        authorizationStatus = locationManager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorized {
            locationManager.requestLocation()
        }
    }

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedAlways || status == .authorized {
                manager.requestLocation()
            }
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.lastFetchLocation = loc
            await self.fetchOpenMeteo(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silent failure; keeps cached weather if any
    }

    private func fetchOpenMeteo(lat: Double, lon: Double) async {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,is_day,weather_code,precipitation&hourly=precipitation_probability&forecast_days=1"
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any] else { return }

            let temp = (current["temperature_2m"] as? Double) ?? 0
            let isDay = ((current["is_day"] as? Int) ?? 1) == 1
            let code = (current["weather_code"] as? Int) ?? 0
            let precip = (current["precipitation"] as? Double) ?? 0

            var precipChance = 0
            if let hourly = json["hourly"] as? [String: Any],
               let probs = hourly["precipitation_probability"] as? [Int],
               let first = probs.first {
                precipChance = first
            }

            let mapped = Self.mapWMOCode(code, isDay: isDay)
            weather = WeatherSnapshot(
                temperatureCelsius: temp,
                conditionCode: code,
                conditionDescription: mapped.description,
                symbolName: mapped.symbol,
                isDaylight: isDay,
                precipitationChance: precipChance,
                isRaining: precip > 0 || [51, 53, 55, 61, 63, 65, 80, 81, 82, 95, 96, 99].contains(code),
                lastFetchDate: Date()
            )
        } catch {
            // Keep existing snapshot
        }
    }

    public static func mapWMOCode(_ code: Int, isDay: Bool) -> (description: String, symbol: String) {
        switch code {
        case 0:
            return ("Clear", isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1, 2:
            return ("Partly Cloudy", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3:
            return ("Cloudy", "cloud.fill")
        case 45, 48:
            return ("Fog", "cloud.fog.fill")
        case 51, 53, 55, 56, 57:
            return ("Drizzle", "cloud.drizzle.fill")
        case 61, 63, 65, 66, 67, 80, 81, 82:
            return ("Rain", isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill")
        case 71, 73, 75, 77, 85, 86:
            return ("Snow", "cloud.snow.fill")
        case 95, 96, 99:
            return ("Thunderstorm", "cloud.bolt.rain.fill")
        default:
            return ("Clear", isDay ? "sun.max.fill" : "moon.stars.fill")
        }
    }
}
