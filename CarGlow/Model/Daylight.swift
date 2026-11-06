import Foundation
import CoreLocation

/// Works out whether it's dark outside from the sun's height in the sky, so "Turn On If Dark"
/// follows the real sunset all year without anyone changing times.
enum Daylight {
    /// Lights count as needed once the sun is below this many degrees above the horizon
    /// (about 15-20 minutes before sunset in the UK).
    static let darkBelowDegrees = 3.0

    /// Central England, used until the app has saved a location of its own.
    static let fallback = CLLocationCoordinate2D(latitude: 52.24, longitude: -0.90)

    private enum Keys { static let lat = "lastLatitude", lon = "lastLongitude" }

    static var savedLocation: CLLocationCoordinate2D {
        let d = UserDefaults.standard
        guard d.object(forKey: Keys.lat) != nil else { return fallback }
        return CLLocationCoordinate2D(latitude: d.double(forKey: Keys.lat), longitude: d.double(forKey: Keys.lon))
    }

    static func save(_ c: CLLocationCoordinate2D) {
        UserDefaults.standard.set(c.latitude, forKey: Keys.lat)
        UserDefaults.standard.set(c.longitude, forKey: Keys.lon)
    }

    static func isDark(at date: Date = .now, location: CLLocationCoordinate2D = savedLocation) -> Bool {
        sunElevation(at: date, location: location) < darkBelowDegrees
    }

    /// Sun elevation in degrees (NOAA general solar position formula, accurate to well under a degree).
    static func sunElevation(at date: Date, location: CLLocationCoordinate2D) -> Double {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let c = utc.dateComponents([.year, .hour, .minute, .second], from: date)
        let dayOfYear = Double(utc.ordinality(of: .day, in: .year, for: date) ?? 1)
        let year = c.year ?? 2026
        let daysInYear = (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) ? 366.0 : 365.0
        let hour = Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60 + Double(c.second ?? 0) / 3600

        let g = 2 * Double.pi / daysInYear * (dayOfYear - 1 + (hour - 12) / 24)
        let eqTime = 229.18 * (0.000075 + 0.001868 * cos(g) - 0.032077 * sin(g)
                               - 0.014615 * cos(2 * g) - 0.040849 * sin(2 * g))
        let decl = 0.006918 - 0.399912 * cos(g) + 0.070257 * sin(g) - 0.006758 * cos(2 * g)
            + 0.000907 * sin(2 * g) - 0.002697 * cos(3 * g) + 0.00148 * sin(3 * g)

        let trueSolarMinutes = hour * 60 + eqTime + 4 * location.longitude
        let hourAngle = (trueSolarMinutes / 4 - 180) * .pi / 180
        let lat = location.latitude * .pi / 180
        let cosZenith = sin(lat) * sin(decl) + cos(lat) * cos(decl) * cos(hourAngle)
        return 90 - acos(max(-1, min(1, cosZenith))) * 180 / .pi
    }
}

/// Saves a rough location whenever the app is opened, so sunset times match where the car is.
@MainActor
final class LocationRefresher: NSObject, CLLocationManagerDelegate {
    static let shared = LocationRefresher()
    private let manager = CLLocationManager()

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func refresh() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        default: break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if [.authorizedWhenInUse, .authorizedAlways].contains(manager.authorizationStatus) {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let c = locations.last?.coordinate { Daylight.save(c) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
