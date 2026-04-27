//
//  RunDetailView.swift
//  GhostRunner
//
//  Created by Admin on 01/04/2026.
//


import SwiftUI
import MapKit
import FirebaseFirestore

struct RunDetailView: View {
    let run: RunPost

    @State private var region = MKCoordinateRegion()
    @State private var routeCoords: [CLLocationCoordinate2D] = []
    @State private var selectedPhoto: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // MARK: Route map
                if !routeCoords.isEmpty {
                    Map {
                        // Animated polyline of the route
                        MapPolyline(coordinates: routeCoords)
                            .stroke(.orange, lineWidth: 4)

                        // Start marker
                        if let first = routeCoords.first {
                            Annotation("Start", coordinate: first) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                            }
                        }

                        // End marker
                        if let last = routeCoords.last {
                            Annotation("Finish", coordinate: last) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                            }
                        }
                    }
                    .frame(height: 280)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 280)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "map.slash")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("No route data")
                                    .foregroundColor(.secondary)
                            }
                        )
                }

                VStack(spacing: 20) {

                    // MARK: Title + date
                    VStack(spacing: 4) {
                        Text(run.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(run.timestamp, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)

                    // MARK: Stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        statCard(value: String(format: "%.2f", run.distanceKm),
                                 unit: "km", icon: "map.fill")
                        statCard(value: formatPace(run.avgPaceSecPerKm),
                                 unit: "/km", icon: "speedometer")
                        statCard(value: formatDuration(run.durationSeconds),
                                 unit: "time", icon: "clock.fill")
                        statCard(value: "\(run.points)",
                                 unit: "points", icon: "star.fill")
                    }
                    .padding(.horizontal)

                    // MARK: Notes
                    if !run.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notes")
                                .font(.headline)
                            Text(run.notes)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }

                    // MARK: Photos
                    if !run.photoURLs.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Photos")
                                .font(.headline)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(run.photoURLs, id: \.self) { urlString in
                                        if let url = URL(string: urlString) {
                                            AsyncImage(url: url) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                            } placeholder: {
                                                Color(.systemGray5)
                                            }
                                            .frame(width: 200, height: 150)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .onTapGesture {
                                                selectedPhoto = urlString
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Run Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { buildRoute() }
        // Full screen photo viewer
        .fullScreenCover(item: $selectedPhoto) { urlString in
            PhotoFullScreenView(urlString: urlString)
        }
    }

    // MARK: - Build route from stored coordinates
    func buildRoute() {
        // Route is stored in the run's raw data — fetch it from Firestore
        let db = Firestore.firestore()
        db.collection("runs").document(run.id).getDocument { snapshot, _ in
            guard let data = snapshot?.data(),
                  let rawRoute = data["route"] as? [[String: Double]] else { return }

            let coords = rawRoute.compactMap { point -> CLLocationCoordinate2D? in
                guard let lat = point["lat"], let lng = point["lng"] else { return nil }
                return CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }

            DispatchQueue.main.async {
                self.routeCoords = coords
            }
        }
    }

    @ViewBuilder
    func statCard(value: String, unit: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.orange)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    func formatPace(_ secPerKm: Double) -> String {
        guard secPerKm > 0 else { return "--'--\"" }
        let m = Int(secPerKm) / 60; let s = Int(secPerKm) % 60
        return String(format: "%d'%02d\"", m, s)
    }

    func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600; let m = (total % 3600) / 60; let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Full screen photo viewer
struct PhotoFullScreenView: View {
    let urlString: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    ProgressView().tint(.white)
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}

// Make String conform to Identifiable for fullScreenCover
extension String: @retroactive Identifiable {
    public var id: String { self }
}

extension FeedRun {
    func toRunPost() -> RunPost {
        RunPost(from: [
            "title":            title,
            "notes":            notes,
            "distanceKm":       distanceKm,
            "durationSeconds":  durationSeconds,
            "avgPaceSecPerKm":  avgPaceSecPerKm,
            "photoURLs":        photoURLs,
            "points":           points,
            "timestamp":        Timestamp(date: timestamp)
        ], id: id)!
    }
}
