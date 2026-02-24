//
//  AdminDashboard.swift
//  TapIn
//

import SwiftUI
import FirebaseFirestore
import Combine

// ===============================================================
// MARK: - Tab Enum
// ===============================================================
enum AdminTab {
    case staff, reports, menu, layout, settings
}

// ===============================================================
// MARK: - Models
// ===============================================================
struct AppUser: Identifiable {
    let id: String
    var name: String
    var role: String
    var pin: String
}

struct Receipt: Identifiable {
    let id: String
    let total: Double
    let tip: Double
    let paymentMethod: String
    let timestamp: Date
}

struct ModifierOption: Identifiable, Hashable {
    var id = UUID().uuidString
    var name: String
    var price: Double
}

struct ModifierGroup: Identifiable, Hashable {
    var id = UUID().uuidString
    var name: String
    var isRequired: Bool
    var options: [ModifierOption]
}

struct AdminMenuItem: Identifiable {
    let id: String
    var name: String
    var price: Double
    var group: String
    var category: String
    var modifiers: [ModifierGroup]
    var isAvailable: Bool
}

struct AppSettings {
    var taxRate: Double = 14.8
    var tip1: Int = 15
    var tip2: Int = 18
    var tip3: Int = 20
    var receiptMessage: String = "Thank you!"
}

// ===============================================================
// MARK: - ViewModels
// ===============================================================
class AdminViewModel: ObservableObject {
    @Published var users: [AppUser] = []
    @Published var searchText = ""
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    init() { listenForUsers() }
    deinit { listener?.remove() }
    
    var filteredUsers: [AppUser] {
        if searchText.isEmpty {
            return users
        } else {
            return users.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    func listenForUsers() {
        listener = db.collection("users").order(by: "name").addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else { return }
            self.users = documents.compactMap { doc in
                let data = doc.data()
                return AppUser(
                    id: doc.documentID,
                    name: data["name"] as? String ?? "Unknown",
                    role: data["role"] as? String ?? "server",
                    pin: data["pin"] as? String ?? "0000"
                )
            }
        }
    }
    
    func updateUserRole(userId: String, newRole: String) {
        db.collection("users").document(userId).updateData(["role": newRole])
    }
    
    func deleteUser(userId: String) {
        db.collection("users").document(userId).delete()
    }
    
    func saveUser(id: String?, name: String, pin: String, role: String) {
        let data: [String: Any] = ["name": name, "pin": pin, "role": role]
        if let id = id {
            db.collection("users").document(id).updateData(data)
        } else {
            db.collection("users").addDocument(data: data)
        }
    }
}

class ReportsViewModel: ObservableObject {
    @Published var receipts: [Receipt] = []
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    var grossSales: Double { receipts.reduce(0) { $0 + $1.total } }
    var totalTips: Double { receipts.reduce(0) { $0 + $1.tip } }
    var totalOrders: Int { receipts.count }
    var averageTicket: Double { totalOrders > 0 ? (grossSales / Double(totalOrders)) : 0 }
    
    var cashTotal: Double { receipts.filter { $0.paymentMethod == "Cash" }.reduce(0) { $0 + $1.total } }
    var cardTotal: Double { receipts.filter { $0.paymentMethod != "Cash" }.reduce(0) { $0 + $1.total } }
    
    init() { listenForReceipts() }
    deinit { listener?.remove() }
    
    func listenForReceipts() {
        listener = db.collection("receipts").order(by: "timestamp", descending: true).addSnapshotListener { snapshot, error in
            guard let docs = snapshot?.documents else { return }
            self.receipts = docs.compactMap { doc in
                let data = doc.data()
                return Receipt(
                    id: doc.documentID,
                    total: data["total"] as? Double ?? 0,
                    tip: data["tip"] as? Double ?? 0,
                    paymentMethod: data["paymentMethod"] as? String ?? "Unknown",
                    timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
        }
    }
    
    func closeRegister(actualCash: Double) {
        let expected = cashTotal
        let variance = actualCash - expected
        
        let data: [String: Any] = [
            "expectedCash": expected,
            "actualCash": actualCash,
            "variance": variance,
            "timestamp": Timestamp(date: Date()),
            "status": variance == 0 ? "Exact" : (variance > 0 ? "Over" : "Short")
        ]
        
        db.collection("drawerRecords").addDocument(data: data) { err in
            if let err = err { print("Error saving drawer record: \(err)") }
            else { print("Register successfully closed and logged.") }
        }
    }
}

class MenuEditorViewModel: ObservableObject {
    @Published var menuItems: [AdminMenuItem] = []
    @Published var searchText = ""
    @Published var selectedFilterGroup = "ALL"
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    init() { listenForMenu() }
    deinit { listener?.remove() }
    
    var filteredItems: [AdminMenuItem] {
        let grouped = selectedFilterGroup == "ALL" ? menuItems : menuItems.filter { $0.group == selectedFilterGroup }
        if searchText.isEmpty { return grouped }
        else { return grouped.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }
    }
    
    func listenForMenu() {
        listener = db.collection("menu").order(by: "name").addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else { return }
            self.menuItems = documents.compactMap { doc in
                let data = doc.data()
                
                var parsedModifiers: [ModifierGroup] = []
                if let rawMods = data["modifiers"] as? [[String: Any]] {
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
                
                return AdminMenuItem(
                    id: doc.documentID,
                    name: data["name"] as? String ?? "Unknown",
                    price: data["price"] as? Double ?? 0.0,
                    group: data["group"] as? String ?? "FOOD",
                    category: data["category"] as? String ?? "Appetizers",
                    modifiers: parsedModifiers,
                    isAvailable: data["isAvailable"] as? Bool ?? true
                )
            }
        }
    }
    
    func deleteMenuItem(itemId: String) {
        db.collection("menu").document(itemId).delete()
    }
    
    func saveMenuItem(id: String?, name: String, price: Double, group: String, category: String, modifiers: [ModifierGroup], isAvailable: Bool) {
        let modsData = modifiers.map { mod in
            return [
                "id": mod.id,
                "name": mod.name,
                "isRequired": mod.isRequired,
                "options": mod.options.map { opt in
                    return ["id": opt.id, "name": opt.name, "price": opt.price]
                }
            ]
        }
        
        let data: [String: Any] = [
            "name": name,
            "price": price,
            "group": group,
            "category": category,
            "modifiers": modsData,
            "isAvailable": isAvailable
        ]
        
        if let id = id {
            db.collection("menu").document(id).updateData(data)
        } else {
            db.collection("menu").addDocument(data: data)
        }
    }
}

// ===============================================================
// MARK: - Floor Plan Editor ViewModel
// ===============================================================
class FloorPlanEditorViewModel: ObservableObject {
    @Published var rooms: [RoomLayout] = []
    
    @Published var selectedRoomIndex: Int = 0 {
        didSet { selectedTableId = nil } // Clears selection if we change rooms
    }
    
    @Published var selectedTableId: String? = nil {
        didSet {
            // ✅ NEW: Automatically populates the edit form when you tap a table
            if let tid = selectedTableId,
               selectedRoomIndex < rooms.count,
               let table = rooms[selectedRoomIndex].tables.first(where: { $0.id == tid }) {
                editTableName = table.label
                editTableShape = table.shape
            }
        }
    }
    
    @Published var newRoomName: String = ""
    @Published var newTableName: String = "T1"
    @Published var newTableShape: TableShape = .square
    
    // ✅ NEW: State for editing existing tables
    @Published var editTableName: String = ""
    @Published var editTableShape: TableShape = .square
    
    @Published var showSaveConfirmation = false
    
    private let db = Firestore.firestore()
    
    init() { fetchLayout() }
    
    func fetchLayout() {
        db.collection("settings").document("floorplan").getDocument { snap, _ in
            if let data = snap?.data(), let roomsRaw = data["rooms"] as? [[String: Any]] {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: roomsRaw)
                    self.rooms = try JSONDecoder().decode([RoomLayout].self, from: jsonData)
                } catch { print("Error loading: \(error)") }
            } else {
                self.rooms = [
                    RoomLayout(name: "Main Room", tables: [
                        TableDefinition(label: "T1", shape: .square, x: 0.10, y: 0.15),
                        TableDefinition(label: "T2", shape: .circle, x: 0.26, y: 0.15),
                        TableDefinition(label: "T3", shape: .circle, x: 0.46, y: 0.15),
                        TableDefinition(label: "T4", shape: .rectangle, x: 0.70, y: 0.15),
                        TableDefinition(label: "T5", shape: .circle, x: 0.90, y: 0.33),
                        TableDefinition(label: "T6", shape: .circle, x: 0.90, y: 0.58),
                        TableDefinition(label: "T7", shape: .diamond, x: 0.90, y: 0.85),
                        TableDefinition(label: "T8", shape: .circle, x: 0.70, y: 0.85),
                        TableDefinition(label: "T9", shape: .circle, x: 0.50, y: 0.85),
                        TableDefinition(label: "T10", shape: .rectangle, x: 0.20, y: 0.86),
                        TableDefinition(label: "T11", shape: .diamond, x: 0.10, y: 0.52),
                        TableDefinition(label: "T12", shape: .diamond, x: 0.30, y: 0.50),
                        TableDefinition(label: "T13", shape: .diamond, x: 0.39, y: 0.65),
                        TableDefinition(label: "T14", shape: .diamond, x: 0.39, y: 0.35),
                        TableDefinition(label: "T15", shape: .diamond, x: 0.48, y: 0.50),
                        TableDefinition(label: "T16", shape: .square, x: 0.70, y: 0.50)
                    ]),
                    RoomLayout(name: "Patio", tables: [
                        TableDefinition(label: "P1", shape: .circle, x: 0.20, y: 0.25),
                        TableDefinition(label: "P2", shape: .circle, x: 0.50, y: 0.25),
                        TableDefinition(label: "P3", shape: .circle, x: 0.80, y: 0.25),
                        TableDefinition(label: "P4", shape: .circle, x: 0.20, y: 0.75),
                        TableDefinition(label: "P5", shape: .circle, x: 0.50, y: 0.75),
                        TableDefinition(label: "P6", shape: .circle, x: 0.80, y: 0.75)
                    ]),
                    RoomLayout(name: "Bar Lounge", tables: [
                        TableDefinition(label: "B1", shape: .square, x: 0.15, y: 0.30),
                        TableDefinition(label: "B2", shape: .square, x: 0.15, y: 0.70),
                        TableDefinition(label: "B3", shape: .square, x: 0.35, y: 0.30),
                        TableDefinition(label: "B4", shape: .square, x: 0.35, y: 0.70),
                        TableDefinition(label: "BAR1", shape: .rectangle, x: 0.75, y: 0.50)
                    ])
                ]
            }
        }
    }
    
    func saveLayout() {
        do {
            let encoded = try JSONEncoder().encode(rooms)
            let dict = try JSONSerialization.jsonObject(with: encoded) as? [[String: Any]] ?? []
            db.collection("settings").document("floorplan").setData(["rooms": dict]) { _ in
                self.showSaveConfirmation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.showSaveConfirmation = false }
            }
        } catch { print("Save error: \(error)") }
    }
    
    func addRoom() {
        guard !newRoomName.isEmpty else { return }
        rooms.append(RoomLayout(name: newRoomName, tables: []))
        selectedRoomIndex = rooms.count - 1
        newRoomName = ""
    }
    
    func deleteCurrentRoom() {
        guard !rooms.isEmpty else { return }
        rooms.remove(at: selectedRoomIndex)
        if selectedRoomIndex >= rooms.count {
            selectedRoomIndex = max(0, rooms.count - 1)
        }
    }
    
    func addTable() {
        guard !rooms.isEmpty, !newTableName.isEmpty else { return }
        let newTable = TableDefinition(label: newTableName, shape: newTableShape, x: 0.5, y: 0.5)
        rooms[selectedRoomIndex].tables.append(newTable)
        newTableName = ""
    }
    
    // ✅ NEW: Pushes changes back to the array for editing!
    func updateSelectedTable() {
        guard let tid = selectedTableId, selectedRoomIndex < rooms.count else { return }
        if let idx = rooms[selectedRoomIndex].tables.firstIndex(where: { $0.id == tid }) {
            rooms[selectedRoomIndex].tables[idx].label = editTableName
            rooms[selectedRoomIndex].tables[idx].shape = editTableShape
        }
    }
    
    func deleteSelectedTable() {
        guard let tid = selectedTableId, !rooms.isEmpty else { return }
        rooms[selectedRoomIndex].tables.removeAll { $0.id == tid }
        selectedTableId = nil
    }
}


class SettingsViewModel: ObservableObject {
    @Published var settings = AppSettings()
    @Published var showSaveConfirmation = false
    private let db = Firestore.firestore()
    
    init() { fetchSettings() }
    
    func fetchSettings() {
        db.collection("settings").document("global").getDocument { snap, _ in
            if let data = snap?.data() {
                self.settings.taxRate = data["taxRate"] as? Double ?? 14.8
                self.settings.tip1 = data["tip1"] as? Int ?? 15
                self.settings.tip2 = data["tip2"] as? Int ?? 18
                self.settings.tip3 = data["tip3"] as? Int ?? 20
                self.settings.receiptMessage = data["receiptMessage"] as? String ?? "Thank you!"
            }
        }
    }
    
    func saveSettings() {
        let data: [String: Any] = [
            "taxRate": settings.taxRate,
            "tip1": settings.tip1,
            "tip2": settings.tip2,
            "tip3": settings.tip3,
            "receiptMessage": settings.receiptMessage
        ]
        db.collection("settings").document("global").setData(data) { _ in
            self.showSaveConfirmation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.showSaveConfirmation = false }
        }
    }
    
    func wipeAllTables() {
        db.collection("tables").getDocuments { snap, _ in
            guard let docs = snap?.documents else { return }
            for doc in docs { doc.reference.updateData(["items": [], "guests": 0]) }
        }
    }
}

// ===============================================================
// MARK: - Main Dashboard Container
// ===============================================================
struct AdminDashboard: View {
    @State private var selectedTab: AdminTab = .staff
    @Environment(\.dismiss) private var dismiss
    
    let navy = Color(red: 0.0078, green: 0.188, blue: 0.278)
    let sidebarGray = Color.gray.opacity(0.8)
    
    var body: some View {
        HStack(spacing: 0) {
            
            VStack(spacing: 40) {
                Spacer().frame(height: 20)
                sidebarButton(icon: "person.2.fill", tab: .staff)
                sidebarButton(icon: "chart.bar.fill", tab: .reports)
                sidebarButton(icon: "list.bullet.rectangle", tab: .menu)
                sidebarButton(icon: "map.fill", tab: .layout)
                sidebarButton(icon: "gearshape.fill", tab: .settings)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 26, weight: .bold)).foregroundColor(.black)
                }
                .padding(.bottom, 40)
            }
            .frame(width: 80)
            .background(sidebarGray)
            .zIndex(1)
            
            ZStack(alignment: .topLeading) {
                navy.ignoresSafeArea()
                RoundedRectangle(cornerRadius: 84).fill(Color.orange).frame(width: 450, height: 450).rotationEffect(.degrees(35)).offset(x: -350, y: -300)
                
                switch selectedTab {
                case .staff: StaffManagementView()
                case .reports: ReportsDashboardView()
                case .menu: MenuEditorView()
                case .layout: FloorPlanEditorView()
                case .settings: SettingsDashboardView()
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    func sidebarButton(icon: String, tab: AdminTab) -> some View {
        Button(action: { selectedTab = tab }) {
            Image(systemName: icon).font(.system(size: 24)).foregroundColor(selectedTab == tab ? .white : .black).frame(width: 50, height: 50).background(selectedTab == tab ? Color.orange : Color.clear).cornerRadius(12)
        }
    }
}

// ===============================================================
// MARK: - View 1: Staff Management
// ===============================================================
struct StaffManagementView: View {
    @StateObject private var vm = AdminViewModel()
    @State private var showUserModal = false
    @State private var editingUser: AppUser? = nil
    let panelBlue = Color(red: 0.05, green: 0.25, blue: 0.35)
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Staff Management").font(.system(size: 38, weight: .bold)).foregroundColor(.white)
                    Spacer()
                    Button(action: { editingUser = nil; showUserModal = true }) {
                        HStack { Image(systemName: "person.badge.plus"); Text("Add Staff") }.font(.system(size: 18, weight: .bold)).foregroundColor(.white).padding(.horizontal, 20).padding(.vertical, 12).background(Color.blue).cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40).padding(.top, 20)
                
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Search staff by name...", text: $vm.searchText).foregroundColor(.white)
                    }
                    .padding(14).background(Color.white.opacity(0.1)).cornerRadius(12).padding(20)
                    
                    HStack {
                        Text("Name").frame(maxWidth: .infinity, alignment: .leading)
                        Text("PIN Code").frame(width: 120, alignment: .leading)
                        Text("Role Access").frame(width: 160, alignment: .leading)
                        Text("Actions").frame(width: 100, alignment: .trailing)
                    }
                    .font(.system(size: 16, weight: .bold)).foregroundColor(.gray).padding(.horizontal, 30).padding(.bottom, 10)
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    ScrollView {
                        // ✅ PERFORMANCE FIX: Changed VStack to LazyVStack to fix laggy menus!
                        LazyVStack(spacing: 0) {
                            ForEach(vm.filteredUsers) { user in
                                StaffRow(user: user, vm: vm) { editingUser = user; showUserModal = true }
                                Divider().background(Color.white.opacity(0.1))
                            }
                        }
                    }
                }
                .background(panelBlue).cornerRadius(20).padding(.horizontal, 40).padding(.bottom, 40)
            }
            if showUserModal {
                UserFormModal(user: editingUser, onSave: { name, pin, role in vm.saveUser(id: editingUser?.id, name: name, pin: pin, role: role); showUserModal = false }, onCancel: { showUserModal = false })
            }
        }
    }
}

struct StaffRow: View {
    let user: AppUser
    @ObservedObject var vm: AdminViewModel
    let onEdit: () -> Void
    let roles = ["server", "kitchen", "admin"]
    
    var body: some View {
        HStack {
            Text(user.name).font(.system(size: 20, weight: .medium)).foregroundColor(.white).frame(maxWidth: .infinity, alignment: .leading)
            Text(user.pin).font(.system(size: 18, weight: .semibold, design: .monospaced)).foregroundColor(.orange).frame(width: 120, alignment: .leading)
            Menu {
                ForEach(roles, id: \.self) { role in Button(role.capitalized) { vm.updateUserRole(userId: user.id, newRole: role) } }
            } label: {
                HStack { Text(user.role.capitalized); Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)) }.foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 8).background(Color.white.opacity(0.15)).cornerRadius(8)
            }
            .frame(width: 160, alignment: .leading)
            HStack(spacing: 16) {
                Button(action: onEdit) { Image(systemName: "pencil").font(.system(size: 20)).foregroundColor(.blue) }
                Button(action: { vm.deleteUser(userId: user.id) }) { Image(systemName: "trash").font(.system(size: 20)).foregroundColor(.red) }
            }
            .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal, 30).padding(.vertical, 16).background(Color.white.opacity(0.02))
    }
}

struct UserFormModal: View {
    let user: AppUser?
    let onSave: (String, String, String) -> Void
    let onCancel: () -> Void
    @State private var name: String = ""
    @State private var pin: String = ""
    @State private var role: String = "server"
    let roles = ["server", "kitchen", "admin"]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 24) {
                Text(user == nil ? "Add New Staff" : "Edit Staff Member").font(.system(size: 26, weight: .bold)).foregroundColor(.black)
                VStack(alignment: .leading, spacing: 8) { Text("Full Name").font(.system(size: 16, weight: .bold)).foregroundColor(.gray); TextField("e.g. James Uzumaki", text: $name).padding().background(Color(.systemGray6)).cornerRadius(10) }
                VStack(alignment: .leading, spacing: 8) { Text("4-Digit PIN Code").font(.system(size: 16, weight: .bold)).foregroundColor(.gray); TextField("0000", text: $pin).keyboardType(.numberPad).padding().background(Color(.systemGray6)).cornerRadius(10).onChange(of: pin) { newValue in if newValue.count > 4 { pin = String(newValue.prefix(4)) } } }
                VStack(alignment: .leading, spacing: 8) { Text("App Access Role").font(.system(size: 16, weight: .bold)).foregroundColor(.gray); Picker("Role", selection: $role) { ForEach(roles, id: \.self) { r in Text(r.capitalized).tag(r) } }.pickerStyle(SegmentedPickerStyle()) }
                HStack(spacing: 16) {
                    Button(action: onCancel) { Text("Cancel").font(.system(size: 18, weight: .bold)).foregroundColor(.gray).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color(.systemGray5)).cornerRadius(12) }
                    Button(action: { if !name.isEmpty && pin.count == 4 { onSave(name, pin, role) } }) { Text("Save User").font(.system(size: 18, weight: .bold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.blue).cornerRadius(12) }
                }
                .padding(.top, 10)
            }
            .padding(30).frame(width: 400).background(Color.white).cornerRadius(24).shadow(radius: 20)
        }
        .onAppear { if let u = user { name = u.name; pin = u.pin; role = u.role } }
    }
}

// ===============================================================
// MARK: - View 2: Reports Dashboard
// ===============================================================
struct ReportsDashboardView: View {
    @StateObject private var vm = ReportsViewModel()
    @State private var showCashDrawerModal = false
    let panelBlue = Color(red: 0.05, green: 0.25, blue: 0.35)
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Sales Reports").font(.system(size: 38, weight: .bold)).foregroundColor(.white)
                    Spacer()
                    Button(action: { showCashDrawerModal = true }) {
                        HStack { Image(systemName: "lock.square.fill"); Text("Close Register") }.font(.system(size: 16, weight: .bold)).foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 10).background(Color.red.opacity(0.8)).cornerRadius(10)
                    }
                }
                .padding(.horizontal, 40).padding(.top, 20)
                
                HStack(spacing: 20) {
                    kpiCard(title: "Gross Sales", value: String(format: "$%.2f", vm.grossSales), icon: "chart.line.uptrend.xyaxis")
                    kpiCard(title: "Total Orders", value: "\(vm.totalOrders)", icon: "receipt")
                    kpiCard(title: "Avg Ticket", value: String(format: "$%.2f", vm.averageTicket), icon: "person.2.fill")
                }
                .padding(.horizontal, 40)
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Payment Breakdown").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                        VStack(spacing: 16) {
                            HStack { Circle().fill(Color.orange).frame(width: 12, height: 12); Text("Credit/Apple Pay").foregroundColor(.white.opacity(0.8)); Spacer(); Text(String(format: "$%.2f", vm.cardTotal)).fontWeight(.bold).foregroundColor(.white) }
                            HStack { Circle().fill(Color.green).frame(width: 12, height: 12); Text("Cash in Drawer").foregroundColor(.white.opacity(0.8)); Spacer(); Text(String(format: "$%.2f", vm.cashTotal)).fontWeight(.bold).foregroundColor(.white) }
                        }
                        Spacer()
                    }
                    .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(panelBlue).cornerRadius(20)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Staff Gratuity").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                        Text(String(format: "$%.2f", vm.totalTips)).font(.system(size: 40, weight: .bold)).foregroundColor(.green)
                        Text("Total tips collected across all completed orders.").foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(panelBlue).cornerRadius(20)
                }
                .padding(.horizontal, 40).frame(height: 220)
                Spacer()
            }
            if showCashDrawerModal {
                CashDrawerModal(expectedCash: vm.cashTotal, onSave: { actualCountedCash in vm.closeRegister(actualCash: actualCountedCash); showCashDrawerModal = false }, onCancel: { showCashDrawerModal = false })
            }
        }
    }
    
    func kpiCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text(title).font(.system(size: 16, weight: .medium)).foregroundColor(.white.opacity(0.7)); Spacer(); Image(systemName: icon).foregroundColor(.orange) }
            Text(value).font(.system(size: 32, weight: .bold)).foregroundColor(.white)
        }
        .padding(24).frame(maxWidth: .infinity, alignment: .leading).background(panelBlue).cornerRadius(20)
    }
}

struct CashDrawerModal: View {
    let expectedCash: Double
    let onSave: (Double) -> Void
    let onCancel: () -> Void
    @State private var countedCashString: String = ""
    var countedCash: Double { return Double(countedCashString) ?? 0.0 }
    var variance: Double { return countedCash - expectedCash }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("End of Day: Cash Drawer").font(.system(size: 26, weight: .bold)).foregroundColor(.black)
                VStack(spacing: 16) {
                    HStack { Text("Expected Cash in Drawer:").font(.system(size: 18, weight: .medium)).foregroundColor(.gray); Spacer(); Text(String(format: "$%.2f", expectedCash)).font(.system(size: 22, weight: .bold)).foregroundColor(.black) }
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Actual Counted Cash").font(.system(size: 16, weight: .bold)).foregroundColor(.gray)
                        TextField("0.00", text: $countedCashString).keyboardType(.decimalPad).padding().background(Color(.systemGray6)).cornerRadius(10).font(.system(size: 20, weight: .semibold))
                    }
                    if !countedCashString.isEmpty {
                        HStack {
                            Text("Variance:").font(.system(size: 18, weight: .medium)).foregroundColor(.gray)
                            Spacer()
                            if variance == 0 { Text("Exact Match").font(.system(size: 20, weight: .bold)).foregroundColor(.green) }
                            else if variance < 0 { Text(String(format: "Short by -$%.2f", abs(variance))).font(.system(size: 20, weight: .bold)).foregroundColor(.red) }
                            else { Text(String(format: "Over by +$%.2f", variance)).font(.system(size: 20, weight: .bold)).foregroundColor(.green) }
                        }
                        .padding(.top, 10)
                    }
                }
                HStack(spacing: 16) {
                    Button(action: onCancel) { Text("Cancel").font(.system(size: 18, weight: .bold)).foregroundColor(.gray).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color(.systemGray5)).cornerRadius(12) }
                    Button(action: { onSave(countedCash) }) { Text("Confirm & Log").font(.system(size: 18, weight: .bold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.red).cornerRadius(12) }
                }
                .padding(.top, 10)
            }
            .padding(30).frame(width: 440).background(Color.white).cornerRadius(24).shadow(radius: 20)
        }
    }
}

// ===============================================================
// MARK: - View 3: Menu Editor Dashboard
// ===============================================================
struct MenuEditorView: View {
    @StateObject private var vm = MenuEditorViewModel()
    @State private var showItemModal = false
    @State private var editingItem: AdminMenuItem? = nil
    let panelBlue = Color(red: 0.05, green: 0.25, blue: 0.35)
    
    let filterGroups = ["ALL", "FOOD", "DRINKS", "DESSERT"]
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Menu Management").font(.system(size: 38, weight: .bold)).foregroundColor(.white)
                    Spacer()
                    Button(action: { editingItem = nil; showItemModal = true }) {
                        HStack { Image(systemName: "plus.circle.fill"); Text("Add Menu Item") }.font(.system(size: 18, weight: .bold)).foregroundColor(.white).padding(.horizontal, 20).padding(.vertical, 12).background(Color.blue).cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40).padding(.top, 20)
                
                VStack(spacing: 0) {
                    HStack(spacing: 16) {
                        HStack { Image(systemName: "magnifyingglass").foregroundColor(.gray); TextField("Search menu...", text: $vm.searchText).foregroundColor(.white) }
                            .padding(14).background(Color.white.opacity(0.1)).cornerRadius(12)
                        Picker("Filter", selection: $vm.selectedFilterGroup) { ForEach(filterGroups, id: \.self) { g in Text(g).tag(g) } }
                            .pickerStyle(MenuPickerStyle()).frame(width: 140).padding(14).background(Color.white.opacity(0.1)).cornerRadius(12).foregroundColor(.white)
                    }
                    .padding(20)
                    
                    HStack {
                        Text("Item Name").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Group").frame(width: 100, alignment: .leading)
                        Text("Category").frame(width: 120, alignment: .leading)
                        Text("Price").frame(width: 80, alignment: .leading)
                        Text("Actions").frame(width: 100, alignment: .trailing)
                    }
                    .font(.system(size: 16, weight: .bold)).foregroundColor(.gray).padding(.horizontal, 30).padding(.bottom, 10)
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    ScrollView {
                        // ✅ PERFORMANCE FIX: Changed VStack to LazyVStack to fix laggy menus!
                        LazyVStack(spacing: 0) {
                            ForEach(vm.filteredItems) { item in
                                MenuItemRow(item: item, vm: vm) { editingItem = item; showItemModal = true }
                                Divider().background(Color.white.opacity(0.1))
                            }
                        }
                    }
                }
                .background(panelBlue).cornerRadius(20).padding(.horizontal, 40).padding(.bottom, 40)
            }
            
            if showItemModal {
                MenuItemFormModal(
                    item: editingItem,
                    onSave: { name, price, group, category, modifiers, isAvailable in
                        vm.saveMenuItem(id: editingItem?.id, name: name, price: price, group: group, category: category, modifiers: modifiers, isAvailable: isAvailable)
                        showItemModal = false
                    },
                    onCancel: { showItemModal = false }
                )
            }
        }
    }
}

struct MenuItemRow: View {
    let item: AdminMenuItem
    @ObservedObject var vm: MenuEditorViewModel
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(item.isAvailable ? .white : .gray)
                
                if !item.isAvailable {
                    Text("SOLD OUT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(item.group).font(.system(size: 14, weight: .bold)).foregroundColor(.white.opacity(0.7)).frame(width: 100, alignment: .leading)
            Text(item.category).font(.system(size: 16)).foregroundColor(.white.opacity(0.9)).frame(width: 120, alignment: .leading)
            Text(String(format: "$%.2f", item.price)).font(.system(size: 18, weight: .semibold)).foregroundColor(.green).frame(width: 80, alignment: .leading)
            
            HStack(spacing: 16) {
                Button(action: onEdit) { Image(systemName: "pencil").font(.system(size: 20)).foregroundColor(.blue) }
                Button(action: { vm.deleteMenuItem(itemId: item.id) }) { Image(systemName: "trash").font(.system(size: 20)).foregroundColor(.red) }
            }
            .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal, 30).padding(.vertical, 16).background(Color.white.opacity(0.02))
    }
}

struct MenuItemFormModal: View {
    let item: AdminMenuItem?
    let onSave: (String, Double, String, String, [ModifierGroup], Bool) -> Void
    let onCancel: () -> Void
    
    @State private var name: String = ""
    @State private var priceString: String = ""
    @State private var group: String = "FOOD"
    @State private var category: String = "Appetizers"
    @State private var isAvailable: Bool = true
    
    @State private var modifiers: [ModifierGroup] = []
    
    let groups = ["FOOD", "DRINKS", "DESSERT"]
    let categoryMap: [String: [String]] = [
        "FOOD": ["Appetizers", "Salads", "Entrees", "Sides", "Desserts", "Add Ons"],
        "DRINKS": ["Soft Drinks", "Coffee", "Juice", "Alcohol"],
        "DESSERT": ["Desserts"]
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            
            VStack(spacing: 0) {
                Text(item == nil ? "Add Menu Item" : "Edit Menu Item")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.black)
                    .padding()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        Toggle("Item is Available (In Stock)", isOn: $isAvailable)
                            .font(.system(size: 16, weight: .bold))
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Item Name").font(.system(size: 16, weight: .bold)).foregroundColor(.gray)
                            TextField("e.g. Bacon Cheeseburger", text: $name).padding().background(Color(.systemGray6)).cornerRadius(10)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Base Price ($)").font(.system(size: 16, weight: .bold)).foregroundColor(.gray)
                            TextField("0.00", text: $priceString).keyboardType(.decimalPad).padding().background(Color(.systemGray6)).cornerRadius(10)
                        }
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Group").font(.system(size: 16, weight: .bold)).foregroundColor(.gray)
                                Picker("Group", selection: $group) { ForEach(groups, id: \.self) { g in Text(g).tag(g) } }
                                    .pickerStyle(MenuPickerStyle()).frame(maxWidth: .infinity).padding(12).background(Color(.systemGray6)).cornerRadius(10)
                                    .onChange(of: group) { newGroup in category = categoryMap[newGroup]?.first ?? "" }
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Category").font(.system(size: 16, weight: .bold)).foregroundColor(.gray)
                                Picker("Category", selection: $category) { ForEach(categoryMap[group] ?? [], id: \.self) { c in Text(c).tag(c) } }
                                    .pickerStyle(MenuPickerStyle()).frame(maxWidth: .infinity).padding(12).background(Color(.systemGray6)).cornerRadius(10)
                            }
                        }
                        
                        Divider().padding(.vertical, 10)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Modifier Groups").font(.system(size: 20, weight: .bold)).foregroundColor(.black)
                                Spacer()
                                Button(action: {
                                    modifiers.append(ModifierGroup(name: "", isRequired: false, options: []))
                                }) {
                                    Text("+ Add Group").font(.system(size: 14, weight: .bold)).foregroundColor(.blue)
                                }
                            }
                            
                            ForEach(modifiers) { modGroup in
                                if let gIndex = modifiers.firstIndex(where: { $0.id == modGroup.id }) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            TextField("Group Name (e.g. Meat Temp)", text: $modifiers[gIndex].name)
                                                .font(.system(size: 16, weight: .bold))
                                            
                                            Toggle("Required?", isOn: $modifiers[gIndex].isRequired)
                                                .labelsHidden()
                                            Text("Req.")
                                                .font(.system(size: 12)).foregroundColor(.gray)
                                            
                                            Button(action: {
                                                modifiers.remove(at: gIndex)
                                            }) {
                                                Image(systemName: "trash").foregroundColor(.red)
                                            }
                                        }
                                        
                                        ForEach(modGroup.options) { option in
                                            if let oIndex = modifiers[gIndex].options.firstIndex(where: { $0.id == option.id }) {
                                                HStack {
                                                    Image(systemName: "circle").foregroundColor(.gray)
                                                    TextField("Option Name", text: $modifiers[gIndex].options[oIndex].name)
                                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                                    
                                                    TextField("Price ($0.00)", value: $modifiers[gIndex].options[oIndex].price, formatter: NumberFormatter())
                                                        .keyboardType(.decimalPad)
                                                        .frame(width: 80)
                                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                                    
                                                    Button(action: {
                                                        modifiers[gIndex].options.remove(at: oIndex)
                                                    }) {
                                                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                                    }
                                                }
                                            }
                                        }
                                        
                                        Button(action: {
                                            modifiers[gIndex].options.append(ModifierOption(name: "", price: 0.0))
                                        }) {
                                            Text("+ Add Option").font(.system(size: 14)).foregroundColor(.blue)
                                        }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 500)
                
                HStack(spacing: 16) {
                    Button(action: onCancel) { Text("Cancel").font(.system(size: 18, weight: .bold)).foregroundColor(.gray).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color(.systemGray5)).cornerRadius(12) }
                    Button(action: {
                        let price = Double(priceString) ?? 0.0
                        if !name.isEmpty && price >= 0 { onSave(name, price, group, category, modifiers, isAvailable) }
                    }) { Text("Save Item").font(.system(size: 18, weight: .bold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.blue).cornerRadius(12) }
                }
                .padding()
            }
            .frame(width: 500)
            .background(Color.white)
            .cornerRadius(24)
            .shadow(radius: 20)
        }
        .onAppear {
            if let i = item {
                name = i.name
                priceString = String(format: "%.2f", i.price)
                group = i.group
                category = i.category
                modifiers = i.modifiers
                isAvailable = i.isAvailable
            }
        }
    }
}

// ===============================================================
// MARK: - View 4: FLOOR PLAN EDITOR
// ===============================================================
struct FloorPlanEditorView: View {
    @StateObject private var vm = FloorPlanEditorViewModel()
    let panelBlue = Color(red: 0.05, green: 0.25, blue: 0.35)
    
    var body: some View {
        HStack(spacing: 0) {
            // LEFT PANEL: Controls (Wrapped in a ScrollView to fit everything safely)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Text("Layout Editor")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !vm.rooms.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Select Room")
                                .font(.system(size: 16, weight: .bold)).foregroundColor(.gray)
                            
                            HStack {
                                Picker("Room", selection: $vm.selectedRoomIndex) {
                                    ForEach(0..<vm.rooms.count, id: \.self) { idx in
                                        Text(vm.rooms[idx].name).tag(idx)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                                
                                Button(action: vm.deleteCurrentRoom) {
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(.white)
                                        .padding(14)
                                        .background(Color.red)
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.3)).padding(.vertical, 10)
                    
                    // Add Room
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Add New Room").font(.system(size: 16, weight: .bold)).foregroundColor(.gray)
                        HStack {
                            TextField("e.g. Patio", text: $vm.newRoomName)
                                .padding(12).background(Color.white.opacity(0.1)).cornerRadius(10).foregroundColor(.white)
                            Button(action: vm.addRoom) {
                                Image(systemName: "plus.app.fill").font(.system(size: 32)).foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.3)).padding(.vertical, 10)
                    
                    // Add Table
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Add New Table").font(.system(size: 16, weight: .bold)).foregroundColor(.gray)
                        
                        TextField("Table Name (e.g. T12)", text: $vm.newTableName)
                            .padding(12).background(Color.white.opacity(0.1)).cornerRadius(10).foregroundColor(.white)
                        
                        Picker("Shape", selection: $vm.newTableShape) {
                            Text("Square").tag(TableShape.square)
                            Text("Circle").tag(TableShape.circle)
                            Text("Rectangle").tag(TableShape.rectangle)
                            Text("Diamond").tag(TableShape.diamond)
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(12).background(Color.white.opacity(0.1)).cornerRadius(10).foregroundColor(.white)
                        
                        Button(action: vm.addTable) {
                            Text("Spawn Table")
                                .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.blue).cornerRadius(10)
                        }
                    }
                    
                    // ✅ NEW: Edit the table when tapped!
                    if vm.selectedTableId != nil {
                        Divider().background(Color.white.opacity(0.3)).padding(.vertical, 10)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Edit Selected Table")
                                .font(.system(size: 16, weight: .bold)).foregroundColor(.orange)
                            
                            TextField("Name", text: $vm.editTableName)
                                .padding(12).background(Color.white.opacity(0.1)).cornerRadius(10).foregroundColor(.white)
                            
                            Picker("Shape", selection: $vm.editTableShape) {
                                Text("Square").tag(TableShape.square)
                                Text("Circle").tag(TableShape.circle)
                                Text("Rectangle").tag(TableShape.rectangle)
                                Text("Diamond").tag(TableShape.diamond)
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding(12).background(Color.white.opacity(0.1)).cornerRadius(10).foregroundColor(.white)
                            
                            HStack {
                                Button(action: vm.updateSelectedTable) {
                                    Text("Update")
                                        .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                                        .frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.green).cornerRadius(10)
                                }
                                
                                Button(action: vm.deleteSelectedTable) {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                                        .padding(.vertical, 14).padding(.horizontal, 20).background(Color.red).cornerRadius(10)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(12)
                    }
                    
                    Spacer(minLength: 40)
                    
                    Button(action: vm.saveLayout) {
                        HStack {
                            Image(systemName: vm.showSaveConfirmation ? "checkmark.circle.fill" : "square.and.arrow.down.fill")
                            Text(vm.showSaveConfirmation ? "Saved!" : "Save Layout to Database")
                        }
                        .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16).background(vm.showSaveConfirmation ? Color.green : Color.orange).cornerRadius(10)
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 30)
                .padding(.top, 30)
            }
            .frame(width: 340)
            .background(panelBlue)
            
            // RIGHT PANEL: The Canvas
            VStack {
                if !vm.rooms.isEmpty && vm.selectedRoomIndex < vm.rooms.count {
                    Text(vm.rooms[vm.selectedRoomIndex].name)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    ZStack {
                        Color.gray.opacity(0.5)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue, lineWidth: 4))
                            .padding(40)
                        
                        GeometryReader { geo in
                            let w = geo.size.width
                            let h = geo.size.height
                            
                            ForEach($vm.rooms[vm.selectedRoomIndex].tables) { $table in
                                DraggableAdminTable(
                                    table: $table,
                                    geo: geo,
                                    isSelected: vm.selectedTableId == table.id,
                                    onSelect: { vm.selectedTableId = table.id }
                                )
                            }
                        }
                    }
                } else {
                    Text("No rooms configured. Add a room to start.")
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Tap the blank space of the canvas to deselect a table
            .contentShape(Rectangle())
            .onTapGesture { vm.selectedTableId = nil }
        }
    }
}

// Special Draggable Graphic isolated for the Admin Panel
struct DraggableAdminTable: View {
    @Binding var table: TableDefinition
    let geo: GeometryProxy
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            switch table.shape {
            case .square: Rectangle().fill(Color.gray).frame(width: 110, height: 110).cornerRadius(12)
            case .circle: Circle().fill(Color.gray).frame(width: 130, height: 130)
            case .rectangle: Rectangle().fill(Color.gray).frame(width: 300, height: 75).cornerRadius(12)
            case .diamond: Rectangle().fill(Color.gray).frame(width: 100, height: 100).rotationEffect(.degrees(45))
            }
            
            Text(table.label).foregroundColor(.black).font(.system(size: 20, weight: .bold))
            
            if isSelected {
                Rectangle()
                    .stroke(Color.green, lineWidth: 6)
                    .frame(width: 140, height: 140)
            }
        }
        .onTapGesture { onSelect() }
        .offset(dragOffset)
        .gesture(
            DragGesture()
                .onChanged { val in
                    dragOffset = val.translation
                }
                .onEnded { val in
                    let pctX = val.translation.width / geo.size.width
                    let pctY = val.translation.height / geo.size.height
                    
                    table.x = min(max(table.x + pctX, 0.05), 0.95)
                    table.y = min(max(table.y + pctY, 0.05), 0.95)
                    
                    dragOffset = .zero
                }
        )
        .position(x: geo.size.width * table.x, y: geo.size.height * table.y)
    }
}

// ===============================================================
// MARK: - View 5: Global Settings Dashboard
// ===============================================================
struct SettingsDashboardView: View {
    @StateObject private var vm = SettingsViewModel()
    let panelBlue = Color(red: 0.05, green: 0.25, blue: 0.35)
    let numberFormatter: NumberFormatter = { let f = NumberFormatter(); f.numberStyle = .decimal; return f }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Global Settings").font(.system(size: 38, weight: .bold)).foregroundColor(.white)
                Spacer()
                Button(action: { vm.saveSettings() }) {
                    HStack { Image(systemName: vm.showSaveConfirmation ? "checkmark.circle.fill" : "tray.and.arrow.down.fill"); Text(vm.showSaveConfirmation ? "Saved!" : "Save Settings") }.font(.system(size: 18, weight: .bold)).foregroundColor(.white).padding(.horizontal, 20).padding(.vertical, 12).background(vm.showSaveConfirmation ? Color.green : Color.blue).cornerRadius(12)
                }
            }
            .padding(.horizontal, 40).padding(.top, 20)
            
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Financial Configuration").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                        Divider().background(Color.white.opacity(0.3))
                        HStack(spacing: 40) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Global Tax Rate (%)").font(.system(size: 16, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                                TextField("14.8", value: $vm.settings.taxRate, formatter: numberFormatter).keyboardType(.decimalPad).padding().background(Color.white.opacity(0.1)).cornerRadius(10).foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Default Tip Percentages").font(.system(size: 16, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                                HStack {
                                    TextField("15", value: $vm.settings.tip1, formatter: numberFormatter).keyboardType(.numberPad).padding().background(Color.white.opacity(0.1)).cornerRadius(10).foregroundColor(.white)
                                    TextField("18", value: $vm.settings.tip2, formatter: numberFormatter).keyboardType(.numberPad).padding().background(Color.white.opacity(0.1)).cornerRadius(10).foregroundColor(.white)
                                    TextField("20", value: $vm.settings.tip3, formatter: numberFormatter).keyboardType(.numberPad).padding().background(Color.white.opacity(0.1)).cornerRadius(10).foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .padding(24).background(panelBlue).cornerRadius(20)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Receipt & System Text").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                        Divider().background(Color.white.opacity(0.3))
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Customer 'Thank You' Message").font(.system(size: 16, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                            TextField("Enter message...", text: $vm.settings.receiptMessage).padding().background(Color.white.opacity(0.1)).cornerRadius(10).foregroundColor(.white)
                        }
                    }
                    .padding(24).background(panelBlue).cornerRadius(20)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Danger Zone").font(.system(size: 22, weight: .bold)).foregroundColor(.red)
                        Divider().background(Color.red.opacity(0.3))
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Wipe All Active Tables").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                                Text("Instantly clears all items and resets guest counts to 0 across the entire restaurant. This cannot be undone.").font(.system(size: 14)).foregroundColor(.white.opacity(0.6))
                            }
                            Spacer()
                            Button(action: { vm.wipeAllTables() }) {
                                Text("Emergency Reset").font(.system(size: 16, weight: .bold)).foregroundColor(.white).padding(.horizontal, 24).padding(.vertical, 14).background(Color.red).cornerRadius(10)
                            }
                        }
                    }
                    .padding(24).background(Color.red.opacity(0.1)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.red.opacity(0.4), lineWidth: 2)).cornerRadius(20)
                }
                .padding(.horizontal, 40).padding(.bottom, 40)
            }
        }
    }
}
