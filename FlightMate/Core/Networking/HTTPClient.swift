//
//  HTTPClient.swift
//  FlightMate
//
//  Thin protocol-oriented HTTP GET seam for external APIs (AWC, SimBrief).
//  Constructor-injected so services stay unit-testable with a fake client.
//

import Foundation

enum HTTPClientError: Error, LocalizedError, Equatable {
    case invalidURL
    case badStatus(Int)
    case emptyBody
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL."
        case .badStatus(let code): return "HTTP status \(code)."
        case .emptyBody: return "Empty response body."
        case .decodingFailed(let detail): return "Decoding failed: \(detail)"
        }
    }
}

protocol HTTPClient: Sendable {
    func get(url: URL) async throws -> Data
}

struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    private let timeout: TimeInterval

    init(session: URLSession = .shared, timeout: TimeInterval = 15) {
        self.session = session
        self.timeout = timeout
    }

    func get(url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HTTPClientError.emptyBody
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw HTTPClientError.badStatus(http.statusCode)
        }
        guard !data.isEmpty else { throw HTTPClientError.emptyBody }
        return data
    }
}
