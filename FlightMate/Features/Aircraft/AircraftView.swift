//
//  AircraftView.swift
//  FlightMate
//
//  Displays aircraft reference information. UI to be designed.
//

import SwiftUI

/// Placeholder root view for the Aircraft feature.
struct AircraftView: View {
    @StateObject private var viewModel = AircraftViewModel()

    var body: some View {
        Text("Aircraft")
            .navigationTitle("Aircraft")
    }
}

#Preview {
    AircraftView()
}
