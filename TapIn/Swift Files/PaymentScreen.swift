//
//  PaymentScreen.swift
//  TapIn
//

import SwiftUI
import FirebaseFirestore
import Combine

// ===============================================================
// MARK: - PRO MODELS FOR SPLIT CHECK
// ===============================================================
struct SplitItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let price: Double
    let notes: String
    let course: Int    // ✅ Preserves course through payment
    let isFired: Bool  // ✅ Preserves fired status through payment
}

struct ProSeat: Identifiable {
    let id = UUID()
    let seatNumber: Int
    var items: [SplitItem] = []
    var isPaid: Bool = false
    
    var subtotal: Double { items.reduce(0) { $0 + $1.price } }
    var tax: Double { subtotal * 0.148 } // Global 14.8% tax
    var total: Double { subtotal + tax }
}

// ===============================================================
// MARK: - INLINE TIP OVERLAY (ONLY FOR SPLIT CHECKS)
// ===============================================================
struct SplitTipOverlay: View {
    let subtotal: Double
    let total: Double
    let onSelectTip: (Double) -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Select Tip Amount")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 20) {
                    tipButton(percentage: 0.15)
                    tipButton(percentage: 0.18)
                    tipButton(percentage: 0.20)
                }
                
                Button(action: { onSelectTip(0.0) }) {
                    Text("No Tip")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                }
            }
            .padding(40)
            .background(Color(red: 0.05, green: 0.20, blue: 0.35))
            .cornerRadius(24)
            .shadow(radius: 20)
        }
    }
    
    func tipButton(percentage: Double) -> some View {
        let tipAmount = subtotal * percentage
        return Button(action: { onSelectTip(tipAmount) }) {
            VStack(spacing: 12) {
                Text("\(Int(percentage * 100))%")
                    .font(.system(size: 32, weight: .bold))
                Text(String(format: "+$%.2f", tipAmount))
                    .font(.system(size: 20, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(width: 140, height: 140)
            .background(Color.blue)
            .cornerRadius(16)
        }
    }
}

// ===============================================================
// MARK: - PAYMENT SCREEN
// ===============================================================
struct PaymentScreen: View {
    
    @State var table: TableInfo
    @Environment(\.dismiss) private var dismiss
    
    // Navigation States
    @State private var showSplitView = false
    @State private var showYourTipScreen = false
    @State private var pendingPaymentMethod = ""
    
    var subtotal: Double { table.items.reduce(0) { $0 + ($1.price * Double($1.qty)) } }
    var tax: Double { subtotal * 0.148 }
    var total: Double { subtotal + tax }
    
    let navy = Color(red: 0.02, green: 0.16, blue: 0.27)
    
    var body: some View {
        ZStack {
            navy.ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("Payment: Table \(table.tableNumber)")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.left").opacity(0)
                }
                .padding(.horizontal, 40)
                
                HStack(alignment: .top, spacing: 40) {
                    // LEFT: Order Summary
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Order Summary")
                            .font(.title2).bold().foregroundColor(.white)
                        
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(table.items) { item in
                                    HStack {
                                        Text("\(item.qty)x \(item.name)")
                                        Spacer()
                                        Text(String(format: "$%.2f", item.price * Double(item.qty)))
                                    }
                                    .foregroundColor(.white.opacity(0.9))
                                    .font(.system(size: 18))
                                }
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.3))
                        
                        VStack(spacing: 10) {
                            summaryRow(label: "Subtotal", value: subtotal)
                            summaryRow(label: "Tax (14.8%)", value: tax)
                            HStack {
                                Text("Total")
                                    .font(.system(size: 28, weight: .bold))
                                Spacer()
                                Text(String(format: "$%.2f", total))
                                    .font(.system(size: 28, weight: .bold))
                            }
                            .foregroundColor(.orange)
                        }
                    }
                    .padding(30)
                    .frame(width: 400)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(20)
                    
                    // RIGHT: Payment Options
                    VStack(spacing: 20) {
                        paymentButton(title: "Credit / Apple Pay", icon: "creditcard.fill", color: .blue) {
                            pendingPaymentMethod = "Credit Card"
                            showYourTipScreen = true
                        }
                        
                        paymentButton(title: "Cash", icon: "banknote.fill", color: .green) {
                            pendingPaymentMethod = "Cash"
                            showYourTipScreen = true
                        }
                        
                        paymentButton(title: "Split Bill", icon: "scissors", color: .purple) {
                            showSplitView = true
                        }
                        
                        Spacer()
                        
                        Button(action: { dismiss() }) {
                            Text("Cancel Payment")
                                .foregroundColor(.red)
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 40)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showSplitView) {
            SplitCheckView(table: table)
        }
        .navigationDestination(isPresented: $showYourTipScreen) {
            TipScreenView(
                table: table,
                subtotal: subtotal,
                tax: tax,
                totalAmount: total,
                paymentMethod: pendingPaymentMethod
            )
        }
    }
    
    func summaryRow(label: String, value: Double) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: "$%.2f", value))
        }
        .foregroundColor(.white.opacity(0.7))
        .font(.system(size: 20))
    }
    
    func paymentButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.system(size: 24, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(color)
            .cornerRadius(16)
            .shadow(radius: 5)
        }
    }
}

// ===============================================================
// MARK: - SPLIT CHECK VIEW
// ===============================================================
struct SplitCheckView: View {
    @State var table: TableInfo
    @Environment(\.dismiss) private var dismiss
    
    @State private var unassignedItems: [SplitItem] = []
    @State private var seats: [ProSeat] = [ProSeat(seatNumber: 1), ProSeat(seatNumber: 2)]
    
    @State private var selectedItem: SplitItem? = nil
    @State private var splitMode: SplitMode = .byItem
    @State private var splitEvenlyWays: Int = 2
    @State private var paidFractions: Set<Int> = []
    
    @State private var showInlineTipSelection = false
    @State private var showThankYou = false
    @State private var payingSeat: ProSeat? = nil
    @State private var payingFraction: Double? = nil
    @State private var pendingFractionIndex: Int? = nil
    @State private var finalAmountForThankYou: Double = 0.0
    
    enum SplitMode { case byItem, evenly }
    
    let navy = Color(red: 0.02, green: 0.16, blue: 0.27)
    let panelBlue = Color(red: 0.05, green: 0.25, blue: 0.35)
    let db = Firestore.firestore()
    
    var tableSubtotal: Double { table.items.reduce(0) { $0 + ($1.price * Double($1.qty)) } }
    var tableTax: Double { tableSubtotal * 0.148 }
    var tableTotal: Double { tableSubtotal + tableTax }
    var unassignedTotal: Double { unassignedItems.reduce(0) { $0 + $1.price } }
    
    var body: some View {
        ZStack(alignment: .top) {
            navy.ignoresSafeArea()
            
            VStack(spacing: 20) {
                header
                
                Picker("Split Mode", selection: $splitMode) {
                    Text("Split by Item").tag(SplitMode.byItem)
                    Text("Split Evenly").tag(SplitMode.evenly)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 40)
                .frame(width: 400)
                
                if splitMode == .byItem {
                    splitByItemView
                } else {
                    splitEvenlyView
                }
            }
            
            if showInlineTipSelection {
                let subForTip = payingSeat != nil ? payingSeat!.subtotal : (payingFraction! / 1.148)
                let totForTip = payingSeat != nil ? payingSeat!.total : payingFraction!
                
                SplitTipOverlay(subtotal: subForTip, total: totForTip) { tipAmount in
                    withAnimation { showInlineTipSelection = false }
                    
                    if let seat = payingSeat {
                        if let idx = seats.firstIndex(where: { $0.id == seat.id }) {
                            seats[idx].isPaid = true
                            processSeatPayment(for: seats[idx], tip: tipAmount)
                        }
                        payingSeat = nil
                    } else if let fraction = payingFraction, let idx = pendingFractionIndex {
                        paidFractions.insert(idx)
                        processEvenPayment(amount: fraction, tip: tipAmount)
                        payingFraction = nil
                        pendingFractionIndex = nil
                    }
                }
                .zIndex(10)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            flattenTableItems()
        }
        .fullScreenCover(isPresented: $showThankYou) {
            ThankYouView(finalAmount: finalAmountForThankYou, tableNumber: table.tableNumber)
        }
    }
    
    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back to Payment")
                }
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
            }
            
            Spacer()
            
            VStack {
                Text("Split Check: Table \(table.tableNumber)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                if splitMode == .byItem {
                    Text(unassignedItems.isEmpty ? "All items assigned!" : "Select an item, then tap a seat")
                        .font(.system(size: 16))
                        .foregroundColor(unassignedItems.isEmpty ? .green : .orange)
                }
            }
            
            Spacer()
            
            Button(action: {}) { Text("Back to Payment") }.opacity(0)
        }
        .padding(.horizontal, 40)
        .padding(.top, 20)
    }
    
    private var splitByItemView: some View {
        HStack(alignment: .top, spacing: 30) {
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Unassigned Items")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "$%.2f", unassignedTotal))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.gray)
                }
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(unassignedItems) { item in
                            let isSelected = selectedItem?.id == item.id
                            
                            Button(action: {
                                withAnimation(.spring()) {
                                    selectedItem = isSelected ? nil : item
                                }
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(item.name)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(isSelected ? .black : .white)
                                        if !item.notes.isEmpty {
                                            Text(item.notes)
                                                .font(.system(size: 14))
                                                .foregroundColor(isSelected ? .black.opacity(0.7) : .gray)
                                        }
                                    }
                                    Spacer()
                                    Text(String(format: "$%.2f", item.price))
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(isSelected ? .black : .white)
                                }
                                .padding()
                                .background(isSelected ? Color.orange : Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                }
            }
            .padding(24)
            .frame(width: 380)
            .background(panelBlue)
            .cornerRadius(20)
            
            VStack {
                HStack(spacing: 12) {
                    Text("Seats")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if seats.count > 2 {
                        Button(action: {
                            withAnimation {
                                if let last = seats.last, last.items.isEmpty, !last.isPaid {
                                    seats.removeLast()
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "minus.circle.fill")
                                Text("Remove")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background((seats.last?.items.isEmpty == true && seats.last?.isPaid == false) ? Color.red : Color.gray)
                            .cornerRadius(10)
                        }
                        .disabled(seats.last?.items.isEmpty == false || seats.last?.isPaid == true)
                    }
                    
                    Button(action: {
                        withAnimation { seats.append(ProSeat(seatNumber: seats.count + 1)) }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Seat")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 20) {
                        ForEach($seats) { $seat in
                            seatCard(seat: $seat)
                        }
                    }
                    .padding()
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 20)
    }
    
    private func seatCard(seat: Binding<ProSeat>) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                if let item = selectedItem, !seat.wrappedValue.isPaid {
                    assignItem(item, to: seat.wrappedValue.id)
                }
            }) {
                HStack {
                    Text("Seat \(seat.wrappedValue.seatNumber)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor((selectedItem != nil && !seat.wrappedValue.isPaid) ? .white : .gray)
                    Spacer()
                    if selectedItem != nil && !seat.wrappedValue.isPaid {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                .background((selectedItem != nil && !seat.wrappedValue.isPaid) ? Color.blue.opacity(0.8) : Color.white.opacity(0.1))
            }
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(seat.wrappedValue.items) { item in
                        Button(action: {
                            if !seat.wrappedValue.isPaid {
                                returnItemToUnassigned(item, from: seat.wrappedValue.id)
                            }
                        }) {
                            HStack {
                                Text(item.name)
                                    .font(.system(size: 16))
                                    .foregroundColor(seat.wrappedValue.isPaid ? .gray : .white)
                                Spacer()
                                if !seat.wrappedValue.isPaid {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(12)
            }
            .frame(height: 300)
            
            Divider().background(Color.white.opacity(0.3))
            
            VStack(spacing: 8) {
                HStack {
                    Text("Total:")
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "$%.2f", seat.wrappedValue.total))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Button(action: {
                    payingSeat = seat.wrappedValue
                    showInlineTipSelection = true
                }) {
                    Text(seat.wrappedValue.isPaid ? "PAID" : "Pay Seat")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(seat.wrappedValue.isPaid ? Color.gray : Color.green)
                        .cornerRadius(10)
                }
                .disabled(seat.wrappedValue.isPaid || seat.wrappedValue.items.isEmpty)
            }
            .padding()
        }
        .frame(width: 280)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke((selectedItem != nil && !seat.wrappedValue.isPaid) ? Color.orange.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 2)
        )
    }
    
    private var splitEvenlyView: some View {
        VStack(spacing: 40) {
            Text("Split Total Evenly")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 40)
            
            HStack(spacing: 30) {
                Button(action: {
                    if splitEvenlyWays > 2 {
                        splitEvenlyWays -= 1
                        paidFractions.removeAll()
                    }
                }) {
                    Image(systemName: "minus.circle.fill").font(.system(size: 60)).foregroundColor(.blue)
                }
                
                Text("\(splitEvenlyWays) Ways")
                    .font(.system(size: 50, weight: .bold)).foregroundColor(.white).frame(width: 200)
                
                Button(action: {
                    if splitEvenlyWays < 12 {
                        splitEvenlyWays += 1
                        paidFractions.removeAll()
                    }
                }) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 60)).foregroundColor(.blue)
                }
            }
            
            let fractionalTotal = tableTotal / Double(splitEvenlyWays)
            
            Text("Each person pays:")
                .font(.system(size: 24))
                .foregroundColor(.gray)
            
            Text(String(format: "$%.2f", fractionalTotal))
                .font(.system(size: 70, weight: .bold))
                .foregroundColor(.green)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(0..<splitEvenlyWays, id: \.self) { index in
                        let isPaid = paidFractions.contains(index)
                        
                        Button(action: {
                            payingFraction = fractionalTotal
                            pendingFractionIndex = index
                            showInlineTipSelection = true
                        }) {
                            VStack(spacing: 10) {
                                Image(systemName: isPaid ? "checkmark.circle.fill" : "creditcard.fill")
                                    .font(.system(size: 30))
                                Text(isPaid ? "PAID" : "Pay 1/\(splitEvenlyWays)")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(width: 140, height: 100)
                            .background(isPaid ? Color.gray : Color.blue)
                            .cornerRadius(16)
                        }
                        .disabled(isPaid)
                    }
                }
                .padding()
            }
            
            Spacer()
        }
    }
    
    // ✅ NEW: Passes the course and fired state into the split system
    func flattenTableItems() {
        var flattened: [SplitItem] = []
        for item in table.items {
            for _ in 0..<item.qty {
                flattened.append(SplitItem(
                    name: item.name, price: item.price, notes: item.notes, course: item.course, isFired: item.isFired
                ))
            }
        }
        unassignedItems = flattened
    }
    
    func assignItem(_ item: SplitItem, to seatId: UUID) {
        if let seatIndex = seats.firstIndex(where: { $0.id == seatId }) {
            withAnimation(.spring()) {
                seats[seatIndex].items.append(item)
                unassignedItems.removeAll(where: { $0.id == item.id })
                selectedItem = nil
            }
        }
    }
    
    func returnItemToUnassigned(_ item: SplitItem, from seatId: UUID) {
        if let seatIndex = seats.firstIndex(where: { $0.id == seatId }) {
            withAnimation(.spring()) {
                seats[seatIndex].items.removeAll(where: { $0.id == item.id })
                unassignedItems.append(item)
            }
        }
    }
    
    func processSeatPayment(for seat: ProSeat, tip: Double) {
        db.collection("receipts").addDocument(data: [
            "total": seat.total + tip,
            "tip": tip,
            "paymentMethod": "Split - Credit Card",
            "timestamp": Timestamp()
        ])
        
        let allAssigned = unassignedItems.isEmpty
        let allSeatsPaid = seats.allSatisfy { $0.isPaid || $0.items.isEmpty }
        
        if allAssigned && allSeatsPaid {
            finalAmountForThankYou = seat.total + tip
            clearTableAndDismiss()
        } else {
            updatePartialTableInFirebase()
        }
    }
    
    func processEvenPayment(amount: Double, tip: Double) {
        db.collection("receipts").addDocument(data: [
            "total": amount + tip,
            "tip": tip,
            "paymentMethod": "Split - Credit Card",
            "timestamp": Timestamp()
        ])
        
        if paidFractions.count == splitEvenlyWays {
            finalAmountForThankYou = amount + tip
            clearTableAndDismiss()
        }
    }
    
    func clearTableAndDismiss() {
        db.collection("tables").document(table.tableNumber).updateData([
            "items": [],
            "guests": 0
        ])
        
        withAnimation { showThankYou = true }
    }
    
    func updatePartialTableInFirebase() {
        var remainingItems: [SplitItem] = []
        remainingItems.append(contentsOf: unassignedItems)
        
        for seat in seats where !seat.isPaid {
            remainingItems.append(contentsOf: seat.items)
        }
        
        var groupedItems: [String: (item: SplitItem, qty: Int)] = [:]
        
        for item in remainingItems {
            let key = "\(item.name)_\(item.notes)_\(item.course)_\(item.isFired)"
            if let existing = groupedItems[key] {
                groupedItems[key] = (existing.item, existing.qty + 1)
            } else {
                groupedItems[key] = (item, 1)
            }
        }
        
        let finalData = groupedItems.values.map { group in
            return [
                "name": group.item.name,
                "price": group.item.price,
                "qty": group.qty,
                "notes": group.item.notes,
                "course": group.item.course,
                "isFired": group.item.isFired
            ]
        }
        
        db.collection("tables").document(table.tableNumber).updateData([
            "items": finalData
        ])
    }
}
