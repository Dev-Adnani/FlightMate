//
//  ChatView.swift
//  FlightMate
//
//  Conversational UI for the AI companion. UI to be designed.
//

import SwiftUI

/// Placeholder root view for the Chat feature.
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        Text("Chat")
    }
}

#Preview {
    ChatView()
}
