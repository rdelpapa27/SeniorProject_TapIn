//
//  PaymentScreen.swift
//  TapIn
//

import SwiftUI
import FirebaseFirestore
import Combine


struct PaymentScreen: View {

    let table: TableInfo
    let db = Firestore.firestore()

    @Environment(\.dismiss) private var dismiss

    @State private var selectedMethod: String? = nil
    @State private var tendered: Double = 0
    @State private var remaining: Double = 0
    @State private var goTip = false
    @State private var liveTable: TableInfo

    // DYNAMIC TAX RATE (Defaults to 14.8%, updates from Firebase)
    @State private var taxRate: Double = 0.148

    // FREEZE TOTALS
    @State private var frozenSubtotal: Double = 0
    @State private var frozenTax: Double = 0
    @State private var frozenTotal: Double = 0

    init(table: TableInfo) {
        self.table = table
        _liveTable = State(initialValue: table)
        _remaining = State(initialValue: 0)
        _tendered = State(initialValue: 0)

        // Initial compute (will be overwritten if Firebase has a different tax rate)
        let initialSubtotal = table.items.reduce(0) { $0 + ($1.price * Double($1.qty)) }
        let initialTax = initialSubtotal * 0.148
        let initialTotal = initialSubtotal + initialTax

        _frozenSubtotal = State(initialValue: initialSubtotal)
        _frozenTax = State(initialValue: initialTax)
        _frozenTotal = State(initialValue: initialTotal)
    }

    // ===============================================================
    // MARK: - Totals (LIVE for ticket rows, FROZEN for payment)
    // ===============================================================

    var liveSubtotal: Double { liveTable.items.reduce(0) { $0 + ($1.price * Double($1.qty)) } }
    var liveTax: Double { liveSubtotal * taxRate } // ✅ Now dynamic!
    var liveTotal: Double { liveSubtotal + liveTax }

    var changeDue: Double {
        max(tendered - frozenTotal, 0)
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
            TipScreenView(
                table: table,
                subtotal: frozenSubtotal,
                tax: frozenTax,
                totalAmount: frozenTotal,
                paymentMethod: selectedMethod ?? "Unknown"
            )
        }
        .onAppear {
            tendered = 0
            remaining = frozenTotal
            fetchGlobalSettings() // ✅ Fetch the custom tax rate!
            listenToTable()
        }
    }

    // ===============================================================
    // MARK: - Settings Fetcher
    // ===============================================================
    func fetchGlobalSettings() {
        db.collection("settings").document("global").getDocument { snap, error in
            if let data = snap?.data() {
                // Get tax rate (e.g., 14.8) and convert to decimal (0.148)
                let fetchedTax = data["taxRate"] as? Double ?? 14.8
                self.taxRate = fetchedTax / 100.0
                
                // Recalculate frozen totals with the new tax rate
                self.frozenTax = self.frozenSubtotal * self.taxRate
                self.frozenTotal = self.frozenSubtotal + self.frozenTax
                self.remaining = self.frozenTotal - self.tendered
            }
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
                    Text(format(frozenSubtotal))
                }

                HStack {
                    Text(String(format: "Tax (%.1f%%):", taxRate * 100))
                    Spacer()
                    Text(format(frozenTax))
                }

                Divider().padding(.vertical, 4)

                HStack {
                    Text("Total:")
                        .fontWeight(.bold)
                    Spacer()
                    Text(format(frozenTotal))
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

            HStack(spacing: 14) {
                paymentMethodButton("Credit Card")
                paymentMethodButton("Cash")
                paymentMethodButton("Apple Pay")
                paymentMethodButton("Split")
            }

            if selectedMethod == "Cash" {
                cashTenderSection
            }

            Spacer()
        }
    }

    func paymentMethodButton(_ method: String) -> some View {
        Button {
            selectedMethod = method
            if method != "Cash" { goTip = true }
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

            if tendered < frozenTotal {
                HStack {
                    Text("Remaining Balance:")
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Text(format(remaining))
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .bold))
                }
            }

            if remaining > 0 {
                HStack(spacing: 14) {
                    tenderQuickAdd(1)
                    tenderQuickAdd(5)
                    tenderQuickAdd(10)
                    tenderQuickAdd(20)
                    exactButton
                }
            }

            if tendered > frozenTotal {
                HStack {
                    Text("Change Due:")
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Text(format(changeDue))
                        .foregroundColor(.white)
                        .font(.system(size: 22, weight: .bold))
                }
            }

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
            tendered = frozenTotal
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

    func handleContinue() {
        if tendered < frozenTotal {
            remaining = frozenTotal - tendered
            selectedMethod = nil
        } else {
            goTip = true
        }
    }

    func updateRemaining() {
        remaining = frozenTotal - tendered
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

                liveTable = TableInfo(tableNumber: table.tableNumber, guests: guests, items: items)
            }
    }
}

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
