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
    case staff, reports, menu, settings
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

struct AdminMenuItem: Identifiable {
    let id: String
    var name: String
    var price: Double
    var group: String
    var category: String
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
        if searchText.isEmpty {
            return grouped
        } else {
            return grouped.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    func listenForMenu() {
        listener = db.collection("menu").order(by: "name").addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else { return }
            self.menuItems = documents.compactMap { doc in
                let data = doc.data()
                return AdminMenuItem(
                    id: doc.documentID,
                    name: data["name"] as? String ?? "Unknown",
                    price: data["price"] as? Double ?? 0.0,
                    group: data["group"] as? String ?? "FOOD",
                    category: data["category"] as? String ?? "Appetizers"
                )
            }
        }
    }
    
    func deleteMenuItem(itemId: String) {
        db.collection("menu").document(itemId).delete()
    }
    
    func saveMenuItem(id: String?, name: String, price: Double, group: String, category: String) {
        let data: [String: Any] = [
            "name": name,
            "price": price,
            "group": group,
            "category": category
        ]
        
        if let id = id {
            db.collection("menu").document(id).updateData(data)
        } else {
            db.collection("menu").addDocument(data: data)
        }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.showSaveConfirmation = false
            }
        }
    }
    
    func wipeAllTables() {
        db.collection("tables").getDocuments { snap, _ in
            guard let docs = snap?.documents else { return }
            for doc in docs {
                doc.reference.updateData([
                    "items": [],
                    "guests": 0
                ])
            }
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
            
            // 1. SIDEBAR NAVIGATION
            VStack(spacing: 40) {
                
                Spacer().frame(height: 20)
                
                sidebarButton(icon: "person.2.fill", tab: .staff)
                sidebarButton(icon: "chart.bar.fill", tab: .reports)
                sidebarButton(icon: "list.bullet.rectangle", tab: .menu)
                sidebarButton(icon: "gearshape.fill", tab: .settings)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.black)
                }
                .padding(.bottom, 40)
            }
            .frame(width: 80)
            .background(sidebarGray)
            .zIndex(1)
            
            // 2. MAIN CONTENT AREA
            ZStack(alignment: .topLeading) {
                navy.ignoresSafeArea()
                
                RoundedRectangle(cornerRadius: 84)
                    .fill(Color.orange)
                    .frame(width: 450, height: 450)
                    .rotationEffect(.degrees(35))
                    .offset(x: -350, y: -300)
                
                switch selectedTab {
                case .staff:
                    StaffManagementView()
                case .reports:
                    ReportsDashboardView()
                case .menu:
                    MenuEditorView()
                case .settings:
                    SettingsDashboardView()
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    func sidebarButton(icon: String, tab: AdminTab) -> some View {
        Button(action: { selectedTab = tab }) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(selectedTab == tab ? .white : .black)
                .frame(width: 50, height: 50)
                .background(selectedTab == tab ? Color.orange : Color.clear)
                .cornerRadius(12)
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
                    Text("Staff Management")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        editingUser = nil
                        showUserModal = true
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Add Staff")
                        }
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Search staff by name...", text: $vm.searchText).foregroundColor(.white)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(20)
                    
                    HStack {
                        Text("Name").frame(maxWidth: .infinity, alignment: .leading)
                        Text("PIN Code").frame(width: 120, alignment: .leading)
                        Text("Role Access").frame(width: 160, alignment: .leading)
                        Text("Actions").frame(width: 100, alignment: .trailing)
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 10)
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(vm.filteredUsers) { user in
                                StaffRow(user: user, vm: vm) {
                                    editingUser = user
                                    showUserModal = true
                                }
                                Divider().background(Color.white.opacity(0.1))
                            }
                        }
                    }
                }
                .background(panelBlue)
                .cornerRadius(20)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            
            if showUserModal {
                UserFormModal(
                    user: editingUser,
                    onSave: { name, pin, role in
                        vm.saveUser(id: editingUser?.id, name: name, pin: pin, role: role)
                        showUserModal = false
                    },
                    onCancel: { showUserModal = false }
                )
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
                ForEach(roles, id: \.self) { role in
                    Button(role.capitalized) { vm.updateUserRole(userId: user.id, newRole: role) }
                }
            } label: {
                HStack {
                    Text(user.role.capitalized)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 12))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.15))
                .cornerRadius(8)
            }
            .frame(width: 160, alignment: .leading)
            
            HStack(spacing: 16) {
                Button(action: onEdit) { Image(systemName: "pencil").font(.system(size: 20)).foregroundColor(.blue) }
                Button(action: { vm.deleteUser(userId: user.id) }) { Image(systemName: "trash").font(.system(size: 20)).foregroundColor(.red) }
            }
            .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.02))
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
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Full Name").font(.system(size: 16, weight: .bold)).foregroundColor(.gray)
                    TextField("e.g. James Uzumaki", text: $name).padding().background(Color(.systemGray6)).cornerRadius(10)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("4-Digit PIN Code").font(.system(size: 16, weight: .bold)).foregroundColor(.gray)
                    TextField("0000", text: $pin).keyboardType(.numberPad).padding().background(Color(.systemGray6)).cornerRadius(10)
                        .onChange(of: pin) { newValue in
                            if newValue.count > 4 { pin = String(newValue.prefix(4)) }
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("App Access Role").font(.system(size: 16, weight: .bold)).foregroundColor(.gray)
                    Picker("Role", selection: $role) {
                        ForEach(roles, id: \.self) { r in Text(r.capitalized).tag(r) }
                    }.pickerStyle(SegmentedPickerStyle())
                }
                
                HStack(spacing: 16) {
                    Button(action: onCancel) { Text("Cancel").font(.system(size: 18, weight: .bold)).foregroundColor(.gray).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color(.systemGray5)).cornerRadius(12) }
                    Button(action: {
                        if !name.isEmpty && pin.count == 4 { onSave(name, pin, role) }
                    }) { Text("Save User").font(.system(size: 18, weight: .bold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.blue).cornerRadius(12) }
                }
                .padding(.top, 10)
            }
            .padding(30)
            .frame(width: 400)
            .background(Color.white)
            .cornerRadius(24)
            .shadow(radius: 20)
        }
        .onAppear {
            if let u = user {
                name = u.name; pin = u.pin; role = u.role
            }
        }
    }
}

// ===============================================================
// MARK: - View 2: Reports Dashboard
// ===============================================================
struct ReportsDashboardView: View {
    @StateObject private var vm = ReportsViewModel()
    let panelBlue = Color(red: 0.05, green: 0.25, blue: 0.35)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Sales Reports")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("All Time Data")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
            
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
                        HStack {
                            Circle().fill(Color.orange).frame(width: 12, height: 12)
                            Text("Credit/Apple Pay").foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text(String(format: "$%.2f", vm.cardTotal)).fontWeight(.bold).foregroundColor(.white)
                        }
                        HStack {
                            Circle().fill(Color.green).frame(width: 12, height: 12)
                            Text("Cash in Drawer").foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text(String(format: "$%.2f", vm.cashTotal)).fontWeight(.bold).foregroundColor(.white)
                        }
                    }
                    Spacer()
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(panelBlue)
                .cornerRadius(20)
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Staff Gratuity").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                    Text(String(format: "$%.2f", vm.totalTips)).font(.system(size: 40, weight: .bold)).foregroundColor(.green)
                    Text("Total tips collected across all completed orders.").foregroundColor(.gray)
                    Spacer()
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(panelBlue)
                .cornerRadius(20)
            }
            .padding(.horizontal, 40)
            .frame(height: 220)
            
            Spacer()
        }
    }
    
    func kpiCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.system(size: 16, weight: .medium)).foregroundColor(.white.opacity(0.7))
                Spacer()
                Image(systemName: icon).foregroundColor(.orange)
            }
            Text(value).font(.system(size: 32, weight: .bold)).foregroundColor(.white)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBlue)
        .cornerRadius(20)
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
                    Text("Menu Management")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        editingItem = nil
                        showItemModal = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Menu Item")
                        }
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                
                VStack(spacing: 0) {
                    
                    // Filter and Search Row
                    HStack(spacing: 16) {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.gray)
                            TextField("Search menu...", text: $vm.searchText).foregroundColor(.white)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        
                        Picker("Filter", selection: $vm.selectedFilterGroup) {
                            ForEach(filterGroups, id: \.self) { g in
                                Text(g).tag(g)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 140)
                        .padding(14)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    }
                    .padding(20)
                    
                    HStack {
                        Text("Item Name").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Group").frame(width: 100, alignment: .leading)
                        Text("Category").frame(width: 120, alignment: .leading)
                        Text("Price").frame(width: 80, alignment: .leading)
                        Text("Actions").frame(width: 100, alignment: .trailing)
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 10)
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(vm.filteredItems) { item in
                                MenuItemRow(item: item, vm: vm) {
                                    editingItem = item
                                    showItemModal = true
                                }
                                Divider().background(Color.white.opacity(0.1))
                            }
                        }
                    }
                }
                .background(panelBlue)
                .cornerRadius(20)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            
            if showItemModal {
                MenuItemFormModal(
                    item: editingItem,
                    onSave: { name, price, group, category in
                        vm.saveMenuItem(id: editingItem?.id, name: name, price: price, group: group, category: category)
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
            Text(item.name).font(.system(size: 18, weight: .medium)).foregroundColor(.white).frame(maxWidth: .infinity, alignment: .leading)
            Text(item.group).font(.system(size: 14, weight: .bold)).foregroundColor(.white.opacity(0.7)).frame(width: 100, alignment: .leading)
            Text(item.category).font(.system(size: 16)).foregroundColor(.white.opacity(0.9)).frame(width: 120, alignment: .leading)
            Text(String(format: "$%.2f", item.price)).font(.system(size: 18, weight: .semibold)).foregroundColor(.green).frame(width: 80, alignment: .leading)
            
            HStack(spacing: 16) {
                Button(action: onEdit) { Image(systemName: "pencil").font(.system(size: 20)).foregroundColor(.blue) }
                Button(action: { vm.deleteMenuItem(itemId: item.id) }) { Image(systemName: "trash").font(.system(size: 20)).foregroundColor(.red) }
            }
            .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.02))
    }
}

struct MenuItemFormModal: View {
    let item: AdminMenuItem?
    let onSave: (String, Double, String, String) -> Void
    let onCancel: () -> Void
    
    @State private var name: String = ""
    @State private var priceString: String = ""
    @State private var group: String = "FOOD"
    @State private var category: String = "Appetizers"
    
    let groups = ["FOOD", "DRINKS", "DESSERT"]
    let categoryMap: [String: [String]] = [
        "FOOD": ["Appetizers", "Salads", "Entrees", "Sides", "Desserts", "Add Ons"],
        "DRINKS": ["Soft Drinks", "Coffee", "Juice", "Alcohol"],
        "DESSERT": ["Desserts"]
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 24) {
                Text(item == nil ? "Add Menu Item" : "Edit Menu Item").font(.system(size: 26, weight: .bold)).foregroundColor(.black)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Item Name").font(.system(size: 16, weight: .bold)).foregroundColor(.gray)
                    TextField("e.g. Bacon Cheeseburger", text: $name).padding().background(Color(.systemGray6)).cornerRadius(10)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Price ($)").font(.system(size: 16, weight: .bold)).foregroundColor(.gray)
                    TextField("0.00", text: $priceString).keyboardType(.decimalPad).padding().background(Color(.systemGray6)).cornerRadius(10)
                }
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Group").font(.system(size: 16, weight: .bold)).foregroundColor(.gray)
                        Picker("Group", selection: $group) { ForEach(groups, id: \.self) { g in Text(g).tag(g) } }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .onChange(of: group) { newGroup in category = categoryMap[newGroup]?.first ?? "" }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category").font(.system(size: 16, weight: .bold)).foregroundColor(.gray)
                        Picker("Category", selection: $category) { ForEach(categoryMap[group] ?? [], id: \.self) { c in Text(c).tag(c) } }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                }
                
                HStack(spacing: 16) {
                    Button(action: onCancel) { Text("Cancel").font(.system(size: 18, weight: .bold)).foregroundColor(.gray).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color(.systemGray5)).cornerRadius(12) }
                    Button(action: {
                        let price = Double(priceString) ?? 0.0
                        if !name.isEmpty && price > 0 { onSave(name, price, group, category) }
                    }) { Text("Save Item").font(.system(size: 18, weight: .bold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.blue).cornerRadius(12) }
                }
                .padding(.top, 10)
            }
            .padding(30)
            .frame(width: 440)
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
            }
        }
    }
}

// ===============================================================
// MARK: - View 4: Global Settings Dashboard
// ===============================================================
struct SettingsDashboardView: View {
    @StateObject private var vm = SettingsViewModel()
    let panelBlue = Color(red: 0.05, green: 0.25, blue: 0.35)
    
    // Formatter to prevent invalid tax inputs
    let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // Header
            HStack {
                Text("Global Settings")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    vm.saveSettings()
                }) {
                    HStack {
                        Image(systemName: vm.showSaveConfirmation ? "checkmark.circle.fill" : "tray.and.arrow.down.fill")
                        Text(vm.showSaveConfirmation ? "Saved!" : "Save Settings")
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(vm.showSaveConfirmation ? Color.green : Color.blue)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // SECTION 1: FINANCIAL MATH
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Financial Configuration")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        
                        Divider().background(Color.white.opacity(0.3))
                        
                        HStack(spacing: 40) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Global Tax Rate (%)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                                TextField("14.8", value: $vm.settings.taxRate, formatter: numberFormatter)
                                    .keyboardType(.decimalPad)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Default Tip Percentages")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                HStack {
                                    TextField("15", value: $vm.settings.tip1, formatter: numberFormatter)
                                        .keyboardType(.numberPad)
                                        .padding()
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(10)
                                        .foregroundColor(.white)
                                    
                                    TextField("18", value: $vm.settings.tip2, formatter: numberFormatter)
                                        .keyboardType(.numberPad)
                                        .padding()
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(10)
                                        .foregroundColor(.white)
                                    
                                    TextField("20", value: $vm.settings.tip3, formatter: numberFormatter)
                                        .keyboardType(.numberPad)
                                        .padding()
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(10)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .padding(24)
                    .background(panelBlue)
                    .cornerRadius(20)
                    
                    // SECTION 2: RECEIPT CUSTOMIZATION
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Receipt & System Text")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        
                        Divider().background(Color.white.opacity(0.3))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Customer 'Thank You' Message")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            TextField("Enter message...", text: $vm.settings.receiptMessage)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(24)
                    .background(panelBlue)
                    .cornerRadius(20)
                    
                    // SECTION 3: DANGER ZONE
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Danger Zone")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.red)
                        
                        Divider().background(Color.red.opacity(0.3))
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Wipe All Active Tables")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Instantly clears all items and resets guest counts to 0 across the entire restaurant. This cannot be undone.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                vm.wipeAllTables()
                            }) {
                                Text("Emergency Reset")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 14)
                                    .background(Color.red)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(24)
                    .background(Color.red.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.red.opacity(0.4), lineWidth: 2))
                    .cornerRadius(20)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}
