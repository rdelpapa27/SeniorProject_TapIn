//
//  KitchenDashboard.swift
//  TapIn
//

import SwiftUI
import FirebaseFirestore
import Combine

// ===============================================================
// MARK: - Models
// ===============================================================

struct KitchenOrder: Identifiable {
    let id: String
    let orderNumber: String
    let tableNumber: String
    let serverName: String
    let items: [KitchenItem]
    let createdAt: Date
    let status: String
}

struct KitchenItem: Identifiable {
    let id = UUID()
    let name: String
    let qty: Int
    let notes: String
    let course: Int // ✅ NEW: Tracks which course the item belongs to
}

// ===============================================================
// MARK: - ViewModel
// ===============================================================

final class KitchenDashboardViewModel: ObservableObject {

    @Published var orders: [KitchenOrder] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init() { listen() }
    deinit { listener?.remove() }

    func listen() {
        listener = db.collection("kitchenOrders")
            .whereField("status", in: ["new", "ready"])
            .order(by: "createdAt")
            .addSnapshotListener { snap, _ in
                guard let docs = snap?.documents else { return }
                self.orders = docs.compactMap { self.map($0) }
            }
    }

    func markReady(_ order: KitchenOrder) {
        updateLocal(order.id, status: "ready")
        updateRemote(order.id, status: "ready")
    }

    func clear(_ order: KitchenOrder) {
        orders.removeAll { $0.id == order.id }
        updateRemote(order.id, status: "cleared")
    }

    private func updateLocal(_ id: String, status: String) {
        guard let i = orders.firstIndex(where: { $0.id == id }) else { return }
        let o = orders[i]
        orders[i] = KitchenOrder(
            id: o.id,
            orderNumber: o.orderNumber,
            tableNumber: o.tableNumber,
            serverName: o.serverName,
            items: o.items,
            createdAt: o.createdAt,
            status: status
        )
    }

    private func updateRemote(_ id: String, status: String) {
        db.collection("kitchenOrders")
            .document(id)
            .updateData(["status": status])
    }

    private func map(_ doc: QueryDocumentSnapshot) -> KitchenOrder? {
        let d = doc.data()

        guard
            let orderNumber = d["orderNumber"] as? String,
            let tableNumber = d["tableNumber"] as? String,
            let serverName = d["serverName"] as? String,
            let status = d["status"] as? String,
            let ts = d["createdAt"] as? Timestamp,
            let raw = d["items"] as? [[String: Any]]
        else { return nil }

        let items: [KitchenItem] = raw.compactMap { item in
            guard
                let name = item["name"] as? String,
                let qty = item["qty"] as? Int
            else { return nil }

            return KitchenItem(
                name: name,
                qty: qty,
                notes: item["notes"] as? String ?? "",
                course: item["course"] as? Int ?? 1 // ✅ Safely parses the course
            )
        }

        return KitchenOrder(
            id: doc.documentID,
            orderNumber: orderNumber,
            tableNumber: tableNumber,
            serverName: serverName,
            items: items,
            createdAt: ts.dateValue(),
            status: status
        )
    }
}

// ===============================================================
// MARK: - Dashboard
// ===============================================================

struct KitchenDashboard: View {

    @StateObject private var vm = KitchenDashboardViewModel()
    @Environment(\.dismiss) private var dismiss

    // ✅ NEW: Defines the responsive grid layout (Columns & Rows)
    let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 320), spacing: 24, alignment: .top)
    ]

    var body: some View {

        ZStack {

            BackgroundDecorView()

            VStack(spacing: 0) {

                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                    }
                    .padding(.trailing, 10)
                    
                    Text("Kitchen Order Dashboard")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(red: 0.02, green: 0.20, blue: 0.30))

                // ✅ NEW: Swapped horizontal scroll for a vertical Grid layout
                ScrollView(.vertical) {
                    LazyVGrid(columns: columns, spacing: 30) {
                        ForEach(Array(vm.orders.enumerated()), id: \.element.id) { index, order in
                            TicketView(
                                order: order,
                                orderIndex: index + 1,
                                onReady: { vm.markReady(order) },
                                onClear: { vm.clear(order) }
                            )
                        }
                    }
                    .padding(24)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarHidden(true)
    }
}

// ===============================================================
// MARK: - Background Decor
// ===============================================================

struct BackgroundDecorView: View {
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    RoundedRectangle(cornerRadius: 180)
                        .fill(Color.orange.opacity(0.55))
                        .frame(width: 700, height: 700)
                        .rotationEffect(.degrees(30))
                        .offset(x: -140, y: -140)
                    Spacer()
                }
                Spacer()
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 220)
                        .fill(Color.orange.opacity(0.50))
                        .frame(width: 900, height: 550)
                        .rotationEffect(.degrees(30))
                        .offset(x: 180, y: 180)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// ===============================================================
// MARK: - Ticket View (DYNAMIC HEIGHT & COURSE DIVIDERS)
// ===============================================================

struct TicketView: View {

    let order: KitchenOrder
    let orderIndex: Int
    let onReady: () -> Void
    let onClear: () -> Void

    @State private var currentTime = Date()
    let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var elapsedMinutes: Int {
        let mins = Int(currentTime.timeIntervalSince(order.createdAt) / 60)
        return max(mins, 0)
    }

    var timeString: String {
        return elapsedMinutes <= 0 ? "just now" : "\(elapsedMinutes)m ago"
    }

    var ticketColor: Color {
        if elapsedMinutes >= 15 { return Color.red }
        else if elapsedMinutes >= 10 { return Color.orange }
        else { return Color.green }
    }
    
    // ✅ TRANSLATOR: Converts course numbers into headers
    func courseName(for course: Int) -> String {
        switch course {
        case 1: return "Appetizers"
        case 2: return "Entrees"
        case 3: return "Desserts"
        default: return "Course \(course)"
        }
    }

    var body: some View {

        VStack(spacing: 0) {

            // HEADER
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Order #\(String(order.orderNumber.prefix(4)))") // Uses actual DB ID to prevent visual jumping
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Text(timeString)
                        .font(.system(size: 14, weight: .bold))
                }

                HStack {
                    Text("TABLE: \(order.tableNumber)")
                    Spacer()
                    Text(order.serverName.uppercased())
                }
                .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(10)
            .background(ticketColor)
            .animation(.easeInOut, value: ticketColor)

            // BODY (DYNAMIC HEIGHT)
            VStack(alignment: .leading, spacing: 16) {
                
                // ✅ GROUP ITEMS BY COURSE INSIDE THE TICKET
                let groupedItems = Dictionary(grouping: order.items, by: { $0.course })
                let sortedCourses = groupedItems.keys.sorted()
                
                ForEach(sortedCourses, id: \.self) { course in
                    VStack(alignment: .leading, spacing: 8) {
                        
                        // Beautiful mini-header for the course
                        Text(courseName(for: course).uppercased())
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(Color.gray.opacity(0.8))
                            .padding(.bottom, -4)
                        
                        ForEach(groupedItems[course]!) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(item.qty) x \(item.name)")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.black)
                                
                                if !item.notes.isEmpty {
                                    Text(item.notes)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.red)
                                        .padding(.leading, 10)
                                }
                            }
                        }
                    }
                    
                    // Add a subtle divider if it's not the last course in the ticket
                    if course != sortedCourses.last {
                        Divider().background(Color.gray.opacity(0.3))
                    }
                }

                Button(action: order.status == "new" ? onReady : onClear) {
                    Text(order.status == "new" ? "READY" : "CLEAR")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 45)
                        .background(order.status == "new" ? Color.blue : Color.gray)
                        .cornerRadius(8)
                }
                .padding(.top, 6)
            }
            .padding(14)
            .background(Color(.systemGray6))
        }
        // ✅ No fixed height here! It will stretch downwards automatically.
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ticketColor)
                .offset(x: 8, y: 8)
                .animation(.easeInOut, value: ticketColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black, lineWidth: 2)
        )
        .onReceive(timer) { newTime in
            currentTime = newTime
        }
    }
}
