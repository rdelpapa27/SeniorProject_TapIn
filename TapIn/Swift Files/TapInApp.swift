//
//  TapInApp.swift
//  TapIn
//

import SwiftUI
import Firebase
import FirebaseFirestore

@main
struct TapInApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool
    {
        FirebaseApp.configure()
        print("Firebase Configured.")

        // seedDatabase()   // RUN ONCE → Then comment out

        return true
    }
}

// MARK: - Seed Firestore Database
func seedDatabase() {
    let db = Firestore.firestore()

    let menuItems: [[String: Any]] = [

        // Breakfast
        ["name": "Honduran Breakfast", "price": 6.25, "category_id": "breakfast"],
        ["name": "Country-Style Breakfast", "price": 7.83, "category_id": "breakfast"],
        ["name": "Simple Baleada", "price": 1.33, "category_id": "breakfast"],
        ["name": "Baleada with Egg", "price": 1.46, "category_id": "breakfast"],
        ["name": "Baleada with Egg and Chorizo", "price": 1.63, "category_id": "breakfast"],
        ["name": "Baleada with Chicken or Pork", "price": 1.96, "category_id": "breakfast"],
        ["name": "Oatmeal", "price": 3.96, "category_id": "breakfast"],
        ["name": "Pancake", "price": 3.96, "category_id": "breakfast"],
        ["name": "Bread with Beans", "price": 2.50, "category_id": "breakfast"],
        ["name": "Spanish Omelette", "price": 6.67, "category_id": "breakfast"],

        // Tacos, Enchiladas, Plantains
        ["name": "Flauta Tacos", "price": 5.83, "category_id": "tacos"],
        ["name": "Enchiladas", "price": 3.96, "category_id": "tacos"],
        ["name": "Fried Plantains with Beef", "price": 3.96, "category_id": "tacos"],

        // Sandwiches & Burgers
        ["name": "Club Sandwich", "price": 6.46, "category_id": "sandwiches"],
        ["name": "Pamplona Sandwich", "price": 6.88, "category_id": "sandwiches"],
        ["name": "Cuban Sandwich", "price": 7.38, "category_id": "sandwiches"],
        ["name": "Regular Burger", "price": 6.88, "category_id": "sandwiches"],
        ["name": "Cheeseburger", "price": 7.17, "category_id": "sandwiches"],
        ["name": "Bacon Burger", "price": 7.46, "category_id": "sandwiches"],

        // Pastas & Rice
        ["name": "Spaghetti Bolognese", "price": 5.21, "category_id": "pasta"],
        ["name": "Spaghetti with Chicken", "price": 5.83, "category_id": "pasta"],
        ["name": "Spaghetti with Shrimp", "price": 7.08, "category_id": "pasta"],
        ["name": "Chicken Rice", "price": 5.83, "category_id": "pasta"],
        ["name": "Shrimp Rice", "price": 6.88, "category_id": "pasta"],

        // Chicken
        ["name": "Chicken with Plantains", "price": 6.46, "category_id": "chicken"],
        ["name": "Chicken with Fries", "price": 6.88, "category_id": "chicken"],
        ["name": "6 Chicken Fingers with Fries", "price": 7.29, "category_id": "chicken"],
        ["name": "6 Chicken Wings with Fries", "price": 7.29, "category_id": "chicken"],

        // Salads
        ["name": "Mixed Salad", "price": 4.17, "category_id": "salads"],
        ["name": "Lettuce and Tomato Salad", "price": 3.13, "category_id": "salads"],
        ["name": "Chicken Salad", "price": 4.58, "category_id": "salads"],

        // Meats & Seafood
        ["name": "Breaded Shrimp", "price": 7.92, "category_id": "meats"],
        ["name": "Fried Fish", "price": 8.13, "category_id": "meats"],
        ["name": "Grilled Pork Chop", "price": 7.29, "category_id": "meats"],
        ["name": "Onion Pork Chop", "price": 7.71, "category_id": "meats"],

        // Soups
        ["name": "Chicken Soup", "price": 6.88, "category_id": "soups"],
        ["name": "Conch Soup", "price": 11.67, "category_id": "soups"],

        // Drinks
        ["name": "Black Coffee", "price": 1.33, "category_id": "drinks"],
        ["name": "Mochaccino", "price": 2.50, "category_id": "drinks"],
        ["name": "Hot Chocolate", "price": 2.50, "category_id": "drinks"],
        ["name": "Natural Juice", "price": 2.38, "category_id": "drinks"],
        ["name": "Natural Juice with Milk", "price": 2.71, "category_id": "drinks"],
        ["name": "Soft Drinks", "price": 1.25, "category_id": "drinks"],
        ["name": "Cappuccino", "price": 1.96, "category_id": "drinks"],
        ["name": "Latte", "price": 1.54, "category_id": "drinks"],
        ["name": "Milk Coffee (Skim / Lactose-free)", "price": 2.50, "category_id": "drinks"],
        ["name": "Flavored Granita", "price": 2.42, "category_id": "drinks"],
        ["name": "Coffee Granita with Cream", "price": 2.71, "category_id": "drinks"],
        ["name": "Supreme Mochaccino", "price": 7.17, "category_id": "drinks"],
        ["name": "Sweet Bread", "price": 0.75, "category_id": "drinks"],
        ["name": "Hot Tea", "price": 2.50, "category_id": "drinks"],

        // Beer & Liquor
        ["name": "Domestic Beer", "price": 1.88, "category_id": "alcohol"],
        ["name": "Imported Beer", "price": 2.08, "category_id": "alcohol"],
        ["name": "Rum (Single Shot)", "price": 3.33, "category_id": "alcohol"],
        ["name": "Vodka (Single Shot)", "price": 3.75, "category_id": "alcohol"],
        ["name": "Gin (Single Shot)", "price": 3.96, "category_id": "alcohol"],
        ["name": "Whiskey (Single Shot)", "price": 4.38, "category_id": "alcohol"]
    ]

    for item in menuItems {
        db.collection("menu_items").addDocument(data: item)
    }

    print("Menu seeded successfully.")
}

