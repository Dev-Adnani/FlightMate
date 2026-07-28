//
//  AirportView.swift
//  FlightMate
//
//  Displays airport information relevant to the current flight. UI to be designed.
//

import SwiftUI

/// Placeholder root view for the Airport feature.
struct AirportView: View {
    @StateObject private var viewModel = AirportViewModel()

    var body: some View {
        Text("Airport")
            .navigationTitle("Airports")
    }
}

#Preview {
    AirportView()
}
