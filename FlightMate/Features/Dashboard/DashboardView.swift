//
//  DashboardView.swift
//  FlightMate
//
//  Primary at-a-glance view of the current flight. UI to be designed.
//

import SwiftUI

/// Placeholder root view for the Dashboard feature.
struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        Text("Dashboard")
    }
}

#Preview {
    DashboardView()
}
