// ProfileView.swift
// GhostRunner

import SwiftUI
import PhotosUI
import FirebaseFirestore

struct ProfileView: View {
    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var runStore    = RunStore.shared

    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var isUploadingPhoto = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: Profile header
                    VStack(spacing: 12) {

                        // Profile picture + camera badge
                        ZStack(alignment: .bottomTrailing) {
                            if !userManager.profileImageURL.isEmpty,
                               let url = URL(string: userManager.profileImageURL) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.orange)
                            }

                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Image(systemName: "camera.circle.fill")
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                    .foregroundColor(.orange)
                                    .background(Color.white)
                                    .clipShape(Circle())
                            }
                            .onChange(of: selectedPhoto) { _, item in
                                uploadNewProfilePhoto(item: item)
                            }
                        }

                        if isUploadingPhoto {
                            ProgressView("Updating photo...")
                                .font(.caption)
                        }

                        if userManager.isLoading {
                            ProgressView()
                        } else {
                            Text(userManager.displayName.isEmpty ? "Runner" : userManager.displayName)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(userManager.email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top)

                    // MARK: Stats row
                    HStack(spacing: 0) {
                        statCell(value: "\(userManager.totalRuns)",
                                 label: "Runs")
                        Divider().frame(height: 40)
                        statCell(value: String(format: "%.1f", userManager.totalKm),
                                 label: "Total KM")
                        Divider().frame(height: 40)
                        statCell(value: "\(userManager.totalRuns * 10)",
                                 label: "Points")
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // MARK: My runs feed
                    VStack(alignment: .leading, spacing: 12) {
                        Text("My Runs")
                            .font(.headline)
                            .padding(.horizontal)

                        if runStore.myRuns.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "figure.run")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                Text("No runs yet — go for a run!")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(runStore.myRuns) { run in
                                NavigationLink(destination: RunDetailView(run: run)) {
                                    RunCard(run: run)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }

    // MARK: - Upload profile photo
    func uploadNewProfilePhoto(item: PhotosPickerItem?) {
        guard let item = item else { return }
        isUploadingPhoto = true

        item.loadTransferable(type: Data.self) { result in
            if case .success(let data) = result,
               let data = data,
               let image = UIImage(data: data) {
                UserManager.shared.uploadProfileImage(image) { _ in
                    DispatchQueue.main.async {
                        isUploadingPhoto = false
                    }
                }
            } else {
                DispatchQueue.main.async { isUploadingPhoto = false }
            }
        }
    }

    @ViewBuilder
    func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3).fontWeight(.semibold)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - RunCard
struct RunCard: View {
    let run: RunPost

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Title + date
            HStack {
                Text(run.title).font(.headline)
                Spacer()
                Text(run.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Stats
            HStack(spacing: 16) {
                Label(String(format: "%.2f km", run.distanceKm),
                      systemImage: "map")
                Label(formatPace(run.avgPaceSecPerKm),
                      systemImage: "speedometer")
                Label(formatDuration(run.durationSeconds),
                      systemImage: "clock")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            // Notes
            if !run.notes.isEmpty {
                Text(run.notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Photos
            if !run.photoURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(run.photoURLs, id: \.self) { urlString in
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Color(.systemGray5)
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }

            // Points badge
            HStack {
                Spacer()
                Text("+\(run.points) pts")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
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
}
