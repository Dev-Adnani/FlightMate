//
//  AeroflyVersionReader.swift
//  FlightMate
//
//  Reads the running Aerofly FS 4 version out of tm.log — the only reliable
//  source found for it. main.mcf itself carries no application-version
//  field. Distribution channel (Steam/Mac App Store/direct) is NOT
//  detected: no reliable signal for it exists, and inventing one would
//  violate the "never invent simulator capabilities" rule.
//

import Foundation

/// Reads Aerofly's running version number from its session directory.
protocol AeroflyVersionReading {
    /// - Parameter directory: The Aerofly user directory (as resolved by
    ///   `AeroflyUserDirectoryLocating`).
    /// - Returns: The version string (e.g. `"4.08.04.01"`), or `nil` if it
    ///   cannot be read — never a guess.
    func readVersion(in directory: URL) -> String?
}

/// Reads `tm.log`, which Aerofly rewrites fresh on every launch and which
/// contains a single, stable line near the top of the form
/// `Program version 4.08.04.01`.
struct TmLogAeroflyVersionReader: AeroflyVersionReading {
    private static let logFileName = "tm.log"
    private static let marker = "Program version "

    func readVersion(in directory: URL) -> String? {
        let logURL = directory.appendingPathComponent(Self.logFileName)
        guard let contents = try? String(contentsOf: logURL, encoding: .utf8) else {
            return nil
        }
        return Self.extractVersion(from: contents)
    }

    /// Pure parsing logic, exposed separately so it's testable without
    /// touching disk.
    static func extractVersion(from logContents: String) -> String? {
        guard let markerRange = logContents.range(of: marker) else { return nil }
        let versionSubstring = logContents[markerRange.upperBound...].prefix { $0.isNumber || $0 == "." }
        return versionSubstring.isEmpty ? nil : String(versionSubstring)
    }
}
