//
//  ChecklistView.swift
//  FlightMate
//
//  Displays flight checklists. UI to be designed.
//

import SwiftUI

/// Placeholder root view for the Checklist feature.
struct ChecklistView: View {
    @StateObject private var viewModel = ChecklistViewModel()

    var body: some View {
        Text("Checklist")
    }
}

#Preview {
    ChecklistView()
}
