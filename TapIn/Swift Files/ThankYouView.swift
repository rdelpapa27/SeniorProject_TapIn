//
//  ThankYouView.swift
//  TapIn
//

import SwiftUI
import FirebaseFirestore

struct ThankYouView: View {

    let finalAmount: Double
    let tableNumber: String

    private let db = Firestore.firestore()
    @State private var animateCheck = false
    
    // ✅ NEW: Native dismiss action
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 9/255, green: 34/255, blue: 58/255)
                .ignoresSafeArea()

            VStack(spacing: 32) {

                Spacer()

                VStack(spacing: 16) {
                    Text("Payment Complete")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)

                    Text("$\(String(format: "%.2f", finalAmount))")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }

                ZStack {
                    Circle()
                        .stroke(Color.green, lineWidth: 8)
                        .frame(width: 160, height: 160)

                    Image(systemName: "checkmark")
                        .font(.system(size: 88, weight: .bold))
                        .foregroundColor(.green)
                        .scaleEffect(animateCheck ? 1.0 : 0.4)
                        .opacity(animateCheck ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateCheck)
                }

                Text("Thank you!")
                    .foregroundColor(.white.opacity(0.9))
                    .font(.system(size: 24))

                Spacer()
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            resetTable()
            animateIn()
            autoReturn()
        }
    }

    // ----------------------------------------------------------
    // MARK: - Animation
    // ----------------------------------------------------------

    func animateIn() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            animateCheck = true
        }
    }

    // ----------------------------------------------------------
    // MARK: - Reset Table in Firestore
    // ----------------------------------------------------------

    func resetTable() {
        db.collection("tables")
            .document(tableNumber)
            .updateData([
                "items": [],
                "guests": 0
            ]) { err in
                if let err = err {
                    print("Error resetting table: \(err)")
                } else {
                    print("Table \(tableNumber) cleared by ThankYouView.")
                }
            }
    }

    // ----------------------------------------------------------
    // MARK: - Safe Auto Return
    // ----------------------------------------------------------

    func autoReturn() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // ✅ FIX: Drops the Thank You screen
            dismiss()
            
            // ✅ FIX: Tells the Floor Plan to safely retract all navigation views
            NotificationCenter.default.post(name: NSNotification.Name("ReturnToFloorPlan"), object: nil)
        }
    }
}
