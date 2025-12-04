//
//  TableModels.swift
//

import Foundation
import FirebaseFirestore

// ===============================================================
// MARK: - MENU ITEM (Supports quantity + notes)
// ===============================================================

struct MenuItem: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    let name: String
    let price: Double
    var qty: Int                // NEW — supports multiple identical items
    var notes: String           // NEW — supports POS notes ("no salt", etc.)

    init(id: String = UUID().uuidString,
         name: String,
         price: Double,
         qty: Int = 1,
         notes: String = "") {

        self.id = id
        self.name = name
        self.price = price
        self.qty = qty
        self.notes = notes
    }
}

// ===============================================================
// MARK: - TABLE INFORMATION
// ===============================================================

struct TableInfo: Identifiable, Codable {
    var id: String = UUID().uuidString
    let tableNumber: String
    let guests: Int
    let items: [MenuItem]
}


