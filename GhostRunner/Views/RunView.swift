//
//  RunView.swift
//  GhostRunner
//
//  Created by Admin on 26/03/2026.
//



import SwiftUI
import MapKit
import CoreLocation
import FirebaseFirestore
internal import Combine
// MARK: - CLLocationCoordinate2D Equatable
extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D,
                           rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// MARK: - LocationManager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var updateCount: Int = 0

    override init() {
        super.init()
        manager.delegate                        = self
        manager.desiredAccuracy                 = kCLLocationAccuracyBest
        manager.distanceFilter                  = 10
        manager.activityType                    = .fitness
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
    }

    func requestPermission()  { manager.requestWhenInUseAuthorization() }
    func startUpdating()      { manager.startUpdatingLocation() }
    func stopUpdating()       { manager.stopUpdatingLocation() }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }

        // Reject poor accuracy readings
        guard latest.horizontalAccuracy >= 0,
              latest.horizontalAccuracy < 20 else { return }

        RunManager.shared().add(latest.coordinate)

        DispatchQueue.main.async {
            self.userLocation = latest.coordinate
            self.updateCount += 1
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}

// MARK: - RunView
struct RunView: View {
    @StateObject private var locationManager  = LocationManager()
    @StateObject private var ghostEngine      = GhostEngine.shared

    @State private var isRunning              = false
    @State private var runFinished            = false
    @State private var finishedRunData: [String: Any] = [:]

    // HUD stats
    @State private var distanceKm: Double     = 0
    @State private var paceSecPerKm: Double   = 0
    @State private var durationSeconds: Double = 0
    @State private var hudTimer: Timer?       = nil

    // Ghost picker
    @State private var showingGhostPicker     = false
    @State private var selectedGhostRun: FeedRun? = nil

    // Map
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {

                // MARK: Map
                Map(position: $cameraPosition) {
                    UserAnnotation()

                    // Ghost annotation
                    if ghostEngine.isActive,
                       let ghostCoord = ghostEngine.ghostCoordinate {
                        Annotation(ghostEngine.ghostName, coordinate: ghostCoord) {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.3))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "figure.run")
                                    .foregroundColor(.purple)
                                    .font(.system(size: 16))
                            }
                        }
                    }
                }
                .ignoresSafeArea()
                .onAppear {
                    locationManager.requestPermission()
                }
                .onChange(of: locationManager.updateCount) { _, _ in
                    guard let coord = locationManager.userLocation,
                          isRunning else { return }
                    cameraPosition = .camera(MapCamera(
                        centerCoordinate: coord,
                        distance: 500,
                        heading: 0,
                        pitch: 0
                    ))
                }

                // MARK: Ghost delta banner (top of screen)
                if ghostEngine.isActive {
                    VStack {
                        HStack(spacing: 8) {
                            Image(systemName: ghostEngine.deltaSeconds >= 0
                                  ? "arrow.up.circle.fill"
                                  : "arrow.down.circle.fill")
                                .foregroundColor(ghostEngine.deltaSeconds >= 0
                                                 ? .green : .red)

                            Text(ghostEngine.deltaSeconds >= 0
                                 ? "+\(formatDelta(ghostEngine.deltaSeconds)) ahead of \(ghostEngine.ghostName)"
                                 : "\(formatDelta(abs(ghostEngine.deltaSeconds))) behind \(ghostEngine.ghostName)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .padding(.top, 60)

                        Spacer()
                    }
                }

                // MARK: Bottom HUD card
                VStack(spacing: 0) {

                    // Stats row — visible while running
                    if isRunning {
                        HStack(spacing: 0) {
                            statCell(label: "KM",
                                     value: String(format: "%.2f", distanceKm))
                            Divider().frame(height: 50)
                            statCell(label: "PACE",
                                     value: formatPace(paceSecPerKm))
                            Divider().frame(height: 50)
                            statCell(label: "TIME",
                                     value: formatDuration(durationSeconds))
                        }
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                    }

                    // Location denied warning
                    if locationManager.authorizationStatus == .denied {
                        Text("Location access denied — enable it in Settings")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(8)
                            .background(.ultraThinMaterial)
                    }

                    // Ghost picker button — only before run starts
                    if !isRunning {
                        Button {
                            showingGhostPicker = true
                        } label: {
                            HStack {
                                Image(systemName: selectedGhostRun != nil
                                      ? "figure.run.circle.fill"
                                      : "figure.run.circle")
                                Text(selectedGhostRun != nil
                                     ? "Ghost: \(selectedGhostRun!.title)"
                                     : "Choose a ghost (optional)")
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .foregroundColor(selectedGhostRun != nil ? .orange : .secondary)
                        }
                    }

                    // Start / Stop button
                    Button(action: toggleRun) {
                        Text(isRunning ? "Stop Run" : "Start Run")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(isRunning ? Color.red : Color.orange)
                            .cornerRadius(0)
                    }
                }
            }
            .navigationTitle("Run")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $runFinished) {
                UploadRunView(runData: finishedRunData)
            }
            .sheet(isPresented: $showingGhostPicker) {
                GhostPickerView(selectedRun: $selectedGhostRun)
            }
        }
    }

    // MARK: - Actions

    func toggleRun() {
        isRunning ? stopRun() : startRun()
    }

    func startRun() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            locationManager.requestPermission()
            return
        }

        RunManager.shared().startRun()
        locationManager.startUpdating()
        isRunning = true

        // Start ghost if one was selected
        if let ghost = selectedGhostRun {
            let db = Firestore.firestore()
            db.collection("runs").document(ghost.id).getDocument { snapshot, _ in
                guard let data = snapshot?.data(),
                      let route = data["route"] as? [[String: Double]] else { return }
                let name = FriendManager.shared.friends
                    .first { $0.id == ghost.userId }?.displayName ?? "Ghost"
                GhostEngine.shared.start(
                    route: route,
                    duration: ghost.durationSeconds,
                    name: name,
                    title: ghost.title
                )
            }
        }

        // Tick HUD every second
        hudTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                distanceKm      = RunManager.shared().currentDistanceKm()
                paceSecPerKm    = RunManager.shared().currentPaceSecPerKm()
                durationSeconds = RunManager.shared().currentDurationSeconds()
            }
        }
    }

    func stopRun() {
        isRunning = false
        hudTimer?.invalidate()
        hudTimer = nil
        locationManager.stopUpdating()
        GhostEngine.shared.stop()

        RunManager.shared().stopRun { runData in
            DispatchQueue.main.async {
                self.finishedRunData = runData as? [String: Any] ?? [:]
                self.runFinished = true
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    func statCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    func formatPace(_ secPerKm: Double) -> String {
        guard secPerKm > 0 else { return "--'--\"" }
        let m = Int(secPerKm) / 60; let s = Int(secPerKm) % 60
        return String(format: "%d'%02d\"", m, s)
    }

    func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600; let m = (total % 3600) / 60; let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%02d:%02d", m, s)
    }

    func formatDelta(_ seconds: Double) -> String {
        let s = Int(seconds)
        return s < 60 ? "\(s)s" : "\(s/60)m \(s % 60)s"
    }
}
