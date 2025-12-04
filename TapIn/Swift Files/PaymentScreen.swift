//
//  PaymentScreen.swift
//  TapIn
//

import SwiftUI
import FirebaseFirestore

struct PaymentScreen: View {

    let table: TableInfo
    let db = Firestore.firestore()

    @Environment(\.dismiss) private var dismiss

    @State private var selectedMethod: String? = nil
    @State private var tendered: Double = 0
    @State private var remaining: Double = 0
    @State private var goTip = false
    @State private var liveTable: TableInfo

    init(table: TableInfo) {
        self.table = table
        _liveTable = State(initialValue: table)
        _remaining = State(initialValue: 0)
        _tendered = State(initialValue: 0)
    }

    // ===============================================================
    // MARK: - Totals
    // ===============================================================

    var subtotal: Double { liveTable.items.reduce(0) { $0 + ($1.price * Double($1.qty)) } }
    var tax: Double { subtotal * 0.148 }
    var total: Double { subtotal + tax }

    var changeDue: Double {
        max(tendered - total, 0)
    }

    // ===============================================================
    // MARK: - Body
    // ===============================================================

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 30) {

                topBackButton

                HStack(alignment: .top, spacing: 40) {

                    leftTicketPanel
                    rightPaymentPanel
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .navigationDestination(isPresented: $goTip) {
            TipScreenView(totalAmount: total, table: liveTable)
        }
        .onAppear {
            tendered = 0
            remaining = total    // initially full amount remains
            listenToTable()
        }
    }

    // ===============================================================
    // MARK: - Background
    // ===============================================================

    var backgroundLayer: some View {
        ZStack {
            Color(red: 0.02, green: 0.16, blue: 0.27).ignoresSafeArea()

            RoundedRectangle(cornerRadius: 84)
                .fill(Color.orange)
                .frame(width: 540, height: 360)
                .rotationEffect(.degrees(18))
                .offset(x: 500, y: -420)
        }
    }

    // ===============================================================
    // MARK: - Back Button
    // ===============================================================

    var topBackButton: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.largeTitle)
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    // ===============================================================
    // MARK: - Left Ticket Panel
    // ===============================================================

    var leftTicketPanel: some View {

        VStack(spacing: 0) {

            VStack(alignment: .leading, spacing: 8) {
                Text("Table \(table.tableNumber)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black)

                HStack {
                    Image(systemName: "person.fill")
                    Text("Server")
                    Spacer()
                    Image(systemName: "person.2.fill")
                    Text("\(liveTable.guests) guests")
                }
                .font(.system(size: 16))
                .foregroundColor(.black.opacity(0.7))
            }
            .padding()
            .background(Color.white.opacity(0.85))

            Divider()

            ScrollView {
                VStack(spacing: 14) {
                    ForEach(liveTable.itemsGrouped(), id: \.0.id) { grouped in
                        ticketRow(item: grouped.0, quantity: grouped.1)
                    }
                }
                .padding()
            }
            .frame(maxHeight: 320)

            Divider()

            VStack(spacing: 8) {
                HStack {
                    Text("Subtotal:")
                    Spacer()
                    Text(format(subtotal))
                }

                HStack {
                    Text("Tax:")
                    Spacer()
                    Text(format(tax))
                }

                Divider().padding(.vertical, 4)

                HStack {
                    Text("Total:")
                        .fontWeight(.bold)
                    Spacer()
                    Text(format(total))
                        .fontWeight(.bold)
                }
            }
            .font(.system(size: 18))
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .frame(width: 360)
        .background(Color.white.opacity(0.80))
        .cornerRadius(24)
        .shadow(radius: 16)
    }

    func ticketRow(item: MenuItem, quantity: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 18, weight: .medium))

                if !item.notes.isEmpty {
                    Text(item.notes)
                        .foregroundColor(.black.opacity(0.7))
                        .font(.system(size: 15))
                }

                if quantity > 1 {
                    Text("x\(quantity)")
                        .foregroundColor(.black.opacity(0.7))
                        .font(.system(size: 15))
                }
            }

            Spacer()

            Text(format(item.price * Double(quantity)))
                .font(.system(size: 18, weight: .medium))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.6))
        .cornerRadius(10)
    }

    // ===============================================================
    // MARK: - Right Payment Panel
    // ===============================================================

    var rightPaymentPanel: some View {

        VStack(alignment: .leading, spacing: 32) {

            Text("Balance due: \(format(remaining))")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)

            //
            // PAYMENT METHOD BUTTONS
            //
            HStack(spacing: 14) {
                paymentMethodButton("Credit Card")
                paymentMethodButton("Cash")
                paymentMethodButton("Apple Pay")
                paymentMethodButton("Split")
            }

            //
            // CASH SECTION SHOWN ONLY IF "Cash" SELECTED
            //
            if selectedMethod == "Cash" {
                cashTenderSection
            }

            Spacer()
        }
    }

    // ===============================================================
    // MARK: - Payment Method Button
    // ===============================================================

    func paymentMethodButton(_ method: String) -> some View {

        Button {

            selectedMethod = method

            // Card or Apple Pay → auto charge remaining balance
            if method != "Cash" {
                if remaining <= 0 {
                    goTip = true
                } else {
                    // charge only remaining
                    goTip = true
                }
            }

        } label: {
            HStack(spacing: 10) {
                Image(systemName: iconForMethod(method))
                Text(method)
                    .font(.system(size: 20, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color.white.opacity(0.25))
            .cornerRadius(16)
        }
    }

    func iconForMethod(_ method: String) -> String {
        switch method {
        case "Credit Card": return "creditcard"
        case "Cash": return "dollarsign.circle"
        case "Apple Pay": return "applelogo"
        case "Split": return "square.split.2x1"
        default: return "circle"
        }
    }

    // ===============================================================
    // MARK: - CASH TENDER UI
    // ===============================================================

    var cashTenderSection: some View {

        VStack(alignment: .leading, spacing: 20) {

            Text("Cash Tender")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)

            //
            // TENDERED INPUT
            //
            HStack {
                Text("Tendered:")
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                TextField("", value: $tendered, formatter: currencyFormatter)
                    .keyboardType(.decimalPad)
                    .frame(width: 140, height: 44)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .onChange(of: tendered) { _ in updateRemaining() }
            }

            //
            // REMAINING BALANCE (ONLY WHEN tendered < total)
            //
            if tendered < total {
                HStack {
                    Text("Remaining Balance:")
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Text(format(remaining))
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .bold))
                }
            }

            //
            // QUICK BUTTONS (ONLY WHEN NOT FULLY PAID)
            //
            if remaining > 0 {
                HStack(spacing: 14) {
                    tenderQuickAdd(1)
                    tenderQuickAdd(5)
                    tenderQuickAdd(10)
                    tenderQuickAdd(20)
                    exactButton
                }
            }

            //
            // CHANGE DUE (ONLY WHEN OVER-TENDERED)
            //
            if tendered > total {
                HStack {
                    Text("Change Due:")
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Text(format(changeDue))
                        .foregroundColor(.white)
                        .font(.system(size: 22, weight: .bold))
                }
            }

            //
            // CONTINUE BUTTON
            //
            Button(action: handleContinue) {
                Text("Continue")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.green)
                    .cornerRadius(16)
            }
            .padding(.top, 10)
        }
        .padding(.top, 20)
    }

    // ===============================================================
    // MARK: - Quick Tender Buttons
    // ===============================================================

    func tenderQuickAdd(_ amount: Double) -> some View {
        Button {
            tendered += amount
            updateRemaining()
        } label: {
            Text("$\(Int(amount))")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 70, height: 44)
                .background(Color.white.opacity(0.25))
                .cornerRadius(12)
        }
    }

    var exactButton: some View {
        Button {
            tendered = total
            updateRemaining()
        } label: {
            Text("Exact")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 90, height: 44)
                .background(Color.white.opacity(0.25))
                .cornerRadius(12)
        }
    }

    // ===============================================================
    // MARK: - Continue Logic
    // ===============================================================

    func handleContinue() {
        if tendered < total {
            // Partial payment: user must choose another method for remainder
            remaining = total - tendered
            selectedMethod = nil   // temporarily reset selection
        } else {
            // Full or over payment → go tip
            goTip = true
        }
    }

    // ===============================================================
    // MARK: - Helpers
    // ===============================================================

    func updateRemaining() {
        remaining = total - tendered
        if remaining < 0 { remaining = 0 }
    }

    func format(_ v: Double) -> String {
        String(format: "$%.2f", v)
    }

    var currencyFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        return f
    }

    // ===============================================================
    // MARK: - Firestore Listener
    // ===============================================================

    func listenToTable() {
        db.collection("tables")
            .document(table.tableNumber)
            .addSnapshotListener { snap, _ in
                guard let data = snap?.data() else { return }

                let guests = data["guests"] as? Int ?? liveTable.guests

                let itemsArray = data["items"] as? [[String: Any]] ?? []

                let items = itemsArray.compactMap { dict -> MenuItem? in
                    guard
                        let name = dict["name"] as? String,
                        let price = dict["price"] as? Double
                    else { return nil }

                    let qty = dict["qty"] as? Int ?? 1
                    let notes = dict["notes"] as? String ?? ""

                    return MenuItem(name: name, price: price, qty: qty, notes: notes)
                }

                liveTable = TableInfo(
                    tableNumber: table.tableNumber,
                    guests: guests,
                    items: items
                )
            }
    }
}

//
// ===============================================================
// MARK: - GROUPING EXTENSION
// ===============================================================

extension TableInfo {
    func itemsGrouped() -> [(MenuItem, Int)] {

        var groups: [String: (MenuItem, Int)] = [:]

        for item in items {
            let key = "\(item.name)_\(item.notes)"

            if let existing = groups[key] {
                groups[key] = (existing.0, existing.1 + item.qty)
            } else {
                groups[key] = (item, item.qty)
            }
        }

        return groups.values.sorted { $0.0.name < $1.0.name }
    }
}

