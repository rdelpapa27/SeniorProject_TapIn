//
//  TipScreenView.swift
//  TapIn
//

import SwiftUI
import FirebaseFirestore
import Combine

struct TipScreenView: View {

    let table: TableInfo
    let subtotal: Double
    let tax: Double
    let totalAmount: Double
    let paymentMethod: String
    
    let db = Firestore.firestore()

    @AppStorage("currentServerName") private var currentServerName = "Server"

    // ✅ FIX 1: Uses standard navigation to go back without breaking the app history!
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTip: String? = nil
    @State private var customTipAmount = ""
    @State private var goThankYou = false

    @State private var tip1: Int = 15
    @State private var tip2: Int = 18
    @State private var tip3: Int = 20

    var computedTip: Double {
        switch selectedTip {
        case "\(tip1)%": return totalAmount * (Double(tip1) / 100.0)
        case "\(tip2)%": return totalAmount * (Double(tip2) / 100.0)
        case "\(tip3)%": return totalAmount * (Double(tip3) / 100.0)
        case "Custom": return Double(customTipAmount) ?? 0
        case "No tip": return 0
        default: return 0
        }
    }

    var finalTotal: Double {
        totalAmount + computedTip
    }

    var body: some View {
        ZStack {
            Color(red: 9/255, green: 34/255, blue: 58/255).ignoresSafeArea()

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
        .onAppear {
            fetchTipSettings()
        }
        .navigationBarHidden(true)
    }

    func fetchTipSettings() {
        db.collection("settings").document("global").getDocument { snap, error in
            if let data = snap?.data() {
                self.tip1 = data["tip1"] as? Int ?? 15
                self.tip2 = data["tip2"] as? Int ?? 18
                self.tip3 = data["tip3"] as? Int ?? 20
            }
        }
    }

    var topBar: some View {
        HStack {
            // ✅ FIX 2: Just dismisses back to the Payment Screen. No table reset happens here!
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left.circle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 36))
            }
            Spacer()
        }
        .padding(.horizontal, 30)
    }

    var tipButtonsSection: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                tipButton("\(tip1)%")
                tipButton("\(tip2)%")
                tipButton("\(tip3)%")
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
                .background(selectedTip == label ? Color.white.opacity(0.35) : Color.white.opacity(0.2))
                .cornerRadius(14)
        }
    }

    var summarySection: some View {
        VStack(spacing: 6) {
            Text("Tip: $\(String(format: "%.2f", computedTip))")
                .foregroundColor(.white.opacity(0.9))

            Text("Final Total: $\(String(format: "%.2f", finalTotal))")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
    }

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
        saveReceipt()
        resetTable() // ✅ Only clears the table once they officially pay!
        goThankYou = true
    }
    
    func saveReceipt() {
        let itemsArray = table.items.map { item in
            [
                "name": item.name,
                "price": item.price,
                "qty": item.qty,
                "notes": item.notes
            ]
        }
        
        let receiptData: [String: Any] = [
            "tableNumber": table.tableNumber,
            "serverName": currentServerName,
            "items": itemsArray,
            "subtotal": subtotal,
            "tax": tax,
            "tip": computedTip,
            "total": finalTotal,
            "paymentMethod": paymentMethod,
            "timestamp": Timestamp(date: Date())
        ]
        
        db.collection("receipts").addDocument(data: receiptData) { err in
            if let err = err {
                print("Error saving receipt: \(err)")
            } else {
                print("Receipt successfully saved to database!")
            }
        }
    }

    func resetTable() {
        db.collection("tables")
            .document(table.tableNumber)
            .updateData([
                "items": [],
                "guests": 0
            ]) { _ in
                print("Table \(table.tableNumber) cleared.")
            }
    }
}
