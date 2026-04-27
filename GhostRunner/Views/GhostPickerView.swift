// GhostPickerView.swift
// GhostRunner

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct GhostPickerView: View {
    @Binding var selectedRun: FeedRun?
    @ObservedObject private var friendManager = FriendManager.shared
    @ObservedObject private var runStore      = RunStore.shared
    @Environment(\.dismiss) var dismiss

    // Convert my RunPost runs into FeedRun so the picker can use them uniformly
    private var myRunsAsFeed: [FeedRun] {
        runStore.myRuns.compactMap { run in
            FeedRun(from: [
                "userId":           FirebaseAuth.Auth.auth().currentUser?.uid ?? "",
                "title":            run.title,
                "notes":            run.notes,
                "distanceKm":       run.distanceKm,
                "durationSeconds":  run.durationSeconds,
                "avgPaceSecPerKm":  run.avgPaceSecPerKm,
                "photoURLs":        run.photoURLs,
                "points":           run.points,
                "timestamp":        Timestamp(date: run.timestamp)
            ], id: run.id)
        }
    }

    private var allRuns: [FeedRun] {
        (myRunsAsFeed + friendManager.friendsFeed)
            .sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allRuns.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "figure.run.circle")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No runs to race against yet")
                            .foregroundColor(.secondary)
                        Text("Complete a run first, or add friends who have posted runs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        // My runs section
                        if !myRunsAsFeed.isEmpty {
                            Section("My Past Runs") {
                                ForEach(myRunsAsFeed) { run in
                                    ghostRow(run: run, label: "You")
                                }
                            }
                        }

                        // Friends' runs section
                        if !friendManager.friendsFeed.isEmpty {
                            Section("Friends' Runs") {
                                ForEach(friendManager.friendsFeed) { run in
                                    let name = friendManager.friends
                                        .first { $0.id == run.userId }?.displayName ?? "Friend"
                                    ghostRow(run: run, label: name)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Choose a Ghost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("No Ghost") {
                        selectedRun = nil
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    func ghostRow(run: FeedRun, label: String) -> some View {
        Button {
            selectedRun = run
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedRun?.id == run.id
                      ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(run.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("· \(label)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 12) {
                        Label(String(format: "%.2f km", run.distanceKm),
                              systemImage: "map")
                        Label(formatPace(run.avgPaceSecPerKm),
                              systemImage: "speedometer")
                        Text(run.timestamp, style: .date)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }

    func formatPace(_ secPerKm: Double) -> String {
        guard secPerKm > 0 else { return "--'--\"" }
        let m = Int(secPerKm) / 60; let s = Int(secPerKm) % 60
        return String(format: "%d'%02d\"", m, s)
    }
}
