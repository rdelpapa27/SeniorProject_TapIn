//
//  TapInApp.swift
//  TapIn
//
import SwiftUI

@main
struct TapInApp: App {
    var body: some Scene {
        WindowGroup {
            PasscodeView()
        }
    }
}

struct PasscodeView: View {
    @State private var passcode: [String] = []
    let correctPasscode = ["1", "2", "3", "4"]
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    // error state
    @State private var showError = false
    
    var body: some View {
        ZStack {
            // Background color
            Color(red: 0.0078, green: 0.188, blue: 0.278) // RGB for #023047
                .ignoresSafeArea()
            
            // Top-left orange shape (73.33% opacity)
            RoundedRectangle(cornerRadius: 84)
                .fill(Color(red: 0.984, green: 0.522, blue: 0.000).opacity(0.7333))
                .frame(width: 649.91, height: 691.79)
                .rotationEffect(.degrees(55))
                .offset(x: -500, y: -400)
                
            // Bottom-right orange shape (100% opacity)
            RoundedRectangle(cornerRadius: 84)
                .fill(Color(red: 0.984, green: 0.522, blue: 0.000))
                .frame(width: 646.88, height: 490.5)
                .rotationEffect(.degrees(26))
                .offset(x: 600, y: 400)
            
            VStack(spacing: 30) {
                // Title
                VStack(spacing: 8) {
                    Text("TapIn")
                        .font(.system(size: 50, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    
                    Rectangle()
                        .frame(width: 100, height: 2)
                        .foregroundColor(.white)
                    
                    Text("Enter Passcode")
                        .padding()
                        .font(.system(size:30))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 10)
                    
                    if showError {
                        Text("Incorrect Pin")
                            .foregroundColor(.red)
                            .font(.headline)
                            .padding(.top, 4)
                            .transition(.opacity)
                    }

                }
                
                // Passcode Dots
                HStack(spacing: 20) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(index < passcode.count ? Color.white : Color.gray.opacity(0.5))
                            .frame(width: 30, height: 30)
                    }
                }
                .padding(.bottom, 20)
                
                // Keypad
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
    
    // MARK: - Button View
    @ViewBuilder
    func keypadButton(title: String, isSystemImage: Bool = false, action: (() -> Void)? = nil) -> some View {
        Button(action: {
            if let action = action {
                action()
            } else {
                if passcode.count < 4 {
                    passcode.append(title)
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
    
    // MARK: - Button Actions
    func clearPasscode() {
        passcode.removeAll()
    }
    
    func removeLastDigit() {
        if !passcode.isEmpty {
            passcode.removeLast()
        }
    }
}

#Preview {
    PasscodeView()
}
