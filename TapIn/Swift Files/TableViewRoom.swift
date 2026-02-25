//
//  TableViewRoom.swift
//  TapIn
//

import SwiftUI
import FirebaseFirestore
import Combine

// ===============================================================
// MARK: - MODELS (UPGRADED FOR DATABASE)
// ===============================================================

enum TableShape: String, Codable, CaseIterable {
    case square, circle, rectangle, diamond
}

struct TableDefinition: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var label: String
    var shape: TableShape
    var x: Double
    var y: Double
}

struct RoomLayout: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    var tables: [TableDefinition]
}

struct ServerNotification: Identifiable {
    let id: String
    let tableNumber: String
    let time: Date
}

// ===============================================================
// MARK: - VIEW MODEL
// ===============================================================

class ServerRoomViewModel: ObservableObject {
    @Published var readyNotifications: [ServerNotification] = []
    
    @Published var rooms: [RoomLayout] = []
    
    private let db = Firestore.firestore()
    private var kitchenListener: ListenerRegistration?
    private var floorplanListener: ListenerRegistration?
    
    init() {
        listenToKitchenNotifications()
        listenToFloorPlan()
    }
    
    deinit {
        kitchenListener?.remove()
        floorplanListener?.remove()
    }
    
    func listenToFloorPlan() {
        floorplanListener = db.collection("settings").document("floorplan").addSnapshotListener { snap, _ in
            guard let data = snap?.data(),
                  let roomsRaw = data["rooms"] as? [[String: Any]] else {
                self.rooms = ServerRoomViewModel.defaultLayouts
                return
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: roomsRaw)
                let decodedRooms = try JSONDecoder().decode([RoomLayout].self, from: jsonData)
                DispatchQueue.main.async {
                    self.rooms = decodedRooms
                }
            } catch {
                print("Error decoding floor plan:", error)
            }
        }
    }
    
    func listenToKitchenNotifications() {
        kitchenListener = db.collection("kitchenOrders")
            .whereField("status", isEqualTo: "ready")
            .addSnapshotListener { snap, _ in
                guard let docs = snap?.documents else { return }
                self.readyNotifications = docs.compactMap { doc in
                    let d = doc.data()
                    let tableNum = d["tableNumber"] as? String ?? "Unknown"
                    let ts = d["createdAt"] as? Timestamp ?? Timestamp()
                    return ServerNotification(id: doc.documentID, tableNumber: tableNum, time: ts.dateValue())
                }
            }
    }
    
    func markAsServed(_ id: String) {
        db.collection("kitchenOrders").document(id).setData(["status": "served"], merge: true)
    }
    
    static let defaultLayouts: [RoomLayout] = [
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

// ===============================================================
// MARK: - MAIN VIEW
// ===============================================================

struct TableViewRoom: View {

    @StateObject private var vm = TableViewModel()
    @StateObject private var serverVM = ServerRoomViewModel()
    
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("currentServerName") private var currentServerName = "Server"

    @State private var selectedTable: TableInfo? = nil
    @State private var showPanel = false

    @State private var openMenu = false
    @State private var tableForMenu: TableInfo? = nil

    @State private var openPayment = false
    @State private var tableForPayment: TableInfo? = nil
    
    @State private var currentRoomIndex = 0
    @State private var showNotifications = false
    @State private var isPulsing = false
    
    @State private var showTakeoutPrompt = false
    @State private var takeoutCustomerName = ""
    @State private var showSentConfirmation = false

    let db = Firestore.firestore()

    var body: some View {

        ZStack(alignment: .leading) {

            // ============================================
            // 1. BACKGROUND
            // ============================================
            Color(red: 0.02, green: 0.16, blue: 0.27)
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 84)
                .fill(Color.orange)
                .frame(width: 540, height: 420)
                .rotationEffect(.degrees(18))
                .offset(x: 520, y: -520)

            // ============================================
            // 2. FLOOR PLAN
            // ============================================
            if serverVM.rooms.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView().tint(.white).scaleEffect(2)
                        Spacer()
                    }
                    Spacer()
                }
            } else {
                VStack {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.white.opacity(0.3))
                                .cornerRadius(12)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                withAnimation { showTakeoutPrompt = true }
                            }) {
                                Image(systemName: "bag.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.white.opacity(0.3))
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                withAnimation { showNotifications.toggle() }
                            }) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                    
                                    if !serverVM.readyNotifications.isEmpty {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 22, height: 22)
                                            .overlay(
                                                Text("\(serverVM.readyNotifications.count)")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                            .offset(x: 8, y: -8)
                                    }
                                }
                                .padding(10)
                                .background(Color.white.opacity(showNotifications ? 0.3 : 0.0))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    HStack {
                        Button(action: previousRoom) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                                .padding(10)
                        }

                        Spacer()

                        Text(serverVM.rooms[safeIndex].name)
                            .font(.system(size: 50, weight: .bold))
                            .foregroundColor(.white)
                            .id(serverVM.rooms[safeIndex].name)

                        Spacer()

                        Button(action: nextRoom) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                                .padding(10)
                        }
                    }
                    .padding(.horizontal, 40)

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

                            ForEach(serverVM.rooms[safeIndex].tables) { tableDef in
                                tableButton(
                                    tableDef.label,
                                    tableDef.shape,
                                    w * tableDef.x,
                                    h * tableDef.y,
                                    roomName: serverVM.rooms[safeIndex].name
                                )
                            }
                        }
                    }
                    .frame(height: 600)
                }
            }

            // ============================================
            // 3. SIDE PANEL & BUG-FREE CUTOUT CATCHER
            // ============================================
            if showPanel, let table = selectedTable {
                ZStack(alignment: .leading) {
                    
                    // The Invisible Layer (ONLY exists on the right side of the screen)
                    HStack(spacing: 0) {
                        Spacer().frame(width: 360)
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showPanel = false
                                }
                            }
                    }
                    
                    // The Actual Interactive Panel
                    SidePanel(
                        table: table,
                        serverName: currentServerName,
                        addItemsAction: { tableForMenu = table; openMenu = true },
                        removeItem: { item in removeItemFromTable(table: table, item: item) },
                        updateGuests: { newGuests in updateGuestCount(table: table, guests: newGuests) },
                        close: { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showPanel = false } },
                        fireCourseAction: { courseNum in fireCourse(table: table, course: courseNum) },
                        payAction: { tableForPayment = table; openPayment = true }
                    )
                    .frame(width: 360)
                    .transition(.move(edge: .leading))
                }
                .zIndex(50)
            }
            
            // ============================================
            // 4. NOTIFICATION DROPDOWN
            // ============================================
            if showNotifications {
                ZStack(alignment: .topTrailing) {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation { showNotifications = false }
                        }
                    
                    notificationDropdown
                        .padding(.top, 80)
                        .padding(.trailing, 20)
                }
                .zIndex(51)
                .transition(.opacity)
            }
            
            // ============================================
            // 5. MODALS
            // ============================================
            if showTakeoutPrompt {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("New Takeout Order")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.black)
                        
                        TextField("Customer Name", text: $takeoutCustomerName)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .font(.system(size: 20))
                        
                        HStack(spacing: 16) {
                            Button(action: { showTakeoutPrompt = false }) {
                                Text("Cancel")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGray5))
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                let newTable = TableInfo(tableNumber: "ToGo: \(takeoutCustomerName)", guests: 1, items: [])
                                tableForMenu = newTable
                                openMenu = true
                                showTakeoutPrompt = false
                                takeoutCustomerName = ""
                            }) {
                                Text("Start Order")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                            .disabled(takeoutCustomerName.isEmpty)
                        }
                    }
                    .padding(30)
                    .frame(width: 400)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(radius: 20)
                }
                .zIndex(100)
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
                .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
                .transition(.scale.combined(with: .opacity))
                .zIndex(150)
            }
        }
        .navigationBarHidden(true)
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
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReturnToFloorPlan"))) { _ in
            openMenu = false
            openPayment = false
            showPanel = false
            showTakeoutPrompt = false
        }
    }
    
    var safeIndex: Int {
        if serverVM.rooms.isEmpty { return 0 }
        return min(currentRoomIndex, serverVM.rooms.count - 1)
    }
    
    var notificationDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ready for Delivery")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray5))
            
            if serverVM.readyNotifications.isEmpty {
                Text("No orders are currently waiting in the window.")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .padding(20)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(serverVM.readyNotifications) { notif in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Table \(notif.tableNumber)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.black)
                                    Text("Food is ready to run!")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                
                                Button(action: {
                                    serverVM.markAsServed(notif.id)
                                    if serverVM.readyNotifications.count == 1 {
                                        showNotifications = false
                                    }
                                }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 340)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .contentShape(Rectangle())
        .onTapGesture { }
    }
    
    func previousRoom() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentRoomIndex > 0 { currentRoomIndex -= 1 }
            else { currentRoomIndex = serverVM.rooms.count - 1 }
            showPanel = false
        }
    }
    
    func nextRoom() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentRoomIndex < serverVM.rooms.count - 1 { currentRoomIndex += 1 }
            else { currentRoomIndex = 0 }
            showPanel = false
        }
    }

    func fireCourse(table: TableInfo, course: Int) {
        let unfired = table.items.filter { $0.course == course && !$0.isFired }
        guard !unfired.isEmpty else { return }
        
        let orderRef = db.collection("kitchenOrders").document()
        let itemsSnapshot = unfired.grouped().map { grouped in
            [
                "name": grouped.item.name,
                "qty": grouped.quantity,
                "notes": grouped.item.notes,
                "course": course
            ]
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
                "isFired": (item.course == course) ? true : item.isFired
            ]
        }
        // ✅ Using setData with merge prevents crashes if the table document is new!
        db.collection("tables").document(table.tableNumber).setData(["items": updatedItems], merge: true)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showPanel = false }
        withAnimation(.spring()) { showSentConfirmation = true }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut) { showSentConfirmation = false }
        }
    }

    func tableButton(_ label: String, _ shape: TableShape, _ x: CGFloat, _ y: CGFloat, roomName: String) -> some View {
        
        let fullTableName = "\(label) (\(roomName))"

        let table = vm.tables.first(where: { $0.tableNumber == fullTableName })
        let occupied = (table?.items.contains(where: { $0.qty > 0 }) ?? false)
        let isReady = serverVM.readyNotifications.contains { $0.tableNumber == fullTableName }
        
        let color: Color
        if isReady {
            color = .green
        } else if occupied {
            color = .yellow
        } else {
            color = .gray
        }

        return TableView(label: label, shape: shape, color: color) {
            if let info = table {
                selectedTable = info
            } else {
                selectedTable = TableInfo(tableNumber: fullTableName, guests: 0, items: [])
            }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showPanel = true
            }
        }
        .position(x: x, y: y)
        .scaleEffect(isReady ? (isPulsing ? 1.08 : 1.0) : 1.0)
        .animation(isReady ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: isPulsing)
    }

    func removeItemFromTable(table: TableInfo, item: MenuItem) {
        let ref = db.collection("tables").document(table.tableNumber)
        ref.getDocument { snap, _ in
            guard let data = snap?.data() else { return }
            var items = data["items"] as? [[String: Any]] ?? []

            if let index = items.firstIndex(where: {
                ($0["name"] as? String) == item.name &&
                ($0["notes"] as? String ?? "") == item.notes &&
                ($0["course"] as? Int ?? 1) == item.course &&
                ($0["isFired"] as? Bool ?? false) == item.isFired
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
            // ✅ Using setData with merge prevents crashes!
            ref.setData(["items": items], merge: true)
        }
    }

    func updateGuestCount(table: TableInfo, guests: Int) {
        // ✅ Using setData with merge prevents crashes!
        db.collection("tables").document(table.tableNumber).setData(["guests": guests], merge: true)
    }
}

extension Array where Element == MenuItem {
    func grouped() -> [(item: MenuItem, quantity: Int)] {
        var groups: [String: (MenuItem, Int)] = [:]
        for item in self {
            let key = "\(item.name)_\(item.notes)_\(item.course)_\(item.isFired)"
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
                HStack {
                    Text(item.name).foregroundColor(.white).font(.system(size: 18, weight: .semibold))
                    if !item.isFired {
                        Text("HOLD")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(Color.red.opacity(0.8)).cornerRadius(4)
                    }
                }
                
                if !item.notes.isEmpty {
                    Text(item.notes).foregroundColor(.white.opacity(0.7)).font(.system(size: 14))
                }
                if quantity > 1 {
                    Text("x\(quantity)").foregroundColor(.white.opacity(0.7)).font(.system(size: 15))
                }
            }
            Spacer()
            Text(String(format: "$%.2f", item.price * Double(quantity))).foregroundColor(.white).font(.system(size: 18, weight: .medium))
            Button(action: onDelete) { Image(systemName: "trash.fill").foregroundColor(.white.opacity(0.9)).font(.system(size: 20)) }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 18)
        .background(Color.white.opacity(0.15))
        .cornerRadius(14)
    }
}

// ===============================================================
// MARK: - SIDE PANEL
// ===============================================================
struct SidePanel: View {
    let table: TableInfo
    let serverName: String
    
    let addItemsAction: () -> Void
    let removeItem: (MenuItem) -> Void
    let updateGuests: (Int) -> Void
    let close: () -> Void
    let fireCourseAction: (Int) -> Void
    let payAction: () -> Void

    var subtotal: Double { table.items.reduce(0) { $0 + ($1.price * Double($1.qty)) } }
    var tax: Double { subtotal * 0.148 }
    var total: Double { subtotal + tax }
    let bg = Color(red: 0.11, green: 0.16, blue: 0.22)
    
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
            HStack {
                Button(action: close) { Image(systemName: "chevron.left").font(.title2).foregroundColor(.white) }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) { Image(systemName: "person.2.fill"); Text("\(table.guests) guests") }.foregroundColor(.white.opacity(0.9)).font(.system(size: 15))
                    HStack(spacing: 6) { Image(systemName: "person.fill"); Text(serverName) }.foregroundColor(.white.opacity(0.85)).font(.system(size: 15))
                }
                Spacer()
                Text("Table \(table.tableNumber)").foregroundColor(.white).font(.system(size: 20, weight: .bold))
            }
            .padding(.horizontal).padding(.vertical, 12)

            Divider().background(Color.white.opacity(0.3))

            ScrollView {
                VStack(spacing: 20) {
                    let courses = Array(Set(table.items.map { $0.course })).sorted()
                    
                    ForEach(courses, id: \.self) { course in
                        let courseItems = table.items.filter { $0.course == course }
                        let unfiredCount = courseItems.filter { !$0.isFired }.count
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(courseName(for: course))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.orange)
                                Spacer()
                                
                                if unfiredCount > 0 {
                                    Button(action: { fireCourseAction(course) }) {
                                        Text("Fire \(courseName(for: course))")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.red)
                                            .cornerRadius(8)
                                    }
                                } else {
                                    Text("FIRED")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.green)
                                }
                            }
                            
                            ForEach(courseItems.grouped(), id: \.item.id) { grouped in
                                OrderItemRow(item: grouped.item, quantity: grouped.quantity, onDelete: { removeItem(grouped.item) })
                            }
                        }
                        .padding(.horizontal)
                        Divider().background(Color.white.opacity(0.3))
                    }
                }
                .padding(.top, 14)
            }
            .frame(maxHeight: 550)

            HStack(spacing: 24) {
                Button(action: { if table.guests > 0 { updateGuests(table.guests - 1) } }) { Image(systemName: "minus.circle.fill").font(.system(size: 40)).foregroundColor(.white) }
                Text("Guests: \(table.guests)").foregroundColor(.white).font(.system(size: 22, weight: .medium))
                Button(action: { updateGuests(table.guests + 1) }) { Image(systemName: "plus.circle.fill").font(.system(size: 40)).foregroundColor(.white) }
                Spacer()
            }
            .padding(.horizontal).padding(.top, 12).padding(.bottom, 18)

            VStack(spacing: 16) {
                posButton(title: "Add Items", icon: "square.grid.2x2.fill", color: Color.gray.opacity(0.35), action: addItemsAction)
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                HStack { Text("Subtotal:").font(.system(size: 20, weight: .medium)).foregroundColor(.white.opacity(0.85)); Spacer(); Text(String(format: "$%.2f", subtotal)).font(.system(size: 20, weight: .semibold)).foregroundColor(.white) }
                HStack { Text("Tax:").font(.system(size: 20, weight: .medium)).foregroundColor(.white.opacity(0.85)); Spacer(); Text(String(format: "$%.2f", tax)).font(.system(size: 20, weight: .semibold)).foregroundColor(.white) }
            }
            .padding(.horizontal).padding(.top, 12)

            Button(action: payAction) {
                Text("Pay \(String(format: "$%.2f", total))").font(.system(size: 22, weight: .bold)).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 60).background(Color.green).cornerRadius(16)
            }
            .padding(.horizontal).padding(.vertical, 16)
        }
        .background(bg)
        .cornerRadius(26)
        .shadow(radius: 20)
    }

    func posButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) { Image(systemName: icon); Text(title).font(.system(size: 20, weight: .semibold)) }.foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 55).background(color).cornerRadius(16)
        }
    }
}

// ===============================================================
// MARK: - TABLE GRAPHIC
// ===============================================================
// ✅ THIS IS THE STRUCT THAT WAS MISSING!
struct TableView: View {
    let label: String
    let shape: TableShape
    var color: Color = .gray
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            ZStack {
                switch shape {
                case .square: Rectangle().fill(color).frame(width: 110, height: 110).cornerRadius(12)
                case .circle: Circle().fill(color).frame(width: 130, height: 130)
                case .rectangle: Rectangle().fill(color).frame(width: 300, height: 75).cornerRadius(12)
                case .diamond: Rectangle().fill(color).frame(width: 100, height: 100).rotationEffect(.degrees(45))
                }
                Text(label).foregroundColor(.black).font(.system(size: 20, weight: .bold))
            }
        }
        .buttonStyle(.plain)
    }
}
