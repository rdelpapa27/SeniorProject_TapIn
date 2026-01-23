import SwiftUI

// MARK: - UI-Only Models (No Conflicts)

struct KitchenDashboardOrder: Identifiable {
    let id = UUID()
    let orderNumber: String
    let serverName: String
    let tableNumber: Int
    let items: [KitchenLineItem]
    let createdAt: Date
}

struct KitchenLineItem: Identifiable {
    let id = UUID()
    let quantity: Int
    let itemName: String
    let modifiers: [String]
}

// MARK: - Main View

struct KitchenDashboard: View {

    @State private var orders: [KitchenDashboardOrder] = SampleKitchenData.orders
    @State private var selectedOrderID: UUID?

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 16),
        count: 4
    )

    var body: some View {
        ZStack {

            Color.white.ignoresSafeArea()

            decorativeShapes

            VStack(spacing: 0) {

                header

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(orders, id: \.id) { order in
                            OrderCard(
                                order: order,
                                isSelected: selectedOrderID == order.id
                            )
                            .onTapGesture {
                                selectedOrderID = order.id
                            }
                        }
                    }
                    .padding()
                }

                footer
            }
        }
    }

    // MARK: - Header

    // MARK: - Header (Logout + Title)

    private var header: some View {
        HStack(spacing: 16) {

            // Logout Button
            Button(action: {
                // TODO: Hook into logout logic
                print("Logout tapped")
            }) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44) // proper tap size
            }

            // Restaurant Name
            Text("Restaurant Name")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(hex: "023047"))
    }


    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button("Ready") {
                // Mark order ready
            }
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(
                selectedOrderID == nil
                ? Color.gray
                : Color(hex: "023047")
            )
            .cornerRadius(10)
            .disabled(selectedOrderID == nil)
        }
        .padding()
        .background(Color(hex: "023047"))
    }

    // MARK: - Decorative Shapes

    private var decorativeShapes: some View {
        ZStack {
            // Top-left orange shape (73.33% opacity)
            RoundedRectangle(cornerRadius: 84)
                .fill(Color(red: 0.984, green: 0.522, blue: 0.000).opacity(0.7333))
                .frame(width: 649.91, height: 691.79)
                .rotationEffect(.degrees(55))
                .offset(x: -500, y: -400)
                
            // Bottom-right orange shape (100% opacity)
            RoundedRectangle(cornerRadius: 84)
                .fill(Color(red: 0.984, green: 0.522, blue: 0.000))
                .frame(width: 646.88, height: 490.5)
                .rotationEffect(.degrees(26))
                .offset(x: 600, y: 400)
        }
    }
}

// MARK: - Order Card View

struct OrderCard: View {

    let order: KitchenDashboardOrder
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0){
            
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.orderNumber)
                        .fontWeight(.bold)
                    Text("TABLE: \(order.tableNumber)")
                }

                Spacer()

                Text(order.serverName)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading) // ✅ MATCH WIDTH
            .foregroundColor(.white)
            .background(Color(hex: "FB8500"))

            // Order Details
            VStack(alignment: .leading, spacing: 8) {
                ForEach(order.items, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(item.quantity) x \(item.itemName)")
                            .fontWeight(.semibold)

                        ForEach(item.modifiers, id: \.self) {
                            Text($0)
                                .foregroundColor(.red)
                        }
                    }
                }

                Spacer()
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .topLeading) // ✅ MATCH WIDTH
            .background(Color(hex: "D9D9D9"))
        }
        .frame(minHeight: 420)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    isSelected ? Color(hex: "023047") : .clear,
                    lineWidth: 3
                )
        )
        .cornerRadius(6)

        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    isSelected ? Color(hex: "023047") : .clear,
                    lineWidth: 3
                )
        )
        .cornerRadius(6)
    }
}

// MARK: - Sample Data

enum SampleKitchenData {
    static let orders: [KitchenDashboardOrder] = [
        KitchenDashboardOrder(
            orderNumber: "#00038",
            serverName: "WILL H.",
            tableNumber: 2,
            items: [
                KitchenLineItem(
                    quantity: 1,
                    itemName: "Burger",
                    modifiers: [
                        "medium rare",
                        "American cheese",
                        "lettuce",
                        "no tomatoes"
                    ]
                )
            ],
            createdAt: Date()
        ),
        KitchenDashboardOrder(
            orderNumber: "#00042",
            serverName: "WILL H.",
            tableNumber: 5,
            items: [
                KitchenLineItem(
                    quantity: 1,
                    itemName: "Burger",
                    modifiers: [
                        "medium rare",
                        "American cheese",
                        "lettuce",
                        "no tomatoes"
                    ]
                )
            ],
            createdAt: Date()
        )
    ]
}

// MARK: - Color Helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        self.init(
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    KitchenDashboard()
}
