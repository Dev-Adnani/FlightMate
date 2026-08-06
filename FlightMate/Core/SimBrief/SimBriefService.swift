//
//  SimBriefService.swift
//  FlightMate
//
//  Orchestrates SimBrief OFP fetch / PLN import and publishes the latest plan.
//

import Combine
import Foundation

protocol SimBriefProviding: AnyObject {
    var latestOFP: SimBriefOFP? { get }
    var lastErrorMessage: String? { get }
    func fetchLatestOFP() async
    func importPLN(from url: URL) async
}

@MainActor
final class SimBriefService: ObservableObject, SimBriefProviding {
    @Published private(set) var latestOFP: SimBriefOFP?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var isBusy = false

    private let client: SimBriefFetching
    private let preferences: SimBriefPreferenceProviding

    init(
        client: SimBriefFetching = SimBriefClient(),
        preferences: SimBriefPreferenceProviding
    ) {
        self.client = client
        self.preferences = preferences
    }

    func fetchLatestOFP() async {
        isBusy = true
        lastErrorMessage = nil
        defer { isBusy = false }
        do {
            latestOFP = try await client.fetchOFP(usernameOrUserID: preferences.username)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func importPLN(from url: URL) async {
        isBusy = true
        lastErrorMessage = nil
        defer { isBusy = false }
        do {
            let data = try Data(contentsOf: url)
            latestOFP = try SimBriefPLNImporter.importPLN(data: data)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
