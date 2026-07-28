//
//  ContentView.swift
//  FlightMate
//
//  Created by Dev Adnani on 27/07/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    let telemetryService: TelemetryService
    let flightContextEngine: FlightContextEngine

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar {
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            DashboardView(telemetryService: telemetryService, flightContextEngine: flightContextEngine)
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    let telemetryService = TelemetryService()
    ContentView(
        telemetryService: telemetryService,
        flightContextEngine: FlightContextEngine(
            telemetryService: telemetryService,
            aeroflySessionService: AeroflySessionService()
        )
    )
    .modelContainer(for: Item.self, inMemory: true)
}
