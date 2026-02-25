//
//  TableModels.swift
//

import Foundation
import FirebaseFirestore
import Combine

// ===============================================================
// MARK: - MENU ITEM
// ===============================================================

struct MenuItem: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    let name: String
    let price: Double
    var qty: Int
    var notes: String
    
    // ✅ NEW: Pacing tracking
    var course: Int
    var isFired: Bool

    init(id: String = UUID().uuidString,
         name: String,
         price: Double,
         qty: Int = 1,
         notes: String = "",
         course: Int = 1,
         isFired: Bool = false) {

        self.id = id
        self.name = name
        self.price = price
        self.qty = qty
        self.notes = notes
        self.course = course
        self.isFired = isFired
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
