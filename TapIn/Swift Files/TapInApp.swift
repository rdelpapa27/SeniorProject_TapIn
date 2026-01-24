//
//  TapInApp.swift
//  TapIn
//

import SwiftUI
import Firebase

@main
struct TapInApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                LogInView()
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        // Firebase only — CLEAN, NO DB SEEDING
        FirebaseApp.configure()
        print("Firebase Configured.")

        return true
    }
}

