//
//  TableViewModel.swift
//  TapIn
//

import Combine
import Foundation
import FirebaseFirestore

class TableViewModel: ObservableObject {

    @Published var tables: [TableInfo] = []

    private var listener: ListenerRegistration?

    init() {
        listenForTables()
    }

    // ===========================================================
    // MARK: - Live Table Listener
    // ===========================================================

    func listenForTables() {
        let db = Firestore.firestore()

        listener = db.collection("tables")
            .order(by: "tableNumber")
            .addSnapshotListener { snapshot, error in

                if let error = error {
                    print("Error loading tables:", error)
                    return
                }

                guard let documents = snapshot?.documents else { return }

                var loaded: [TableInfo] = []

                for doc in documents {
                    let data = doc.data()

                    let tableNumber = data["tableNumber"] as? String ?? "?"
                    let guests = data["guests"] as? Int ?? 0

                    let itemsArray = data["items"] as? [[String: Any]] ?? []
                    let items: [MenuItem] = itemsArray.compactMap { dict in
                        guard
                            let name = dict["name"] as? String,
                            let price = dict["price"] as? Double
                        else { return nil }

                        let qty = dict["qty"] as? Int ?? 1
                        let notes = dict["notes"] as? String ?? ""
                        
                        // ✅ NEW: Parsing the course tracking
                        let course = dict["course"] as? Int ?? 1
                        let isFired = dict["isFired"] as? Bool ?? false

                        return MenuItem(
                            name: name,
                            price: price,
                            qty: qty,
                            notes: notes,
                            course: course,
                            isFired: isFired
                        )
                    }

                    let table = TableInfo(
                        tableNumber: tableNumber,
                        guests: guests,
                        items: items
                    )

                    loaded.append(table)
                }

                DispatchQueue.main.async {
                    self.tables = loaded
                }
            }
    }

    func isOccupied(_ tableNumber: String) -> Bool {
        guard let table = tables.first(where: { $0.tableNumber == tableNumber }) else {
            return false
        }
        return table.items.contains(where: { $0.qty > 0 })
    }
}
