// HomeView.swift
// GhostRunner

import SwiftUI
import FirebaseFirestore

struct HomeView: View {
    @ObservedObject private var friendManager = FriendManager.shared
    @ObservedObject private var userManager   = UserManager.shared

    @State private var searchQuery = ""
    @State private var showingRequests = false
    @State private var searchDebounce: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // MARK: Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search runners...", text: $searchQuery)
                        .autocapitalization(.words)
                        .onChange(of: searchQuery) { _, query in
                            searchDebounce?.cancel()
                            searchDebounce = Task {
                                try? await Task.sleep(nanoseconds: 400_000_000)
                                FriendManager.shared.searchUsers(query: query)
                            }
                        }
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                            friendManager.searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // MARK: Search results or feed
                if !searchQuery.isEmpty {
                    searchResultsView
                } else {
                    feedView
                }
            }
            .navigationTitle("GhostRunner")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingRequests = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                            if !friendManager.friendRequests.isEmpty {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingRequests) {
                FriendRequestsView()
            }
            .onAppear {
                FriendManager.shared.fetchFriends()
                FriendManager.shared.fetchFriendRequests()
            }
        }
    }

    // MARK: - Search results
    @ViewBuilder
    var searchResultsView: some View {
        if friendManager.isSearching {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if friendManager.searchResults.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "person.slash")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No runners found")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(friendManager.searchResults) { user in
                UserSearchRow(user: user)
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Friends feed
    @ViewBuilder
    var feedView: some View {
        if friendManager.friends.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "person.2")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                Text("Find your running crew")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Search for runners above to add friends.\nTheir runs will appear here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else if friendManager.friendsFeed.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "figure.run")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text("No runs from friends yet")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(friendManager.friendsFeed) { run in
                        NavigationLink(destination: RunDetailView(run: run.toRunPost())) {
                            FeedRunCard(run: run)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
    }
}

// MARK: - User search row
struct UserSearchRow: View {
    let user: UserProfile
    @State private var status: FriendshipStatus = .none
    @State private var isLoading = false

    var body: some View {
        HStack(spacing: 12) {
            if !user.profileImageURL.isEmpty,
               let url = URL(string: user.profileImageURL) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Color(.systemGray4)
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 44, height: 44)
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName).font(.headline)
                Text("\(user.totalRuns) runs · \(String(format: "%.1f", user.totalKm)) km")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: sendRequest) {
                if isLoading {
                    ProgressView()
                } else {
                    switch status {
                    case .none:
                        Label("Add", systemImage: "person.badge.plus")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    case .requestSent:
                        Text("Pending")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .cornerRadius(20)
                    case .friends:
                        Label("Friends", systemImage: "checkmark")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(20)
                    }
                }
            }
            .disabled(status != .none || isLoading)
        }
        .padding(.vertical, 4)
        .onAppear {
            FriendManager.shared.friendshipStatus(with: user.id) { s in
                DispatchQueue.main.async { status = s }
            }
        }
    }

    func sendRequest() {
        isLoading = true
        FriendManager.shared.sendFriendRequest(to: user) { success in
            DispatchQueue.main.async {
                isLoading = false
                if success { status = .requestSent }
            }
        }
    }
}

// MARK: - Friend requests sheet
struct FriendRequestsView: View {
    @ObservedObject private var friendManager = FriendManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if friendManager.friendRequests.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bell.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No pending requests")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(friendManager.friendRequests) { user in
                        HStack(spacing: 12) {
                            if !user.profileImageURL.isEmpty,
                               let url = URL(string: user.profileImageURL) {
                                AsyncImage(url: url) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: { Color(.systemGray4) }
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 44, height: 44)
                                    .foregroundColor(.orange)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName).font(.headline)
                                Text("\(user.totalRuns) runs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            HStack(spacing: 8) {
                                Button("Accept") {
                                    FriendManager.shared.acceptFriendRequest(from: user) { _ in }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                                .controlSize(.small)

                                Button("Decline") {
                                    FriendManager.shared.declineFriendRequest(from: user)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Friend Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Feed run card
struct FeedRunCard: View {
    let run: FeedRun
    @State private var authorName: String = ""
    @State private var authorImageURL: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Author header
            HStack(spacing: 10) {
                if !authorImageURL.isEmpty,
                   let url = URL(string: authorImageURL) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: { Color(.systemGray4) }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 36, height: 36)
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(authorName.isEmpty ? "Runner" : authorName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(run.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

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

            Text(run.title).font(.headline)

            HStack(spacing: 16) {
                Label(String(format: "%.2f km", run.distanceKm), systemImage: "map")
                Label(formatPace(run.avgPaceSecPerKm),            systemImage: "speedometer")
                Label(formatDuration(run.durationSeconds),        systemImage: "clock")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            if !run.notes.isEmpty {
                Text(run.notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            if !run.photoURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(run.photoURLs, id: \.self) { urlString in
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: { Color(.systemGray5) }
                                .frame(width: 120, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .onAppear { fetchAuthor() }
    }

    func fetchAuthor() {
        let db = Firestore.firestore()
        db.collection("users").document(run.userId).getDocument { snapshot, _ in
            guard let data = snapshot?.data() else { return }
            DispatchQueue.main.async {
                authorName     = data["displayName"] as? String ?? ""
                authorImageURL = data["profileImageURL"] as? String ?? ""
            }
        }
    }

    func formatPace(_ secPerKm: Double) -> String {
        guard secPerKm > 0 else { return "--'--\"" }
        let m = Int(secPerKm) / 60; let s = Int(secPerKm) % 60
        return String(format: "%d'%02d\"", m, s)
    }

    func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds); let h = total / 3600
        let m = (total % 3600) / 60; let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%02d:%02d", m, s)
    }
}
