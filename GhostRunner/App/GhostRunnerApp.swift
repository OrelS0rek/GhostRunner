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

    @State private var isLoggedIn: Bool = false //משתנה האם הלקוח מחובר

    var body: some Scene {
        WindowGroup {
            Group {
                if isLoggedIn {
                    MainTabView()               //במידה והלקוח מחובר להראות לו את מסך הניווט והבית
                } else {
                    LoginView()                 //במידה ואינו מחובר להראות לו את מסך ההתחברות
                }
            }
            .onAppear {
                isLoggedIn = Auth.auth().currentUser != nil
            }
        }
    }
}
