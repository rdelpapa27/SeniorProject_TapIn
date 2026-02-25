//
//  OrderMenuScreen.swift
//  TapIn
//

import SwiftUI
import FirebaseFirestore
import Combine

struct OrderMenuScreen: View {

    @State var table: TableInfo
    let db = Firestore.firestore()

    @Environment(\.dismiss) private var dismiss
    
    // ✅ Read the logged in user
    @AppStorage("currentServerName") private var currentServerName = "Server"

    @State private var searchText = ""

    @State private var selectedGroup: String = "FOOD"
    @State private var selectedCategory: String = "Appetizers"

    @State private var allItems: [MenuItemCategory] = []

    // ============================================================
    // MARK: - ADD MODAL & ALERT STATE
    // ============================================================
    @State private var showAddModal = false
    @State private var modalItem: MenuItemCategory? = nil
    @State private var modalQty: Int = 1
    @State private var modalNotes: String = ""
    @State private var selectedModifiers: [String: Set<ModifierOption>] = [:]
    
    // ============================================================
    // MARK: - EDIT / DELETE MODAL STATE
    // ============================================================
    @State private var showEditModal = false
    @State private var itemToEdit: MenuItem? = nil
    @State private var editQty: Int = 1
    @State private var editNotes: String = ""
    
    @State private var openPayment = false
    @State private var showSentConfirmation = false

    let groups = ["FOOD", "DRINKS", "DESSERT"]

    // ✅ FIXED: Removed "Desserts" from the FOOD category list so it only shows up under DESSERT
    let categoryMap: [String: [String]] = [
        "FOOD": ["Appetizers", "Salads", "Entrees", "Sides", "Add Ons"],
        "DRINKS": ["Soft Drinks", "Coffee", "Juice", "Alcohol"],
        "DESSERT": ["Desserts"]
    ]

    let navy = Color(red: 10/255, green: 40/255, blue: 65/255)
    let panelGray = Color(.systemGray5)
    let darkNavy = Color(red: 0.05, green: 0.20, blue: 0.35)
    let mediumGray = Color(red: 0.78, green: 0.80, blue: 0.85)

    var filteredItems: [MenuItemCategory] {
        allItems
            .filter { $0.group == selectedGroup }
            .filter { $0.category == selectedCategory }
            .filter { searchText.isEmpty || $0.name.lowercased().contains(searchText.lowercased()) }
    }
    
    var isReadyToAdd: Bool {
        guard let item = modalItem else { return false }
        for group in item.modifiers where group.isRequired {
            let selectedCount = selectedModifiers[group.id]?.count ?? 0
            if selectedCount == 0 { return false }
        }
        return true
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

            if showAddModal {
                modalOverlay
            }
            
            // ✅ NEW: The Edit Modal Overlay
            if showEditModal {
                editModalOverlay
            }
            
            if showSentConfirmation {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Sent to Kitchen!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                }
                .padding(40)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
                .transition(.scale.combined(with: .opacity))
                .zIndex(100)
            }
        }
        .onAppear {
            loadMenu()
            listenToTableUpdates()
        }
        .navigationDestination(isPresented: $openPayment) {
            PaymentScreen(table: table)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissToFloorPlan"))) { _ in
            dismiss()
        }
    }

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

    private var mainContent: some View {
        HStack(spacing: 40) {
            leftPanel
            rightPanel
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 20)
    }

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 18) {

            VStack(alignment: .leading, spacing: 6) {
                Text(table.tableNumber.contains("ToGo:") ? "Takeout Order" : "Table \(table.tableNumber)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.black)

                HStack {
                    Image(systemName: "person.fill")
                    Text(table.tableNumber.contains("ToGo:") ? table.tableNumber.replacingOccurrences(of: "ToGo: ", with: "") : "\(table.guests) guests")
                }
                .foregroundColor(.black.opacity(0.6))
            }

            Divider().background(Color.black.opacity(0.3))

            ScrollView {
                VStack(spacing: 22) {
                    ForEach(Array(table.items.enumerated()), id: \.offset) { index, item in
                        
                        // ✅ UPGRADED: Items in the left panel are now clickable!
                        Button(action: {
                            itemToEdit = item
                            editQty = item.qty
                            editNotes = item.notes
                            withAnimation(.spring()) { showEditModal = true }
                        }) {
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
                                    HStack {
                                        Text(item.name)
                                            .foregroundColor(.black)
                                            .font(.system(size: 20))
                                        
                                        if !item.isFired {
                                            Text("HOLD")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.red.opacity(0.8))
                                                .cornerRadius(4)
                                        }
                                    }

                                    if !item.notes.isEmpty {
                                        Text(item.notes)
                                            .foregroundColor(.black.opacity(0.6))
                                            .font(.system(size: 14))
                                            .multilineTextAlignment(.leading)
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
            }

            Spacer()
            
            Divider().background(Color.black.opacity(0.3))
            
            let subtotal = table.items.reduce(0) { $0 + ($1.price * Double($1.qty)) }
            let tax = subtotal * 0.148
            let total = subtotal + tax
            let unfiredCount = table.items.filter { !$0.isFired }.count
            
            VStack(spacing: 12) {
                HStack {
                    Text("Total:")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                    Text(String(format: "$%.2f", total))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.green)
                }
                
                HStack(spacing: 12) {
                    Button(action: sendToKitchen) {
                        HStack {
                            Image(systemName: "flame.fill")
                            Text(unfiredCount > 0 ? "Fire All Unsent" : "All Fired")
                        }
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(unfiredCount > 0 ? Color.orange : Color.gray)
                        .cornerRadius(10)
                    }
                    .disabled(unfiredCount == 0)
                    
                    Button(action: { openPayment = true }) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                            Text("Pay")
                        }
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .disabled(table.items.isEmpty)
                }
            }
        }
        .padding(22)
        .background(panelGray)
        .cornerRadius(22)
        .frame(width: 340, height: 760)
    }

    private var rightPanel: some View {
        VStack(spacing: 22) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.black.opacity(0.5))
                TextField("Search…", text: $searchText).foregroundColor(.black).font(.system(size: 18))
            }
            .padding().background(Color.white.opacity(0.6)).cornerRadius(16).padding(.horizontal)

            HStack(spacing: 14) {
                ForEach(groups, id: \.self) { group in
                    Button {
                        selectedGroup = group
                        selectedCategory = categoryMap[group]?.first ?? ""
                    } label: {
                        Text(group).font(.system(size: 20, weight: .bold)).foregroundColor(darkNavy).frame(maxWidth: .infinity).frame(height: 52).background(group == selectedGroup ? Color.white : mediumGray).cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)

            HStack(spacing: 14) {
                ForEach(categoryMap[selectedGroup] ?? [], id: \.self) { cat in
                    Button {
                        selectedCategory = cat
                    } label: {
                        Text(cat).font(.system(size: 18, weight: .semibold)).foregroundColor(darkNavy).frame(maxWidth: .infinity).frame(height: 44).background(cat == selectedCategory ? Color.white : mediumGray).cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 26), GridItem(.flexible(), spacing: 26), GridItem(.flexible(), spacing: 26)], spacing: 26) {
                    ForEach(filteredItems, id: \.self) { item in
                        Button {
                            if item.isAvailable {
                                modalItem = item
                                modalQty = 1
                                modalNotes = ""
                                selectedModifiers = [:]
                                withAnimation(.spring()) { showAddModal = true }
                            }
                        } label: {
                            ZStack {
                                VStack(spacing: 10) {
                                    Text(item.name)
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundColor(item.isAvailable ? darkNavy : .gray.opacity(0.5))
                                    Text("$" + String(format: "%.2f", item.price))
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(item.isAvailable ? .gray : .gray.opacity(0.3))
                                }
                                
                                if !item.isAvailable {
                                    Text("SOLD OUT")
                                        .font(.system(size: 20, weight: .black))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.9))
                                        .cornerRadius(8)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 2))
                                        .rotationEffect(.degrees(-10))
                                }
                            }
                            .padding(.vertical, 22)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .background(item.isAvailable ? Color.white : Color(.systemGray5))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.14), radius: 4, x: 0, y: 2)
                        }
                        .disabled(!item.isAvailable)
                    }
                }
                .padding(.horizontal).padding(.bottom, 20)
            }
            Spacer()
        }
        .background(panelGray).cornerRadius(22).frame(height: 760)
    }

    // ===============================================================
    // MARK: - ADD ITEM MODAL
    // ===============================================================
    private var modalOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { withAnimation { showAddModal = false } }

            if let item = modalItem {
                VStack(spacing: 20) {
                    Text("Add \(item.name)")
                        .font(.system(size: 26, weight: .bold))

                    HStack(spacing: 18) {
                        Button { if modalQty > 1 { modalQty -= 1 } } label: { Image(systemName: "minus.circle.fill").font(.system(size: 32)).foregroundColor(.blue) }
                        Text("\(modalQty)").font(.system(size: 28, weight: .semibold)).frame(width: 60)
                        Button { modalQty += 1 } label: { Image(systemName: "plus.circle.fill").font(.system(size: 32)).foregroundColor(.blue) }
                    }

                    if !item.modifiers.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(item.modifiers, id: \.id) { modGroup in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(modGroup.name)
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.black)
                                            
                                            if modGroup.isRequired {
                                                Text("REQUIRED")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.red)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.red.opacity(0.2))
                                                    .cornerRadius(4)
                                            }
                                        }
                                        
                                        ForEach(modGroup.options, id: \.id) { option in
                                            let isSelected = selectedModifiers[modGroup.id]?.contains(option) ?? false
                                            
                                            Button(action: {
                                                handleModifierSelection(group: modGroup, option: option)
                                            }) {
                                                HStack {
                                                    Image(systemName: isSelected ? (modGroup.isRequired ? "largecircle.fill.circle" : "checkmark.square.fill") : (modGroup.isRequired ? "circle" : "square"))
                                                        .foregroundColor(isSelected ? .blue : .gray)
                                                    
                                                    Text(option.name)
                                                        .foregroundColor(.black)
                                                    
                                                    Spacer()
                                                    
                                                    if option.price > 0 {
                                                        Text("+$\(String(format: "%.2f", option.price))")
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                                .padding(12)
                                                .background(Color(.systemGray6))
                                                .cornerRadius(8)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxHeight: 250)
                    }

                    TextField("Notes (optional)", text: $modalNotes)
                        .padding().background(Color(.systemGray6)).cornerRadius(10).padding(.horizontal)

                    HStack {
                        Button { withAnimation { showAddModal = false } } label: { 
                            Text("Cancel").foregroundColor(.red).font(.system(size: 20, weight: .semibold)).frame(maxWidth: .infinity).padding() 
                        }
                        
                        Button { 
                            if isReadyToAdd { confirmAddItem(item) } 
                        } label: { 
                            Text("Add Item")
                                .foregroundColor(.white)
                                .font(.system(size: 20, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isReadyToAdd ? Color.blue : Color.gray)
                                .cornerRadius(10) 
                        }
                        .disabled(!isReadyToAdd)
                    }
                    .padding(.horizontal)
                }
                .padding()
                .frame(width: 420)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(radius: 16)
            }
        }
    }
    
    // ===============================================================
    // MARK: - EDIT / DELETE MODAL
    // ===============================================================
    private var editModalOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { withAnimation { showEditModal = false } }

            if let item = itemToEdit {
                VStack(spacing: 20) {
                    Text("Edit \(item.name)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.black)

                    HStack(spacing: 18) {
                        Button { if editQty > 1 { editQty -= 1 } } label: { Image(systemName: "minus.circle.fill").font(.system(size: 32)).foregroundColor(.blue) }
                        Text("\(editQty)").font(.system(size: 28, weight: .semibold)).frame(width: 60)
                        Button { editQty += 1 } label: { Image(systemName: "plus.circle.fill").font(.system(size: 32)).foregroundColor(.blue) }
                    }

                    TextField("Edit Notes...", text: $editNotes)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)

                    HStack(spacing: 16) {
                        Button { 
                            deleteItemFromTable(item)
                            withAnimation { showEditModal = false }
                        } label: { 
                            Text("Delete Item")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(10) 
                        }
                        
                        Button { 
                            saveEditedItem(item)
                            withAnimation { showEditModal = false }
                        } label: { 
                            Text("Save Changes")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10) 
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(24)
                .frame(width: 420)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(radius: 20)
            }
        }
    }

    func handleModifierSelection(group: ModifierGroup, option: ModifierOption) {
        var currentSet = selectedModifiers[group.id] ?? []
        if group.isRequired {
            selectedModifiers[group.id] = [option]
        } else {
            if currentSet.contains(option) {
                currentSet.remove(option)
            } else {
                currentSet.insert(option)
            }
            selectedModifiers[group.id] = currentSet
        }
    }

    func confirmAddItem(_ categoryItem: MenuItemCategory) {
        guard modalQty > 0 else { return }

        let allSelectedOptions = selectedModifiers.values.flatMap { $0 }
        let modifiersPrice = allSelectedOptions.reduce(0) { $0 + $1.price }
        let finalCalculatedPrice = categoryItem.price + modifiersPrice
        
        var finalNotesArray: [String] = []
        let modifierStrings = allSelectedOptions.map { $0.name }
        if !modifierStrings.isEmpty { finalNotesArray.append(modifierStrings.joined(separator: ", ")) }
        if !modalNotes.isEmpty { finalNotesArray.append(modalNotes) }
        let finalCombinedNotes = finalNotesArray.joined(separator: " | ")
        
        let automaticCourse: Int
        switch categoryItem.category {
        case "Appetizers", "Salads", "Soft Drinks", "Coffee", "Juice", "Alcohol":
            automaticCourse = 1
        case "Entrees", "Sides", "Add Ons":
            automaticCourse = 2
        case "Desserts":
            automaticCourse = 3
        default:
            automaticCourse = 1
        }

        let tableRef = db.collection("tables").document(table.tableNumber)

        tableRef.getDocument { snap, _ in
            var items: [[String: Any]] = []
            var guests = table.guests
            if let data = snap?.data() {
                items = data["items"] as? [[String: Any]] ?? []
                guests = data["guests"] as? Int ?? table.guests
            }

            if let index = items.firstIndex(where: {
                ($0["name"] as? String) == categoryItem.name &&
                ($0["notes"] as? String ?? "") == finalCombinedNotes &&
                ($0["course"] as? Int ?? 1) == automaticCourse &&
                ($0["isFired"] as? Bool ?? false) == false
            }) {
                var updated = items[index]
                let oldQty = updated["qty"] as? Int ?? 1
                updated["qty"] = oldQty + modalQty
                items[index] = updated
            } else {
                items.append([
                    "name": categoryItem.name,
                    "price": finalCalculatedPrice,
                    "qty": modalQty,
                    "notes": finalCombinedNotes,
                    "course": automaticCourse,
                    "isFired": false
                ])
            }

            tableRef.setData([
                "tableNumber": table.tableNumber,
                "guests": guests,
                "items": items
            ], merge: true)
            
            withAnimation { showAddModal = false }
        }
    }
    
    // ===============================================================
    // MARK: - FIREBASE EDIT / DELETE LOGIC
    // ===============================================================
    func deleteItemFromTable(_ item: MenuItem) {
        let tableRef = db.collection("tables").document(table.tableNumber)
        tableRef.getDocument { snap, _ in
            var items = snap?.data()?["items"] as? [[String: Any]] ?? []
            
            if let index = items.firstIndex(where: {
                ($0["name"] as? String) == item.name &&
                ($0["notes"] as? String ?? "") == item.notes &&
                ($0["course"] as? Int ?? 1) == item.course &&
                ($0["isFired"] as? Bool ?? false) == item.isFired
            }) {
                items.remove(at: index)
                tableRef.setData(["items": items], merge: true)
            }
        }
    }
    
    func saveEditedItem(_ item: MenuItem) {
        let tableRef = db.collection("tables").document(table.tableNumber)
        tableRef.getDocument { snap, _ in
            var items = snap?.data()?["items"] as? [[String: Any]] ?? []
            
            if let index = items.firstIndex(where: {
                ($0["name"] as? String) == item.name &&
                ($0["notes"] as? String ?? "") == item.notes &&
                ($0["course"] as? Int ?? 1) == item.course &&
                ($0["isFired"] as? Bool ?? false) == item.isFired
            }) {
                items[index]["qty"] = editQty
                items[index]["notes"] = editNotes
                tableRef.setData(["items": items], merge: true)
            }
        }
    }

    func sendToKitchen() {
        let unfired = table.items.filter { !$0.isFired }
        guard !unfired.isEmpty else { return }
        
        let orderRef = db.collection("kitchenOrders").document()
        
        var groups: [String: (MenuItem, Int)] = [:]
        for item in unfired {
            let key = "\(item.name)_\(item.notes)_\(item.course)"
            if let existing = groups[key] {
                groups[key] = (existing.0, existing.1 + item.qty)
            } else {
                groups[key] = (item, item.qty)
            }
        }
        
        let groupedItems = groups.values.sorted { $0.0.name < $1.0.name }
        let itemsSnapshot = groupedItems.map { tuple in
            ["name": tuple.0.name, "qty": tuple.1, "notes": tuple.0.notes, "course": tuple.0.course]
        }
        
        let payload: [String: Any] = [
            "orderNumber": orderRef.documentID,
            "tableNumber": table.tableNumber,
            "serverName": currentServerName, 
            "items": itemsSnapshot,
            "status": "new",
            "createdAt": Timestamp()
        ]
        
        orderRef.setData(payload)
        
        let updatedItems = table.items.map { item -> [String: Any] in
            return [
                "name": item.name,
                "price": item.price,
                "qty": item.qty,
                "notes": item.notes,
                "course": item.course,
                "isFired": true
            ]
        }
        db.collection("tables").document(table.tableNumber).updateData(["items": updatedItems])
        
        withAnimation(.spring()) {
            showSentConfirmation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut) {
                showSentConfirmation = false
            }
        }
    }

    func loadMenu() {
        db.collection("menu").getDocuments { snap, _ in
            guard let docs = snap?.documents else { return }
            
            if docs.isEmpty {
                self.seedDefaultMenu()
                return
            }
            
            allItems = docs.compactMap { doc in
                let d = doc.data()
                guard let name = d["name"] as? String,
                      let price = d["price"] as? Double,
                      let group = d["group"] as? String,
                      let category = d["category"] as? String else { return nil }
                
                var parsedModifiers: [ModifierGroup] = []
                if let rawMods = d["modifiers"] as? [[String: Any]] {
                    parsedModifiers = rawMods.compactMap { modDict in
                        guard let mId = modDict["id"] as? String,
                              let mName = modDict["name"] as? String,
                              let mRequired = modDict["isRequired"] as? Bool,
                              let rawOpts = modDict["options"] as? [[String: Any]] else { return nil }
                        
                        let opts: [ModifierOption] = rawOpts.compactMap { optDict in
                            guard let oId = optDict["id"] as? String,
                                  let oName = optDict["name"] as? String,
                                  let oPrice = optDict["price"] as? Double else { return nil }
                            return ModifierOption(id: oId, name: oName, price: oPrice)
                        }
                        return ModifierGroup(id: mId, name: mName, isRequired: mRequired, options: opts)
                    }
                }
                
                return MenuItemCategory(
                    name: name,
                    price: price,
                    group: group,
                    category: category,
                    modifiers: parsedModifiers,
                    isAvailable: d["isAvailable"] as? Bool ?? true
                )
            }
        }
    }
    
    func seedDefaultMenu() {
        let meatTempOptions = [
            ["id": UUID().uuidString, "name": "Rare", "price": 0.0],
            ["id": UUID().uuidString, "name": "Med Rare", "price": 0.0],
            ["id": UUID().uuidString, "name": "Medium", "price": 0.0],
            ["id": UUID().uuidString, "name": "Well Done", "price": 0.0]
        ]
        
        let burgerAddons = [
            ["id": UUID().uuidString, "name": "Bacon", "price": 2.0],
            ["id": UUID().uuidString, "name": "Avocado", "price": 1.5],
            ["id": UUID().uuidString, "name": "Fried Egg", "price": 1.5]
        ]
        
        let wingDressings = [
            ["id": UUID().uuidString, "name": "Ranch", "price": 0.0],
            ["id": UUID().uuidString, "name": "Blue Cheese", "price": 0.0]
        ]
        
        let saladDressings = [
            ["id": UUID().uuidString, "name": "Ranch", "price": 0.0],
            ["id": UUID().uuidString, "name": "Caesar", "price": 0.0],
            ["id": UUID().uuidString, "name": "Balsamic", "price": 0.0]
        ]
        
        let proteinOptions = [
            ["id": UUID().uuidString, "name": "Grilled Chicken", "price": 3.0],
            ["id": UUID().uuidString, "name": "Carne Asada", "price": 4.5],
            ["id": UUID().uuidString, "name": "Shrimp", "price": 5.0]
        ]

        let seedItems: [[String: Any]] = [
            // FOOD - Appetizers
            ["name": "Lemon Pepper Wings", "price": 12.00, "group": "FOOD", "category": "Appetizers", "isAvailable": true, "modifiers": [["id": UUID().uuidString, "name": "Dressing", "isRequired": true, "options": wingDressings]]],
            ["name": "Loaded Nachos", "price": 10.00, "group": "FOOD", "category": "Appetizers", "isAvailable": true, "modifiers": [["id": UUID().uuidString, "name": "Add Protein", "isRequired": false, "options": proteinOptions]]],
            ["name": "Mozzarella Sticks", "price": 8.00, "group": "FOOD", "category": "Appetizers", "isAvailable": true, "modifiers": []],
            
            // FOOD - Salads
            ["name": "Caesar Salad", "price": 9.00, "group": "FOOD", "category": "Salads", "isAvailable": true, "modifiers": [["id": UUID().uuidString, "name": "Add Protein", "isRequired": false, "options": proteinOptions]]],
            ["name": "House Salad", "price": 8.00, "group": "FOOD", "category": "Salads", "isAvailable": true, "modifiers": [["id": UUID().uuidString, "name": "Dressing", "isRequired": true, "options": saladDressings]]],
            ["name": "Cobb Salad", "price": 11.00, "group": "FOOD", "category": "Salads", "isAvailable": true, "modifiers": [["id": UUID().uuidString, "name": "Dressing", "isRequired": true, "options": saladDressings]]],
            
            // FOOD - Entrees
            ["name": "TapIn Classic Burger", "price": 14.50, "group": "FOOD", "category": "Entrees", "isAvailable": true, "modifiers": [["id": UUID().uuidString, "name": "Meat Temp", "isRequired": true, "options": meatTempOptions], ["id": UUID().uuidString, "name": "Add-ons", "isRequired": false, "options": burgerAddons]]],
            ["name": "Ribeye Steak (12oz)", "price": 28.00, "group": "FOOD", "category": "Entrees", "isAvailable": true, "modifiers": [["id": UUID().uuidString, "name": "Meat Temp", "isRequired": true, "options": meatTempOptions]]],
            ["name": "Grilled Chicken Sandwich", "price": 13.00, "group": "FOOD", "category": "Entrees", "isAvailable": true, "modifiers": [["id": UUID().uuidString, "name": "Add-ons", "isRequired": false, "options": burgerAddons]]],
            
            // FOOD - Sides
            ["name": "French Fries", "price": 4.00, "group": "FOOD", "category": "Sides", "isAvailable": true, "modifiers": []],
            ["name": "Sweet Potato Fries", "price": 5.00, "group": "FOOD", "category": "Sides", "isAvailable": true, "modifiers": []],
            ["name": "Onion Rings", "price": 5.50, "group": "FOOD", "category": "Sides", "isAvailable": true, "modifiers": []],
            
            // FOOD - Add Ons
            ["name": "Extra Bacon", "price": 2.00, "group": "FOOD", "category": "Add Ons", "isAvailable": true, "modifiers": []],
            ["name": "Extra Cheese", "price": 1.00, "group": "FOOD", "category": "Add Ons", "isAvailable": true, "modifiers": []],
            ["name": "Side of Guacamole", "price": 2.50, "group": "FOOD", "category": "Add Ons", "isAvailable": true, "modifiers": []],
            
            // DRINKS - Soft Drinks
            ["name": "Coca-Cola", "price": 2.50, "group": "DRINKS", "category": "Soft Drinks", "isAvailable": true, "modifiers": []],
            ["name": "Sprite", "price": 2.50, "group": "DRINKS", "category": "Soft Drinks", "isAvailable": true, "modifiers": []],
            ["name": "Diet Coke", "price": 2.50, "group": "DRINKS", "category": "Soft Drinks", "isAvailable": true, "modifiers": []],
            
            // DRINKS - Coffee
            ["name": "Black Coffee", "price": 3.00, "group": "DRINKS", "category": "Coffee", "isAvailable": true, "modifiers": []],
            ["name": "Latte", "price": 4.50, "group": "DRINKS", "category": "Coffee", "isAvailable": true, "modifiers": []],
            ["name": "Cappuccino", "price": 4.50, "group": "DRINKS", "category": "Coffee", "isAvailable": true, "modifiers": []],
            
            // DRINKS - Juice
            ["name": "Orange Juice", "price": 3.50, "group": "DRINKS", "category": "Juice", "isAvailable": true, "modifiers": []],
            ["name": "Apple Juice", "price": 3.50, "group": "DRINKS", "category": "Juice", "isAvailable": true, "modifiers": []],
            ["name": "Cranberry Juice", "price": 3.50, "group": "DRINKS", "category": "Juice", "isAvailable": true, "modifiers": []],
            
            // DRINKS - Alcohol
            ["name": "House Margarita", "price": 9.00, "group": "DRINKS", "category": "Alcohol", "isAvailable": true, "modifiers": [
                ["id": UUID().uuidString, "name": "Flavor", "isRequired": true, "options": [
                    ["id": UUID().uuidString, "name": "Classic Lime", "price": 0.0],
                    ["id": UUID().uuidString, "name": "Strawberry", "price": 1.0],
                    ["id": UUID().uuidString, "name": "Mango", "price": 1.0]
                ]],
                ["id": UUID().uuidString, "name": "Rim", "isRequired": false, "options": [
                    ["id": UUID().uuidString, "name": "Salt", "price": 0.0],
                    ["id": UUID().uuidString, "name": "Tajin", "price": 0.0]
                ]]
            ]],
            ["name": "Craft Beer (Pint)", "price": 6.50, "group": "DRINKS", "category": "Alcohol", "isAvailable": true, "modifiers": []],
            ["name": "Red Wine (Glass)", "price": 8.00, "group": "DRINKS", "category": "Alcohol", "isAvailable": true, "modifiers": []],
            
            // DESSERT - Desserts
            ["name": "Chocolate Lava Cake", "price": 8.50, "group": "DESSERT", "category": "Desserts", "isAvailable": true, "modifiers": []],
            ["name": "New York Cheesecake", "price": 7.50, "group": "DESSERT", "category": "Desserts", "isAvailable": true, "modifiers": []],
            ["name": "Vanilla Bean Ice Cream", "price": 4.50, "group": "DESSERT", "category": "Desserts", "isAvailable": true, "modifiers": []]
        ]

        for item in seedItems {
            db.collection("menu").addDocument(data: item)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.loadMenu()
        }
    }

    func listenToTableUpdates() {
        db.collection("tables").document(table.tableNumber).addSnapshotListener { snap, _ in
            guard let data = snap?.data() else { return }
            let guests = data["guests"] as? Int ?? table.guests
            let itemsArray = data["items"] as? [[String: Any]] ?? []

            let items = itemsArray.compactMap { dict -> MenuItem? in
                guard let name = dict["name"] as? String,
                      let price = dict["price"] as? Double else { return nil }
                let qty = dict["qty"] as? Int ?? 1
                let notes = dict["notes"] as? String ?? ""
                let course = dict["course"] as? Int ?? 1
                let isFired = dict["isFired"] as? Bool ?? false
                return MenuItem(name: name, price: price, qty: qty, notes: notes, course: course, isFired: isFired)
            }
            table = TableInfo(tableNumber: table.tableNumber, guests: guests, items: items)
        }
    }
}

struct MenuItemCategory: Hashable {
    let name: String
    let price: Double
    let group: String
    let category: String
    let modifiers: [ModifierGroup]
    let isAvailable: Bool
}
