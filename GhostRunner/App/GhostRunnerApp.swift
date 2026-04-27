// GhostRunnerApp.swift
import SwiftUI
import FirebaseCore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()             //קונפיגורציה של שרת הפיירבייס
        return true
    }
}

@main
struct GhostRunnerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var isLoggedIn: Bool = false

    var body: some Scene {
        WindowGroup {
            Group {
                if isLoggedIn { MainTabView() }
                else          { LoginView() }
            }
            .onAppear {
                Auth.auth().addStateDidChangeListener { _, user in
                    DispatchQueue.main.async {
                        isLoggedIn = user != nil
                    }
                }
            }
        }
    }
}
