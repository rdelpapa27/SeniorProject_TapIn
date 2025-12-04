//
//  OrderMenuScreen.swift
//  TapIn
//

import SwiftUI
import FirebaseFirestore

struct OrderMenuScreen: View {

    @State var table: TableInfo
    let db = Firestore.firestore()

    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    @State private var selectedGroup: String = "FOOD"
    @State private var selectedCategory: String = "Appetizers"

    @State private var allItems: [MenuItemCategory] = []

    // ============================================================
    // MARK: - NEW MODAL STATE
    // ============================================================
    @State private var showAddModal = false
    @State private var modalItem: MenuItemCategory? = nil
    @State private var modalQty: Int = 1
    @State private var modalNotes: String = ""

    let groups = ["FOOD", "DRINKS", "DESSERT"]

    let categoryMap: [String: [String]] = [
        "FOOD": ["Appetizers", "Salads", "Entrees", "Sides", "Desserts", "Add Ons"],
        "DRINKS": ["Soft Drinks", "Coffee", "Juice", "Alcohol"],
        "DESSERT": ["Desserts"]
    ]

    // THEME COLORS (unchanged)
    let navy = Color(red: 10/255, green: 40/255, blue: 65/255)
    let panelGray = Color(.systemGray5)
    let darkNavy = Color(red: 0.05, green: 0.20, blue: 0.35)
    let mediumGray = Color(red: 0.78, green: 0.80, blue: 0.85)

    // FILTERED ITEMS
    var filteredItems: [MenuItemCategory] {
        allItems
            .filter { $0.group == selectedGroup }
            .filter { $0.category == selectedCategory }
            .filter { searchText.isEmpty || $0.name.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {

        ZStack {

            navy.ignoresSafeArea()
            orangeAccent

            VStack(spacing: 30) {
                header
                mainContent
            }
            .padding(.top, 10)

            // ============================================
            // MODAL OVERLAY (ONLY SHOWN WHEN TAPPING ITEM)
            // ============================================
            if showAddModal {
                modalOverlay
            }
        }
        .onAppear {
            loadMenu()
            listenToTableUpdates()
        }
    }

    // ORANGE ACCENT BLOB (unchanged)
    private var orangeAccent: some View {
        VStack {
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 140)
                    .fill(Color.orange)
                    .frame(width: 330, height: 180)
                    .rotationEffect(.degrees(20))
                    .offset(x: 90, y: -80)
            }
            Spacer()
        }
    }

    // HEADER (unchanged)
    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            Spacer()
            Text("Order Menu")
                .font(.system(size: 38, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Rectangle().fill(Color.clear).frame(width: 40)
        }
        .padding(.horizontal)
    }

    // MAIN CONTENT (unchanged)
    private var mainContent: some View {
        HStack(spacing: 40) {
            leftPanel
            rightPanel
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 20)
    }

    // LEFT PANEL (unchanged)
    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 18) {

            VStack(alignment: .leading, spacing: 6) {
                Text("Table \(table.tableNumber)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.black)

                HStack {
                    Image(systemName: "person.fill")
                    Text("\(table.guests) guests")
                }
                .foregroundColor(.black.opacity(0.6))
            }

            Divider().background(Color.black.opacity(0.3))

            ScrollView {
                VStack(spacing: 22) {

                    ForEach(Array(table.items.enumerated()), id: \.offset) { index, item in

                        HStack {
                            Circle()
                                .fill(Color.gray.opacity(0.65))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text("\(index + 1)")
                                        .foregroundColor(.white)
                                        .font(.system(size: 18, weight: .bold))
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .foregroundColor(.black)
                                    .font(.system(size: 20))

                                if !item.notes.isEmpty {
                                    Text(item.notes)
                                        .foregroundColor(.black.opacity(0.6))
                                        .font(.system(size: 14))
                                }
                            }

                            Spacer()

                            Text("x\(item.qty)")
                                .foregroundColor(.black)
                                .font(.system(size: 18, weight: .medium))

                            Text("$" + String(format: "%.2f", item.price * Double(item.qty)))
                                .foregroundColor(.black)
                                .font(.system(size: 20, weight: .semibold))
                        }
                    }
                }
            }

            Spacer()

        }
        .padding(22)
        .background(panelGray)
        .cornerRadius(22)
        .frame(width: 340, height: 760)
    }

    // RIGHT PANEL (unchanged except for tap behavior)
    private var rightPanel: some View {

        VStack(spacing: 22) {

            // SEARCH BAR
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.black.opacity(0.5))
                TextField("Search…", text: $searchText)
                    .foregroundColor(.black)
                    .font(.system(size: 18))
            }
            .padding()
            .background(Color.white.opacity(0.6))
            .cornerRadius(16)
            .padding(.horizontal)

            // CATEGORY BUTTONS
            HStack(spacing: 14) {
                ForEach(groups, id: \.self) { group in

                    Button {
                        selectedGroup = group
                        selectedCategory = categoryMap[group]?.first ?? ""
                    } label: {
                        Text(group)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(darkNavy)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                group == selectedGroup
                                ? Color.white
                                : mediumGray
                            )
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)

            // SUBCATEGORIES
            HStack(spacing: 14) {
                ForEach(categoryMap[selectedGroup] ?? [], id: \.self) { cat in

                    Button {
                        selectedCategory = cat
                    } label: {
                        Text(cat)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(darkNavy)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                cat == selectedCategory
                                ? Color.white
                                : mediumGray
                            )
                            .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal)

            // GRID (unchanged layout)
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 26),
                        GridItem(.flexible(), spacing: 26),
                        GridItem(.flexible(), spacing: 26)
                    ],
                    spacing: 26
                ) {
                    ForEach(filteredItems, id: \.self) { item in

                        Button {

                            // SHOW MODAL
                            modalItem = item
                            modalQty = 1
                            modalNotes = ""
                            showAddModal = true

                        } label: {
                            VStack(spacing: 10) {
                                Text(item.name)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(darkNavy)

                                Text("$" + String(format: "%.2f", item.price))
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 22)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.14),
                                    radius: 4, x: 0, y: 2)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }

            Spacer()

        }
        .background(panelGray)
        .cornerRadius(22)
        .frame(height: 760)
    }

    // ================================================================
    // MARK: - MODAL UI
    // ================================================================

    private var modalOverlay: some View {

        ZStack {

            // Dimmed background
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            if let item = modalItem {

                VStack(spacing: 20) {

                    Text("Add \(item.name)")
                        .font(.system(size: 26, weight: .bold))

                    // QTY STEPPER
                    HStack(spacing: 18) {

                        Button {
                            if modalQty > 1 { modalQty -= 1 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)
                        }

                        Text("\(modalQty)")
                            .font(.system(size: 28, weight: .semibold))
                            .frame(width: 60)

                        Button { modalQty += 1 } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)
                        }
                    }

                    // NOTES FIELD
                    TextField("Notes (optional)", text: $modalNotes)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)

                    HStack {

                        Button {
                            showAddModal = false
                        } label: {
                            Text("Cancel")
                                .foregroundColor(.red)
                                .font(.system(size: 20, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding()
                        }

                        Button {
                            confirmAddItem(item)
                        } label: {
                            Text("Add Item")
                                .foregroundColor(.white)
                                .font(.system(size: 20, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)

                }
                .padding()
                .frame(width: 340)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(radius: 16)
            }
        }
    }

    // ================================================================
    // MARK: - CONFIRM ADD ITEM
    // ================================================================

    func confirmAddItem(_ categoryItem: MenuItemCategory) {

        guard modalQty > 0 else { return }

        let tableRef = db.collection("tables").document(table.tableNumber)

        tableRef.getDocument { snap, _ in
            guard let data = snap?.data() else { return }

            var items = data["items"] as? [[String: Any]] ?? []

            // NOTES MATTER — identical item with different notes is separate
            if let index = items.firstIndex(where: {
                ($0["name"] as? String) == categoryItem.name &&
                ($0["notes"] as? String ?? "") == modalNotes
            }) {
                var updated = items[index]
                let oldQty = updated["qty"] as? Int ?? 1
                updated["qty"] = oldQty + modalQty
                items[index] = updated
            } else {
                items.append([
                    "name": categoryItem.name,
                    "price": categoryItem.price,
                    "qty": modalQty,
                    "notes": modalNotes
                ])
            }

            tableRef.updateData(["items": items])
            showAddModal = false
        }
    }

    // ================================================================
    // MARK: - LOAD MENU
    // ================================================================

    func loadMenu() {
        db.collection("menu").getDocuments { snap, _ in
            allItems = snap?.documents.compactMap { doc in
                let d = doc.data()
                guard let name = d["name"] as? String,
                      let price = d["price"] as? Double,
                      let group = d["group"] as? String,
                      let category = d["category"] as? String else { return nil }
                return MenuItemCategory(name: name, price: price, group: group, category: category)
            } ?? []
        }
    }

    // ================================================================
    // MARK: - LIVE TABLE LISTENER
    // ================================================================

    func listenToTableUpdates() {
        db.collection("tables")
            .document(table.tableNumber)
            .addSnapshotListener { snap, _ in

                guard let data = snap?.data() else { return }

                let guests = data["guests"] as? Int ?? table.guests

                let itemsArray = data["items"] as? [[String: Any]] ?? []

                let items = itemsArray.compactMap { dict -> MenuItem? in
                    guard let name = dict["name"] as? String,
                          let price = dict["price"] as? Double else { return nil }

                    let qty = dict["qty"] as? Int ?? 1
                    let notes = dict["notes"] as? String ?? ""

                    return MenuItem(name: name, price: price, qty: qty, notes: notes)
                }

                table = TableInfo(
                    tableNumber: table.tableNumber,
                    guests: guests,
                    items: items
                )
            }
    }
}

// ================================================================
// MARK: - CATEGORY MODEL (unchanged)
// ================================================================

struct MenuItemCategory: Hashable {
    let name: String
    let price: Double
    let group: String
    let category: String
}

