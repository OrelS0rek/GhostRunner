// MainTabView.swift
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            RunView()
                .tabItem { Label("Run", systemImage: "figure.run") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .accentColor(.orange)
        .onAppear {
            UserManager.shared.fetchProfile()
            RunStore.shared.fetchMyRuns()
        }
    }
}




