//
//  UploadRunView.swift
//  GhostRunner
//
//  Created by Admin on 26/03/2026.
//


import SwiftUI
import PhotosUI

struct UploadRunView: View {
    var runData: [String: Any] = [:]

    @Environment(\.dismiss) var dismiss
    @StateObject private var runStore = RunStore.shared

    @State private var title = ""
    @State private var notes = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showSuccess = false
    @State private var errorMessage = ""

    //לקיחת סטסיסטיקות מ runData
    private var distanceKm: Double     { runData["distanceKm"] as? Double ?? 0 }
    private var durationSeconds: Double { runData["durationSeconds"] as? Double ?? 0 }
    private var avgPace: Double         { runData["avgPaceSecPerKm"] as? Double ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: כרטיס סיכום סטטיסטיקה
                    HStack(spacing: 0) {
                        statCell(label: "KM",   value: String(format: "%.2f", distanceKm))
                        Divider().frame(height: 50)
                        statCell(label: "PACE", value: formatPace(avgPace))
                        Divider().frame(height: 50)
                        statCell(label: "TIME", value: formatDuration(durationSeconds))
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // MARK: כותרת לריצה
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title").font(.caption).foregroundColor(.secondary)
                        TextField("Morning run, evening jog...", text: $title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)

                    // MARK: תיאור הריצה
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes").font(.caption).foregroundColor(.secondary)
                        TextEditor(text: $notes)
                            .frame(height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4)))
                    }
                    .padding(.horizontal)

                    // MARK: בחירת תמונות
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Photos").font(.caption).foregroundColor(.secondary)

                        PhotosPicker(selection: $selectedPhotos,
                                     maxSelectionCount: 5,
                                     matching: .images) {
                            Label("Add Photos", systemImage: "photo.on.rectangle.angled")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                        .onChange(of: selectedPhotos) { _, items in
                            loadImages(from: items)
                        }

                        // תמונה שמופיעה
                        if !selectedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(selectedImages.indices, id: \.self) { i in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: selectedImages[i])
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 90, height: 90)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                            // מחיקה
                                            Button {
                                                selectedImages.remove(at: i)
                                                selectedPhotos.remove(at: i)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Circle())
                                            }
                                            .padding(4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // שגיאה
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }

                    // MARK: העלאת פוסט
                    Button(action: postRun) {
                        if runStore.isUploading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Post Run")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(title.isEmpty ? Color.gray : Color.orange)
                                .cornerRadius(12)
                        }
                    }
                    .disabled(title.isEmpty || runStore.isUploading)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Upload Run")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Run Posted!", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your run has been saved successfully.")
            }
        }
    }

    // MARK: - פעולות

    func postRun() {
        guard !title.isEmpty else { return }

        RunStore.shared.saveRun(
            title: title,
            notes: notes,
            runData: runData,
            photos: selectedImages
        ) { success in
            if success {
                showSuccess = true
            } else {
                errorMessage = "Failed to save run. Please try again."
            }
        }
    }

    func loadImages(from items: [PhotosPickerItem]) {
        selectedImages = []
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                if case .success(let data) = result,
                   let data = data,
                   let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.selectedImages.append(image)
                    }
                }
            }
        }
    }

    // MARK: - פונקציות עזר
    @ViewBuilder
    func statCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2).fontWeight(.semibold).monospacedDigit()
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    func formatPace(_ secPerKm: Double) -> String {
        // פורמט הריצה
        guard secPerKm > 0 else { return "--'--\"" }
        let m = Int(secPerKm) / 60
        let s = Int(secPerKm) % 60
        return String(format: "%d'%02d\"", m, s)
    }

    func formatDuration(_ seconds: Double) -> String {
        //פורמט של כמות הזמן שעבר (הדרך שזה יוצג על המסך)
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
