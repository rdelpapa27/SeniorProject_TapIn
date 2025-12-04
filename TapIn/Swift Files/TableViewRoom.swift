//
//  TableViewRoom.swift
//  TapIn
//

import SwiftUI
import FirebaseFirestore
import Combine

struct TableViewRoom: View {

    @StateObject private var vm = TableViewModel()

    @State private var selectedTable: TableInfo? = nil
    @State private var showPanel = false

    @State private var openMenu = false
    @State private var tableForMenu: TableInfo? = nil

    @State private var openPayment = false
    @State private var tableForPayment: TableInfo? = nil

    let db = Firestore.firestore()

    var body: some View {

        ZStack(alignment: .leading) {

            Color(red: 0.02, green: 0.16, blue: 0.27)
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 84)
                .fill(Color.orange)
                .frame(width: 540, height: 420)
                .rotationEffect(.degrees(18))
                .offset(x: 520, y: -520)

            VStack {

                HStack {
                    Image(systemName: "chevron.left")
                        .font(.title)
                        .foregroundColor(.white)

                    Spacer()

                    Text("Main Room")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.title)
                        .foregroundColor(.white)
                }
                .padding()

                Text("Table View")
                    .font(.system(size: 38))
                    .foregroundColor(.white)

                ZStack {
                    Color.gray.opacity(0.5)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue, lineWidth: 4))
                        .padding(.horizontal)

                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height

                        Group {
                            tableButton("T1", .square,     w*0.10, h*0.15)
                            tableButton("T2", .circle,     w*0.26, h*0.15)
                            tableButton("T3", .circle,     w*0.46, h*0.15)
                            tableButton("T4", .rectangle,  w*0.70, h*0.15)
                            tableButton("T5", .circle,     w*0.90, h*0.33)
                            tableButton("T6", .circle,     w*0.90, h*0.58)
                            tableButton("T7", .diamond,    w*0.90, h*0.85)
                            tableButton("T8", .circle,     w*0.70, h*0.85)
                            tableButton("T9", .circle,     w*0.50, h*0.85)
                            tableButton("T10", .rectangle, w*0.20, h*0.86)
                            tableButton("T11", .diamond,   w*0.10, h*0.52)
                            tableButton("T12", .diamond,   w*0.30, h*0.50)
                            tableButton("T13", .diamond,   w*0.39, h*0.65)
                            tableButton("T14", .diamond,   w*0.39, h*0.35)
                            tableButton("T15", .diamond,   w*0.48, h*0.50)
                            tableButton("T16", .square,    w*0.70, h*0.50)
                        }
                    }
                }
                .frame(height: 600)
            }

            if showPanel, let table = selectedTable {
                SidePanel(
                    table: table,
                    addItemsAction: {
                        tableForMenu = table
                        openMenu = true
                    },
                    removeItem: { item in
                        removeItemFromTable(table: table, item: item)
                    },
                    updateGuests: { newGuests in
                        updateGuestCount(table: table, guests: newGuests)
                    },
                    close: { showPanel = false },
                    sendAction: {},
                    payAction: {
                        tableForPayment = table
                        openPayment = true
                    }
                )
                .frame(width: 360)
                .transition(.move(edge: .leading))
                .animation(.easeInOut, value: showPanel)
            }
        }

        .navigationDestination(isPresented: $openMenu) {
            if let table = tableForMenu { OrderMenuScreen(table: table) }
        }

        .navigationDestination(isPresented: $openPayment) {
            if let table = tableForPayment { PaymentScreen(table: table) }
        }

        .onReceive(vm.$tables) { updatedTables in
            if let current = selectedTable,
               let updated = updatedTables.first(where: { $0.tableNumber == current.tableNumber }) {
                selectedTable = updated
            }
        }
    }

    func tableButton(
        _ label: String,
        _ shape: TableShape,
        _ x: CGFloat,
        _ y: CGFloat
    ) -> some View {

        let table = vm.tables.first(where: { $0.tableNumber == label })
        let occupied = (table?.items.contains(where: { $0.qty > 0 }) ?? false)
        let color: Color = occupied ? .yellow : .gray

        return TableView(label: label, shape: shape, color: color) {
            if let info = table {
                selectedTable = info
                showPanel = true
            }
        }
        .position(x: x, y: y)
    }

    func removeItemFromTable(table: TableInfo, item: MenuItem) {

        let ref = db.collection("tables").document(table.tableNumber)

        ref.getDocument { snap, _ in
            guard let data = snap?.data() else { return }

            var items = data["items"] as? [[String: Any]] ?? []

            if let index = items.firstIndex(where: {
                ($0["name"] as? String) == item.name &&
                ($0["notes"] as? String ?? "") == item.notes
            }) {

                var updated = items[index]
                let currentQty = updated["qty"] as? Int ?? 1

                if currentQty > 1 {
                    updated["qty"] = currentQty - 1
                    items[index] = updated
                } else {
                    items.remove(at: index)
                }
            }

            ref.updateData(["items": items])
        }
    }

    func updateGuestCount(table: TableInfo, guests: Int) {
        db.collection("tables")
            .document(table.tableNumber)
            .updateData(["guests": guests])
    }
}

extension Array where Element == MenuItem {
    func grouped() -> [(item: MenuItem, quantity: Int)] {
        var groups: [String: (MenuItem, Int)] = [:]

        for item in self {
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

struct OrderItemRow: View {

    let item: MenuItem
    let quantity: Int
    let onDelete: () -> Void

    var body: some View {

        HStack(spacing: 14) {

            VStack(alignment: .leading, spacing: 2) {

                Text(item.name)
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .semibold))

                if !item.notes.isEmpty {
                    Text(item.notes)
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 14))
                }

                if quantity > 1 {
                    Text("x\(quantity)")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 15))
                }
            }

            Spacer()

            Text(String(format: "$%.2f", item.price * Double(quantity)))
                .foregroundColor(.white)
                .font(.system(size: 18, weight: .medium))

            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .foregroundColor(.white.opacity(0.9))
                    .font(.system(size: 20))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 18)
        .background(Color.white.opacity(0.15))
        .cornerRadius(14)
    }
}

//
// ===============================================================
// MARK: - SIDE PANEL (GUEST TICKER MOVED ABOVE SEND)
// ===============================================================
//

struct SidePanel: View {

    let table: TableInfo
    let addItemsAction: () -> Void
    let removeItem: (MenuItem) -> Void
    let updateGuests: (Int) -> Void
    let close: () -> Void
    let sendAction: () -> Void
    let payAction: () -> Void

    var subtotal: Double { table.items.reduce(0) { $0 + ($1.price * Double($1.qty)) } }
    var tax: Double { subtotal * 0.148 }
    var total: Double { subtotal + tax }

    let bg = Color(red: 0.11, green: 0.16, blue: 0.22)

    var body: some View {

        VStack(spacing: 0) {

            // HEADER
            HStack {
                Button(action: close) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                        Text("\(table.guests) guests")
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .font(.system(size: 15))

                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                        Text("James Uzumaki")
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .font(.system(size: 15))
                }

                Spacer()

                Text("Table \(table.tableNumber)")
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .bold))
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider().background(Color.white.opacity(0.3))

            // ITEM LIST
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(table.items.grouped(), id: \.item.id) { grouped in
                        OrderItemRow(item: grouped.item,
                                     quantity: grouped.quantity,
                                     onDelete: { removeItem(grouped.item) })
                    }
                }
                .padding(.horizontal)
                .padding(.top, 14)
            }
            .frame(maxHeight: 300)

            //
            // GUEST TICKER MOVED HERE (directly above SEND)
            //
            HStack(spacing: 24) {

                Button(action: {
                    if table.guests > 0 {
                        updateGuests(table.guests - 1)
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }

                Text("Guests: \(table.guests)")
                    .foregroundColor(.white)
                    .font(.system(size: 22, weight: .medium))

                Button(action: {
                    updateGuests(table.guests + 1)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 18)

            //
            // SEND / MENU / PRINT BUTTONS
            //
            VStack(spacing: 16) {

                posButton(
                    title: "Send",
                    icon: "paperplane.fill",
                    color: Color.blue.opacity(0.35),
                    action: sendAction
                )

                posButton(
                    title: "Menu",
                    icon: "square.grid.2x2.fill",
                    color: Color.gray.opacity(0.35),
                    action: addItemsAction
                )

                posButton(
                    title: "Print",
                    icon: "printer.fill",
                    color: Color.gray.opacity(0.30),
                    action: {}
                )
            }
            .padding(.horizontal)

            //
            // TOTALS + PAY BUTTON
            //
            VStack(spacing: 8) {

                HStack {
                    Text("Subtotal:")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Text(String(format: "$%.2f", subtotal))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }

                HStack {
                    Text("Tax:")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Text(String(format: "$%.2f", tax))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Button(action: payAction) {
                Text("Pay \(String(format: "$%.2f", total))")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.green)
                    .cornerRadius(16)
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(bg)
        .cornerRadius(26)
        .shadow(radius: 20)
    }

    func posButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .background(color)
            .cornerRadius(16)
        }
    }
}

enum TableShape {
    case square, circle, rectangle, diamond
}

struct TableView: View {

    let label: String
    let shape: TableShape
    var color: Color = .gray
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            ZStack {
                switch shape {
                case .square:
                    Rectangle()
                        .fill(color)
                        .frame(width: 110, height: 110)
                        .cornerRadius(12)

                case .circle:
                    Circle()
                        .fill(color)
                        .frame(width: 130, height: 130)

                case .rectangle:
                    Rectangle()
                        .fill(color)
                        .frame(width: 300, height: 75)
                        .cornerRadius(12)

                case .diamond:
                    Rectangle()
                        .fill(color)
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(45))
                }

                Text(label)
                    .foregroundColor(.black)
                    .font(.system(size: 20, weight: .bold))
            }
        }
        .buttonStyle(.plain)
    }
}

