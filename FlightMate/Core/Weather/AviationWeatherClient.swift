//
//  AviationWeatherClient.swift
//  FlightMate
//
//  Aviation Weather Center METAR JSON API client.
//  Ported from fboes/aerofly-startgeraet AviationWeatherApi.
//

import Foundation

protocol METARFetching: Sendable {
    func fetchMETAR(icaoIds: [String]) async throws -> [METARObservation]
}

struct AviationWeatherClient: METARFetching, Sendable {
    private let http: HTTPClient
    private let baseURL: URL

    nonisolated init(
        http: HTTPClient = URLSessionHTTPClient(),
        baseURL: URL = URL(string: "https://aviationweather.gov")!
    ) {
        self.http = http
        self.baseURL = baseURL
    }

    nonisolated func fetchMETAR(icaoIds: [String]) async throws -> [METARObservation] {
        let ids = icaoIds.map { $0.uppercased() }.filter { !$0.isEmpty }
        guard !ids.isEmpty else { return [] }

        var components = URLComponents(url: baseURL.appendingPathComponent("api/data/metar"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "ids", value: ids.joined(separator: ",")),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components.url else { throw HTTPClientError.invalidURL }

        let data = try await http.get(url: url)
        let decoder = JSONDecoder()
        let payloads: [AWCMetarPayload]
        do {
            payloads = try decoder.decode([AWCMetarPayload].self, from: data)
        } catch {
            throw HTTPClientError.decodingFailed(error.localizedDescription)
        }
        return payloads.map { $0.toObservation() }
    }
}

// MARK: - AWC JSON

private struct AWCMetarPayload: Decodable {
    let icaoId: String
    let reportTime: String?
    let temp: Double?
    let dewp: Double?
    let wdir: WDir?
    let wspd: Double?
    let wgst: Double?
    let visib: Visib?
    let clouds: [AWCCloud]?
    let rawOb: String?

    enum WDir: Decodable {
        case degrees(Double)
        case variable

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let number = try? container.decode(Double.self) {
                self = .degrees(number)
            } else if let string = try? container.decode(String.self), string.uppercased() == "VRB" {
                self = .variable
            } else {
                self = .variable
            }
        }
    }

    enum Visib: Decodable {
        case miles(Double)
        case openEnded

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let number = try? container.decode(Double.self) {
                self = .miles(number)
            } else if let string = try? container.decode(String.self) {
                if string.contains("+") || string.uppercased() == "10+" {
                    self = .openEnded
                } else if let parsed = Double(string) {
                    self = .miles(parsed)
                } else {
                    self = .openEnded
                }
            } else {
                self = .openEnded
            }
        }

        var statuteMiles: Double {
            switch self {
            case .miles(let v): return v
            case .openEnded: return 10
            }
        }
    }

    struct AWCCloud: Decodable {
        let cover: String?
        let base: Double?
    }

    func toObservation() -> METARObservation {
        let windDir: Double?
        switch wdir {
        case .degrees(let d): windDir = d
        case .variable, .none: windDir = nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var report: Date?
        if let reportTime {
            report = formatter.date(from: reportTime)
                ?? ISO8601DateFormatter().date(from: reportTime)
        }

        let layers = (clouds ?? []).map { cloud in
            let cover = cloud.cover ?? "CLR"
            let normalized = (cover == "CAVOK" || cover == "SKC") ? "CLR" : cover
            return METARCloudLayer(coverCode: normalized, baseFeetAGL: cloud.base)
        }

        return METARObservation(
            icaoId: icaoId,
            reportTime: report,
            temperatureCelsius: temp,
            dewpointCelsius: dewp,
            windDirectionDegrees: windDir,
            windSpeedKnots: wspd ?? 0,
            windGustKnots: wgst,
            visibilityStatuteMiles: visib?.statuteMiles ?? 10,
            clouds: layers,
            rawText: rawOb
        )
    }
}
