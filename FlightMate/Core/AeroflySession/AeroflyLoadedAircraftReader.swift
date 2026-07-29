//
//  AeroflyLoadedAircraftReader.swift
//  FlightMate
//
//  Reads the aircraft Aerofly actually loaded this session from tm.log.
//  main.mcf can lag behind an in-sim aircraft change; tm.log records
//  `done loading model <aeroflyCode>` at load time and is the better
//  live identity signal when present.
//

import Foundation

/// Reads the Aerofly aircraft code last loaded by the simulator.
protocol AeroflyLoadedAircraftReading {
    /// - Parameter directory: The Aerofly user directory.
    /// - Returns: The Aerofly aircraft code (e.g. `"a320_neo"`), or `nil`
    ///   if `tm.log` is missing or has no recognizable load line.
    func readLoadedAircraft(in directory: URL) -> String?
}

/// Parses `tm.log` for the most recent successful model load.
///
/// Matches lines Aerofly writes when an aircraft finishes loading, e.g.:
/// `5.13-tmsimulator:             done loading model a320_neo`
///
/// Also accepts the earlier dynamics-begin form as a fallback:
/// `loading dynamics begin 'a320_neo'...`
struct TmLogAeroflyLoadedAircraftReader: AeroflyLoadedAircraftReading {
    private static let logFileName = "tm.log"
    private static let doneLoadingMarker = "done loading model "
    private static let dynamicsBeginMarker = "loading dynamics begin '"

    func readLoadedAircraft(in directory: URL) -> String? {
        let logURL = directory.appendingPathComponent(Self.logFileName)
        guard let contents = try? String(contentsOf: logURL, encoding: .utf8) else {
            return nil
        }
        return Self.extractLoadedAircraft(from: contents)
    }

    /// Pure parsing — last matching load wins (mid-session aircraft changes
    /// append new lines; we want the aircraft currently in use).
    static func extractLoadedAircraft(from logContents: String) -> String? {
        var lastCode: String?

        for line in logContents.split(whereSeparator: \.isNewline) {
            let text = String(line)
            if let code = codeAfterDoneLoading(in: text)
                ?? codeAfterDynamicsBegin(in: text) {
                lastCode = code
            }
        }

        return lastCode
    }

    private static func codeAfterDoneLoading(in line: String) -> String? {
        guard let range = line.range(of: doneLoadingMarker) else { return nil }
        let remainder = line[range.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitizeAircraftCode(remainder)
    }

    private static func codeAfterDynamicsBegin(in line: String) -> String? {
        guard let range = line.range(of: dynamicsBeginMarker) else { return nil }
        let afterQuote = line[range.upperBound...]
        guard let endQuote = afterQuote.firstIndex(of: "'") else { return nil }
        return sanitizeAircraftCode(String(afterQuote[..<endQuote]))
    }

    /// Aerofly codes are lowercase identifiers with underscores/digits.
    private static func sanitizeAircraftCode(_ raw: String) -> String? {
        let code = raw
            .prefix(while: { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return code.isEmpty ? nil : String(code)
    }
}
