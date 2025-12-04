//
//  TipScreenView.swift
//  TapIn
//

import SwiftUI
import FirebaseFirestore

struct TipScreenView: View {

    let totalAmount: Double
    let table: TableInfo
    let db = Firestore.firestore()

    @State private var selectedTip: String? = nil
    @State private var customTipAmount = ""
    @State private var goThankYou = false

    // ----------------------------------------------------------
    // MARK: - Computed Values (unchanged)
    // ----------------------------------------------------------

    var computedTip: Double {
        switch selectedTip {
        case "15%": return totalAmount * 0.15
        case "18%": return totalAmount * 0.18
        case "20%": return totalAmount * 0.20
        case "Custom": return Double(customTipAmount) ?? 0
        case "No tip": return 0
        default: return 0
        }
    }

    var finalTotal: Double {
        totalAmount + computedTip
    }

    // ----------------------------------------------------------
    // MARK: - Body (unchanged UI)
    // ----------------------------------------------------------

    var body: some View {
        ZStack {
            Color(red: 9/255, green: 34/255, blue: 58/255)
                .ignoresSafeArea()

            VStack(spacing: 40) {

                topBar

                VStack(spacing: 10) {
                    Text("Would you like to leave a tip?")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Order Total: $\(String(format: "%.2f", totalAmount))")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.9))
                }

                tipButtonsSection

                summarySection

                Spacer()

                completePaymentButton
            }
            .padding(.top, 20)
        }
        .fullScreenCover(isPresented: $goThankYou) {
            ThankYouView(finalAmount: finalTotal, tableNumber: table.tableNumber)
        }
    }

    // ----------------------------------------------------------
    // MARK: - Top Bar
    // ----------------------------------------------------------

    var topBar: some View {
        HStack {
            Button(action: forceReturnToTables) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 32))
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    func forceReturnToTables() {
        resetTable()

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return }

        window.rootViewController = UIHostingController(
            rootView: NavigationStack { TableViewRoom() }
        )
        window.makeKeyAndVisible()
    }

    // ----------------------------------------------------------
    // MARK: - Tip Button Section
    // ----------------------------------------------------------

    var tipButtonsSection: some View {
        VStack(spacing: 20) {

            HStack(spacing: 20) {
                tipButton("15%")
                tipButton("18%")
                tipButton("20%")
            }

            HStack(spacing: 20) {
                tipButton("Custom")
                tipButton("No tip")
            }

            if selectedTip == "Custom" {
                TextField("Enter custom tip", text: $customTipAmount)
                    .keyboardType(.decimalPad)
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
                    .padding(.horizontal, 80)
            }
        }
    }

    func tipButton(_ label: String) -> some View {
        Button(action: { selectedTip = label }) {
            Text(label)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 160, height: 70)
                .background(
                    selectedTip == label
                    ? Color.white.opacity(0.35)
                    : Color.white.opacity(0.2)
                )
                .cornerRadius(14)
        }
    }

    // ----------------------------------------------------------
    // MARK: - Summary
    // ----------------------------------------------------------

    var summarySection: some View {
        VStack(spacing: 6) {
            Text("Tip: $\(String(format: "%.2f", computedTip))")
                .foregroundColor(.white.opacity(0.9))

            Text("Final Total: $\(String(format: "%.2f", finalTotal))")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
    }

    // ----------------------------------------------------------
    // MARK: - Complete Payment Button
    // ----------------------------------------------------------

    var completePaymentButton: some View {
        Button(action: completePayment) {
            Text("Complete Payment")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.green)
                .cornerRadius(14)
                .padding(.horizontal, 80)
        }
        .padding(.bottom, 60)
    }

    func completePayment() {
        resetTable()
        goThankYou = true
    }

    // ----------------------------------------------------------
    // MARK: - Reset Table (compatible with qty + notes)
    // ----------------------------------------------------------

    func resetTable() {
        db.collection("tables")
            .document(table.tableNumber)
            .updateData([
                "items": [],      // clears all qty + notes items
                "guests": 0
            ]) { _ in
                print("Table \(table.tableNumber) cleared from TipScreenView.")
            }
    }
}

