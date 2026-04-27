//
//  RunStore.swift
//  GhostRunner
//
//  Created by Admin on 26/03/2026.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import UIKit
internal import Combine

class RunStore: ObservableObject {
    static let shared = RunStore()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    @Published var myRuns: [RunPost] = []
    @Published var isUploading: Bool = false

    private init() {}

    // MARK: - שמירת ריצה ותמונות לfirestore
    func saveRun(
        title: String,
        notes: String,
        runData: [String: Any],
        photos: [UIImage],
        completion: @escaping (Bool) -> Void
    ) {
        guard let uid = Auth.auth().currentUser?.uid else { completion(false); return } //בדיקה האם המשתמש הנוכחי מחובר
        isUploading = true

        let distanceKm     = runData["distanceKm"] as? Double ?? 0
        let durationSeconds = runData["durationSeconds"] as? Double ?? 0
        let avgPace        = runData["avgPaceSecPerKm"] as? Double ?? 0
        let route          = runData["route"] as? [[String: Double]] ?? []

        // Upload photos first, then save the run document
        uploadPhotos(photos, uid: uid) { photoURLs in
            let runDoc: [String: Any] = [
                "userId":           uid,
                "title":            title,
                "notes":            notes,
                "distanceKm":       distanceKm,
                "durationSeconds":  durationSeconds,
                "avgPaceSecPerKm":  avgPace,
                "route":            route,
                "photoURLs":        photoURLs,
                "timestamp":        Timestamp(date: Date()),
                "points":           self.calculatePoints(distanceKm: distanceKm)
            ]

            self.db.collection("runs").addDocument(data: runDoc) { error in
                DispatchQueue.main.async {
                    self.isUploading = false
                    if let error = error {
                        print("Error saving run: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        // Update user stats
                        UserManager.shared.incrementStats(distanceKm: distanceKm)
                        completion(true)
                    }
                }
            }
        }
    }

    // MARK: - Fetch runs for current user
    func fetchMyRuns() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("runs")
            .whereField("userId", isEqualTo: uid)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    self.myRuns = docs.compactMap { RunPost(from: $0.data(), id: $0.documentID) }
                }
            }
    }

    // MARK: - Upload photos to Firebase Storage
    private func uploadPhotos(_ photos: [UIImage], uid: String, completion: @escaping ([String]) -> Void) {
        guard !photos.isEmpty else { completion([]); return }

        var urls: [String] = []
        let group = DispatchGroup()

        for (index, photo) in photos.enumerated() {
            guard let data = photo.jpegData(compressionQuality: 0.7) else { continue }
            group.enter()

            let ref = storage.reference().child("runPhotos/\(uid)/\(UUID().uuidString)_\(index).jpg")
            ref.putData(data, metadata: nil) { _, error in
                if error == nil {
                    ref.downloadURL { url, _ in
                        if let url = url { urls.append(url.absoluteString) }
                        group.leave()
                    }
                } else {
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { completion(urls) }
    }

    // MARK: - Points calculation (1 point per 100m)
    private func calculatePoints(distanceKm: Double) -> Int {
        return Int(distanceKm * 10)
    }
}

// MARK: - RunPost model
struct RunPost: Identifiable {
    let id: String
    let title: String
    let notes: String
    let distanceKm: Double
    let durationSeconds: Double
    let avgPaceSecPerKm: Double
    let photoURLs: [String]
    let timestamp: Date
    let points: Int

    init?(from data: [String: Any], id: String) {
        self.id              = id
        self.title           = data["title"] as? String ?? "Untitled Run"
        self.notes           = data["notes"] as? String ?? ""
        self.distanceKm      = data["distanceKm"] as? Double ?? 0
        self.durationSeconds = data["durationSeconds"] as? Double ?? 0
        self.avgPaceSecPerKm = data["avgPaceSecPerKm"] as? Double ?? 0
        self.photoURLs       = data["photoURLs"] as? [String] ?? []
        self.points          = data["points"] as? Int ?? 0
        let ts               = data["timestamp"] as? Timestamp
        self.timestamp       = ts?.dateValue() ?? Date()
    }
}
