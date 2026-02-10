//
//  LogInView.swift
//

import SwiftUI
import FirebaseFirestore

struct LogInView: View {

    @State private var goServer = false
    @State private var goKitchen = false
    @State private var goAdmin = false

    var body: some View {
        PasscodeView(
            goServer: $goServer,
            goKitchen: $goKitchen,
            goAdmin: $goAdmin
        )
        .navigationDestination(isPresented: $goServer) {
            TableViewRoom()
        }
        .navigationDestination(isPresented: $goKitchen) {
            KitchenDashboard()   // ✅ FIX — was Text("Kitchen View")
        }
        .navigationDestination(isPresented: $goAdmin) {
            Text("Admin Dashboard")
        }
    }
}

struct PasscodeView: View {

    @Binding var goServer: Bool
    @Binding var goKitchen: Bool
    @Binding var goAdmin: Bool

    @State private var passcode: [String] = []
    @State private var loginError = false
    @State private var isLoading = false

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ZStack {

            // ORIGINAL DARK NAVY BACKGROUND
            Color(red: 0.0078, green: 0.188, blue: 0.278)
                .ignoresSafeArea()

            // ORIGINAL TOP-LEFT ORANGE SHAPE
            RoundedRectangle(cornerRadius: 84)
                .fill(Color(red: 0.984, green: 0.522, blue: 0.000).opacity(0.7333))
                .frame(width: 649.91, height: 691.79)
                .rotationEffect(.degrees(55))
                .offset(x: -500, y: -400)

            // ORIGINAL BOTTOM-RIGHT ORANGE SHAPE
            RoundedRectangle(cornerRadius: 84)
                .fill(Color(red: 0.984, green: 0.522, blue: 0.000))
                .frame(width: 646.88, height: 490.5)
                .rotationEffect(.degrees(26))
                .offset(x: 600, y: 400)

            VStack(spacing: 30) {

                VStack(spacing: 8) {
                    Text("TapIn")
                        .font(.system(size: 50, weight: .medium, design: .rounded))
                        .foregroundColor(.white)

                    Rectangle()
                        .frame(width: 100, height: 2)
                        .foregroundColor(.white)

                    Text("Enter Passcode")
                        .padding(.top, 10)
                        .font(.system(size: 30))
                        .foregroundColor(.white.opacity(0.8))

                    if loginError {
                        Text("Incorrect Pin")
                            .foregroundColor(.red)
                            .font(.headline)
                    }

                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                }

                // PASSCODE DOTS
                HStack(spacing: 20) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(index < passcode.count ? Color.white : Color.gray.opacity(0.5))
                            .frame(width: 30, height: 30)
                    }
                }
                .padding(.bottom, 20)

                // KEYPAD
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(1..<10) { number in
                        keypadButton(title: "\(number)")
                    }

                    keypadButton(title: "X.circle", isSystemImage: true, action: clearPasscode)
                    keypadButton(title: "0")
                    keypadButton(title: "delete.left", isSystemImage: true, action: removeLastDigit)
                }
                .padding(.horizontal, 350)
            }
            .padding()
        }
    }

    // BUTTON VIEW
    @ViewBuilder
    func keypadButton(title: String, isSystemImage: Bool = false, action: (() -> Void)? = nil) -> some View {
        Button(action: {
            if let action = action {
                action()
            } else {
                if passcode.count < 4 {
                    passcode.append(title)
                    if passcode.count == 4 {
                        validatePin()
                    }
                }
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 70)

                if isSystemImage {
                    Image(systemName: title)
                        .font(.title2)
                        .foregroundColor(.white)
                } else {
                    Text(title)
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
        }
    }

    func clearPasscode() { passcode.removeAll() }
    func removeLastDigit() { if !passcode.isEmpty { passcode.removeLast() } }

    func validatePin() {
        isLoading = true
        loginError = false

        let pin = passcode.joined()
        let db = Firestore.firestore()

        db.collection("users")
            .whereField("pin", isEqualTo: pin)
            .getDocuments { snapshot, error in

                isLoading = false

                if error != nil || snapshot?.documents.isEmpty == true {
                    loginError = true
                    reset()
                    return
                }

                let doc = snapshot!.documents.first!
                let role = doc.get("role") as? String ?? ""

                switch role {
                case "server": goServer = true
                case "kitchen": goKitchen = true
                case "admin": goAdmin = true
                default: loginError = true
                }

                reset()
            }
    }

    func reset() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            passcode.removeAll()
        }
    }
}

