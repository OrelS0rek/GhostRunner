//
//  GhostEngine.swift
//  GhostRunner
//
//  Created by Admin on 01/04/2026.
//

import Foundation
import CoreLocation
internal import Combine

class GhostEngine: ObservableObject {
    static let shared = GhostEngine()

    @Published var ghostCoordinate: CLLocationCoordinate2D?
    @Published var deltaSeconds: Double = 0             //שינוי הזמן בין הרוח למשתמש
    // אם השינוי חיובי - המשתמש מוביל, אם שלילי - הרוח מוביל

    //משתנים הקשורים לרוח שבחרנו
    @Published var isActive: Bool = false
    @Published var ghostName: String = ""
    @Published var ghostRunTitle: String = ""

    private var route: [[String: Double]] = []
    private var originalDuration: TimeInterval = 0
    private var startTime: Date = Date()
    private var timer: Timer?

    private init() {}

    // MARK: - התחלת הרוח מריצה ששמרנו
    func start(route: [[String: Double]], duration: TimeInterval, name: String, title: String) {
        self.route           = route
        self.originalDuration = duration
        self.startTime       = Date()
        self.ghostName       = name
        self.ghostRunTitle   = title
        self.isActive        = true

        //לוגיקת טיימר
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.update()
        }
    }
    
    //עצירת הריצה (לוגיקה לעצור גם את הרוח)
    func stop() {
        timer?.invalidate()
        timer = nil
        isActive = false
        ghostCoordinate = nil
        deltaSeconds = 0
    }

    // MARK: - עדכון מיקום הרוח כל חצי שנייה
    private func update() {
        guard !route.isEmpty else { return }

        let myElapsed = Date().timeIntervalSince(startTime) //הזמן שעברנו

        // מציאה איפה הרוח צריך להיות כל זמן elapssed
        // למערך ששומר את הריצות של הרוח יש חתימת זמן כמפתח, נמצא לפיו את המיקום
        //ניגש לערך של המערך בערך ששומר כמה שניות אנחנו עברו (myElapsed)
        let ghostCoord = interpolatedCoordinate(at: myElapsed)

        // דלטה חיובי - מובילים, שלילי - מפסידים
        let myDistanceKm = RunManager.shared().currentDistanceKm()
        let ghostDistanceKm = distanceAtElapsed(myElapsed)
        let distanceDeltaKm = myDistanceKm - ghostDistanceKm

        // ממירים את הדלטה לפי מרחק לזמן בעזרת המשתנה של הקצב הממוצע
        let avgPace = originalDuration / max(totalRouteDistanceKm(), 0.01)
        let timeDelta = distanceDeltaKm * avgPace

        DispatchQueue.main.async {
            self.ghostCoordinate = ghostCoord
            self.deltaSeconds = timeDelta
        }
    }

    // MARK: - מציאת מיקום הרוח בכל שניה לפי הזמן שעבר (אינטרפולציה)
    private func interpolatedCoordinate(at elapsed: TimeInterval) -> CLLocationCoordinate2D? {
        guard route.count >= 2 else {
            return route.first.map {
                CLLocationCoordinate2D(latitude: $0["lat"] ?? 0, longitude: $0["lng"] ?? 0)
            }
        }

        // למצוא את שתי הנקודות במסלול שסוגרות על החתימת זמן הספציפית שאנחנו מחפשים
        for i in 0..<route.count - 1 {
            let t0 = route[i]["elapsed"] ?? 0
            let t1 = route[i + 1]["elapsed"] ?? 0

            guard elapsed >= t0 && elapsed <= t1 else { continue }

            // אינטרפולציה לינארית בין שתי נקודות
            let fraction = t1 > t0 ? (elapsed - t0) / (t1 - t0) : 0

            let lat = (route[i]["lat"] ?? 0) + fraction * ((route[i+1]["lat"] ?? 0) - (route[i]["lat"] ?? 0))
            let lng = (route[i]["lng"] ?? 0) + fraction * ((route[i+1]["lng"] ?? 0) - (route[i]["lng"] ?? 0))

            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }

        // מעבר לסוף של הריצה של הרוח - שישאר במיקום האחרון
        if let last = route.last {
            return CLLocationCoordinate2D(latitude: last["lat"] ?? 0, longitude: last["lng"] ?? 0)
        }
        return nil
    }

    // MARK: - מרחק שעבר הרוח מהרגע שהתחיל הזמן
    private func distanceAtElapsed(_ elapsed: TimeInterval) -> Double {
        guard route.count >= 2 else { return 0 }
        var distance: Double = 0

        for i in 0..<route.count - 1 {
            let t1 = route[i + 1]["elapsed"] ?? 0
            if t1 > elapsed { break }

            let a = CLLocation(latitude: route[i]["lat"] ?? 0,   longitude: route[i]["lng"] ?? 0)
            let b = CLLocation(latitude: route[i+1]["lat"] ?? 0, longitude: route[i+1]["lng"] ?? 0)
            distance += a.distance(from: b) / 1000.0 //חישוב מרחק בין הקואורדינטות והמרה לקילומטרים
        }
        return distance
    }

    // MARK: - מרחק מסלול כולל
    private func totalRouteDistanceKm() -> Double {
        guard route.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 0..<route.count - 1 {
            let a = CLLocation(latitude: route[i]["lat"] ?? 0,   longitude: route[i]["lng"] ?? 0)
            let b = CLLocation(latitude: route[i+1]["lat"] ?? 0, longitude: route[i+1]["lng"] ?? 0)
            total += a.distance(from: b) / 1000.0
        }
        return total
    }
}
