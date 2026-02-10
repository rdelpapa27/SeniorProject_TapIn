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
}

// ===============================================================
// MARK: - ViewModel (UNCHANGED)
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
                notes: item["notes"] as? String ?? ""
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

    var body: some View {

        ZStack {

            BackgroundDecorView()

            VStack(spacing: 0) {

                HStack {
                    Text("Kitchen Order Dashboard")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(red: 0.02, green: 0.20, blue: 0.30))

                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 20) {
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
    }
}

// ===============================================================
// MARK: - Background Decor (BIGGER + 30° TILT)
// ===============================================================

struct BackgroundDecorView: View {
    var body: some View {
        ZStack {

            // TOP-LEFT CORNER — BIGGER + ROTATED
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

            // BOTTOM-RIGHT CORNER — BIGGER + ROTATED
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
// MARK: - Ticket View (UNCHANGED)
// ===============================================================

struct TicketView: View {

    let order: KitchenOrder
    let orderIndex: Int
    let onReady: () -> Void
    let onClear: () -> Void

    var minutesAgo: String {
        let mins = Int(Date().timeIntervalSince(order.createdAt) / 60)
        return mins <= 0 ? "just now" : "\(mins)m ago"
    }

    var body: some View {

        VStack(spacing: 0) {

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Order #\(orderIndex)")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Text(minutesAgo)
                        .font(.system(size: 12, weight: .medium))
                }

                HStack {
                    Text("TABLE: \(order.tableNumber)")
                    Spacer()
                    Text(order.serverName.uppercased())
                }
                .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(8)
            .background(Color.orange)

            VStack(alignment: .leading, spacing: 10) {

                ForEach(order.items) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(item.qty) x \(item.name)")
                            .font(.system(size: 17, weight: .bold))
                        if !item.notes.isEmpty {
                            Text(item.notes)
                                .font(.system(size: 15))
                                .foregroundColor(.red)
                                .padding(.leading, 10)
                        }
                    }
                }

                Button(action: order.status == "new" ? onReady : onClear) {
                    Text(order.status == "new" ? "READY" : "CLEAR")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(order.status == "new" ? Color.green : Color.gray)
                        .cornerRadius(6)
                }
                .padding(.top, 6)
            }
            .padding(12)
            .background(Color(.systemGray5))
        }
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange)
                .offset(x: 8, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black, lineWidth: 2)
        )
    }
}

