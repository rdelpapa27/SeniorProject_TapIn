//
//  TableViewRoom.swift
//
//  Integrated with clickable tables + sliding side panel
//

import SwiftUI

// Data Models
struct TableInfo: Identifiable {
    let id = UUID()
    let tableNumber: String
    let guests: Int
    let items: [MenuItem]
}

struct MenuItem: Identifiable {
    let id = UUID()
    let name: String
    let price: Double
}

struct TableViewRoom: View {

    // Side panel state
    @State private var selectedTable: TableInfo? = nil
    @State private var showPanel = false

    // Table data for all 16 tables (sample data, modify as needed)
    let tableData: [String: TableInfo] = [
        "T1": TableInfo(tableNumber: "T1", guests: 2, items: [
            MenuItem(name: "Sprite", price: 3.00),
            MenuItem(name: "Chicken Wrap", price: 9.50)
        ]),
        "T2": TableInfo(tableNumber: "T2", guests: 3, items: [
            MenuItem(name: "Iced Tea", price: 2.80),
            MenuItem(name: "Burger", price: 11.99)
        ]),
        "T3": TableInfo(tableNumber: "T3", guests: 1, items: [
            MenuItem(name: "Coffee", price: 2.50)
        ]),
        "T4": TableInfo(tableNumber: "T4", guests: 4, items: [
            MenuItem(name: "Wings", price: 14.99),
            MenuItem(name: "Beer Pitcher", price: 18.00)
        ]),
        "T5": TableInfo(tableNumber: "T5", guests: 2, items: [
            MenuItem(name: "Diet Coke", price: 3.70),
            MenuItem(name: "Cheese Burger", price: 30.50),
            MenuItem(name: "Fish Tacos", price: 22.40)
        ]),
        "T6": TableInfo(tableNumber: "T6", guests: 2, items: [
            MenuItem(name: "Chips & Salsa", price: 6.50)
        ]),
        "T7": TableInfo(tableNumber: "T7", guests: 5, items: [
            MenuItem(name: "Nachos", price: 12.99),
            MenuItem(name: "Margarita", price: 9.99)
        ]),
        "T8": TableInfo(tableNumber: "T8", guests: 3, items: [
            MenuItem(name: "Lemonade", price: 3.20)
        ]),
        "T9": TableInfo(tableNumber: "T9", guests: 4, items: [
            MenuItem(name: "Pizza", price: 15.00)
        ]),
        "T10": TableInfo(tableNumber: "T10", guests: 6, items: [
            MenuItem(name: "Fries", price: 4.99),
            MenuItem(name: "Burgers", price: 23.50)
        ]),
        "T11": TableInfo(tableNumber: "T11", guests: 1, items: [
            MenuItem(name: "Water", price: 0.00)
        ]),
        "T12": TableInfo(tableNumber: "T12", guests: 2, items: [
            MenuItem(name: "Salad", price: 9.00)
        ]),
        "T13": TableInfo(tableNumber: "T13", guests: 3, items: [
            MenuItem(name: "Beer", price: 7.50)
        ]),
        "T14": TableInfo(tableNumber: "T14", guests: 4, items: [
            MenuItem(name: "Pasta", price: 13.00)
        ]),
        "T15": TableInfo(tableNumber: "T15", guests: 2, items: [
            MenuItem(name: "Quesadilla", price: 8.50)
        ]),
        "T16": TableInfo(tableNumber: "T16", guests: 3, items: [
            MenuItem(name: "Waffles", price: 10.00)
        ])
    ]

    var body: some View {
        ZStack(alignment: .leading) {

            // Background & Layout
            Color(red: 0.0078, green: 0.188, blue: 0.278)
                .ignoresSafeArea()
                            
            RoundedRectangle(cornerRadius: 84)
                .fill(Color(red: 0.984, green: 0.522, blue: 0.000))
                .frame(width: 546.88, height: 390.5)
                .rotationEffect(.degrees(16.5))
                .offset(x: 500, y: -600)
            
            VStack {
                HStack {
                    Button(action: {}) {
                        Image(systemName: "chevron.left")
                            .font(.title)
                            .foregroundColor(.white)
                    }
            
                    Spacer()
                    Text("Main Room")
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
        
                    Button(action: {}) {
                        Image(systemName: "chevron.right")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                
                Text("Table View")
                    .font(.system(size: 40, weight: .medium, design: .rounded))
                    .foregroundColor(.white)

                ZStack {
                    Color.gray.opacity(0.5)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemBlue), lineWidth: 4))
                        .padding(.horizontal)

                    GeometryReader { geometry in
                        let width = geometry.size.width
                        let height = geometry.size.height
                        
                        Group {
                            tableButton("T1", .square, width * 0.10, height * 0.15)
                            tableButton("T2", .circle, width * 0.26, height * 0.15)
                            tableButton("T3", .circle, width * 0.46, height * 0.15)
                            tableButton("T4", .rectangle, width * 0.70, height * 0.15)
                            tableButton("T5", .circle, width * 0.90, height * 0.33, .yellow)
                            tableButton("T6", .circle, width * 0.90, height * 0.58)
                            tableButton("T7", .diamond, width * 0.90, height * 0.85)
                            tableButton("T8", .circle, width * 0.70, height * 0.85)
                            tableButton("T9", .circle, width * 0.50, height * 0.85)
                            tableButton("T10", .rectangle, width * 0.20, height * 0.86)
                            tableButton("T11", .diamond, width * 0.10, height * 0.52)
                            tableButton("T12", .diamond, width * 0.30, height * 0.50)
                            tableButton("T13", .diamond, width * 0.39, height * 0.65, .yellow)
                            tableButton("T14", .diamond, width * 0.39, height * 0.35)
                            tableButton("T15", .diamond, width * 0.48, height * 0.50)
                            tableButton("T16", .square, width * 0.70, height * 0.50)
                        }
                    }
                }
                .frame(height: 600)
                .padding()
            }

            // SIDE PANEL
            if showPanel, let table = selectedTable {
                SidePanel(table: table, close: {
                    showPanel = false
                })
                .frame(width: 330) // MEDIUM SIZE
                .transition(.move(edge: .leading))
                .animation(.easeInOut, value: showPanel)
            }
        }
    }

    // Helper — creates a clickable table
    func tableButton(_ label: String,
                     _ shape: TableShape,
                     _ x: CGFloat,
                     _ y: CGFloat,
                     _ color: Color = .gray) -> some View {
        
        TableView(label: label, shape: shape, color: color) {
            if let info = tableData[label] {
                selectedTable = info
                showPanel = true
            }
        }
        .position(x: x, y: y)
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
                    Rectangle().fill(color).frame(width: 110, height: 110)
                case .circle:
                    Circle().fill(color).frame(width: 130, height: 130)
                case .rectangle:
                    Rectangle().fill(color).frame(width: 300, height: 75)
                case .diamond:
                    Rectangle().fill(color)
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(45))
                }
                Text(label).foregroundColor(.black).bold()
            }
        }.buttonStyle(.plain)
    }
}

// SIDE PANEL VIEW
struct SidePanel: View {
    let table: TableInfo
    let close: () -> Void

    var subtotal: Double {
        table.items.reduce(0) { $0 + $1.price }
    }
    
    var tax: Double { subtotal * 0.148 }

    var body: some View {
        VStack(alignment: .leading) {
            
            // Close
            HStack {
                Button(action: close) {
                    Image(systemName: "chevron.left")
                        .font(.title)
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .padding()

            // Header
            HStack {
                Image(systemName: "person.2.fill")
                Text("\(table.guests) guests")
                Spacer()
                Text("Table \(table.tableNumber)")
            }
            .foregroundColor(.white)
            .font(.headline)
            .padding(.horizontal)

            // Orders
            ScrollView {
                ForEach(table.items) { item in
                    HStack {
                        Text(item.name)
                        Spacer()
                        Text(String(format: "$%.2f", item.price))
                    }
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }

            Spacer()

            // Totals
            VStack(alignment: .leading) {
                HStack {
                    Text("Subtotal:")
                    Spacer()
                    Text(String(format: "$%.2f", subtotal))
                }
                HStack {
                    Text("Tax:")
                    Spacer()
                    Text(String(format: "$%.2f", tax))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal)

            // Pay Button
            Button(action: {}) {
                Text("Pay \(String(format: "$%.2f", subtotal + tax))")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()

        }
        .background(Color(red: 0.0078, green: 0.188, blue: 0.278))
        .cornerRadius(20)
        .shadow(radius: 20)
    }
}

#Preview {
    TableViewRoom()
}

