//
//  AdminSettings.swift
//  
//
//

import Foundation

import SwiftUI

struct AdminSettingsView: View {

    struct UserPermission: Identifiable {
        let id = UUID()
        var name: String
        var isServer: Bool
        var isKitchen: Bool
        var isAdmin: Bool
    }

    @State private var users: [UserPermission] = [
        .init(name: "Brandon Johnson", isServer: false, isKitchen: true,  isAdmin: false),
        .init(name: "Zooey Easten",     isServer: false, isKitchen: false, isAdmin: true),
        .init(name: "Franny Lyle",      isServer: true,  isKitchen: false, isAdmin: false),
        .init(name: "William Henry",    isServer: true,  isKitchen: false, isAdmin: false),
        .init(name: "Hayden Prior",     isServer: false, isKitchen: false, isAdmin: true),
        .init(name: "Lindsey Tessa",    isServer: true,  isKitchen: false, isAdmin: false),
        .init(name: "John Patrick",     isServer: false, isKitchen: true,  isAdmin: false),
        .init(name: "Stephen Smith",    isServer: false, isKitchen: true,  isAdmin: false)
    ]

    var body: some View {
        ZStack {
            Color(red: 0.0078, green: 0.188, blue: 0.278)
                .edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading, spacing: 20) {

                // Header
                Text("Administrator Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal)

                // Search bar (UI only)
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.6))
                    Text("Search")
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                }
                .padding()
                .background(Color.white.opacity(0.15))
                .cornerRadius(12)
                .padding(.horizontal)

                // Column Headers
                HStack {
                    Text("Users")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Server")
                        .frame(width: 90)
                    Text("Kitchen")
                        .frame(width: 90)
                    Text("Admin")
                        .frame(width: 90)
                    Spacer().frame(width: 40)
                }
                .foregroundColor(.white)
                .font(.headline)
                .padding(.horizontal)

                // User Rows
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach($users) { $user in
                            HStack {
                                Text(user.name)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Toggle("", isOn: $user.isServer)
                                    .labelsHidden()
                                    .toggleStyle(.checkbox)
                                    .frame(width: 90)

                                Toggle("", isOn: $user.isKitchen)
                                    .labelsHidden()
                                    .toggleStyle(.checkbox)
                                    .frame(width: 90)

                                Toggle("", isOn: $user.isAdmin)
                                    .labelsHidden()
                                    .toggleStyle(.checkbox)
                                    .frame(width: 90)

                                Image(systemName: "ellipsis")
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 40)
                            }
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.top)
        }
    }
}

#Preview {
    AdminSettingsView()
}

