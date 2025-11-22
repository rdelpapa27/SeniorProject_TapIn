//
//  TableViewRoom.swift
//
//  Created by Bliss Jungo on 11/3/25.
//

import SwiftUI

struct TableViewRoom: View {
    @State private var selectedTable: String? = nil

    var body: some View {
        ZStack {
            Color(red: 0.0078, green: 0.188, blue: 0.278)
                .ignoresSafeArea()
                            
            RoundedRectangle(cornerRadius: 84)
                .fill(Color(red: 0.984, green: 0.522, blue: 0.000))
                .frame(width: 546.88, height: 390.5)
                .rotationEffect(.degrees(16.5))
                .offset(x: 500, y: -600)
            
            VStack {
                // Top Navigation Bar
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
                
                // Room Area
                ZStack {
                    Color.gray.opacity(0.5)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemBlue), lineWidth: 4))
                        .padding(.horizontal)

                    GeometryReader { geometry in
                        let width = geometry.size.width
                        let height = geometry.size.height
                        
                        Group {
                            TableView(label: "T1", shape: .square) {
                                selectedTable = "T1"
                            }
                            .position(x: width * 0.10, y: height * 0.15)

                            TableView(label: "T2", shape: .circle) {
                                selectedTable = "T2"
                            }
                            .position(x: width * 0.26, y: height * 0.15)

                            TableView(label: "T3", shape: .circle) {
                                selectedTable = "T3"
                            }
                            .position(x: width * 0.46, y: height * 0.15)

                            TableView(label: "T4", shape: .rectangle) {
                                selectedTable = "T4"
                            }
                            .position(x: width * 0.70, y: height * 0.15)

                            TableView(label: "T5", shape: .circle, color: .yellow) {
                                selectedTable = "T5"
                            }
                            .position(x: width * 0.9, y: height * 0.33)

                            TableView(label: "T6", shape: .circle) {
                                selectedTable = "T6"
                            }
                            .position(x: width * 0.9, y: height * 0.58)

                            TableView(label: "T7", shape: .diamond) {
                                selectedTable = "T7"
                            }
                            .position(x: width * 0.9, y: height * 0.85)

                            TableView(label: "T8", shape: .circle) {
                                selectedTable = "T8"
                            }
                            .position(x: width * 0.70, y: height * 0.85)

                            TableView(label: "T9", shape: .circle) {
                                selectedTable = "T9"
                            }
                            .position(x: width * 0.50, y: height * 0.85)

                            TableView(label: "T10", shape: .rectangle) {
                                selectedTable = "T10"
                            }
                            .position(x: width * 0.2, y: height * 0.86)

                            TableView(label: "T11", shape: .diamond) {
                                selectedTable = "T11"
                            }
                            .position(x: width * 0.1, y: height * 0.52)

                            TableView(label: "T12", shape: .diamond) {
                                selectedTable = "T12"
                            }
                            .position(x: width * 0.30, y: height * 0.5)

                            TableView(label: "T13", shape: .diamond, color: .yellow) {
                                selectedTable = "T13"
                            }
                            .position(x: width * 0.39, y: height * 0.65)

                            TableView(label: "T14", shape: .diamond) {
                                selectedTable = "T14"
                            }
                            .position(x: width * 0.39, y: height * 0.35)

                            TableView(label: "T15", shape: .diamond) {
                                selectedTable = "T15"
                            }
                            .position(x: width * 0.48, y: height * 0.5)

                            TableView(label: "T16", shape: .square) {
                                selectedTable = "T16"
                            }
                            .position(x: width * 0.70, y: height * 0.5)
                        }
                    }
                }
                .frame(height: 600)
                .padding()

                // Shows selected table (for testing)
                if let table = selectedTable {
                    Text("Selected: \(table)")
                        .foregroundColor(.white)
                        .font(.title)
                        .padding(.top, 10)
                }
            }
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
                case .circle:
                    Circle()
                        .fill(color)
                        .frame(width: 130, height: 130)
                case .rectangle:
                    Rectangle()
                        .fill(color)
                        .frame(width: 300, height: 75)
                case .diamond:
                    Rectangle()
                        .fill(color)
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(45))
                }
                Text(label)
                    .foregroundColor(.black)
                    .bold()
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TableViewRoom()
}
