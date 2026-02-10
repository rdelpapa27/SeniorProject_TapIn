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
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // -----------------------------
        // Firebase initialization
        // -----------------------------
        FirebaseApp.configure()
        print("Firebase Configured.")

        // -----------------------------
        // Cloudflare Worker test call
        // -----------------------------
        let url = URL(string: "https://worker.robertimanol2.workers.dev/api/status")!

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Cloudflare error:", error)
                return
            }

            if let data = data {
                print("Cloudflare response:")
                print(String(decoding: data, as: UTF8.self))
            }
        }.resume()

        return true
    }
}

