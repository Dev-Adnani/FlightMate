//
//  TelemetryPacketParser.swift
//  FlightMate
//
//  Decodes raw UDP payloads into strongly typed telemetry packets.
//

import Foundation
import OSLog

/// Decodes raw telemetry payloads (as received by `UDPListener`) into
/// strongly typed `TelemetryPacket` values.
///
/// The parser has no knowledge of any specific packet's fields — it only
/// knows how to split the wire format into a prefix, a simulator name, and
/// a list of fields, then hand those pieces to whichever registered
/// `TelemetryPacket` type claims the prefix. See `TelemetryPacket` for how
/// to add support for a new packet type.
///
/// Unknown packet types and malformed payloads are never treated as errors:
/// they are logged and skipped, so a single bad or unrecognized datagram
/// never interrupts the telemetry stream.
enum TelemetryPacketParser {

    /// Every packet type this parser currently understands. This is the
    /// only place that needs to change to support a new packet type —
    /// `parse` itself never needs to be touched.
    private static let knownTypes: [TelemetryPacket.Type] = [
        XGPSPacket.self,
        XATTPacket.self,
    ]

    /// Decodes a raw UDP payload into a strongly typed packet.
    ///
    /// - Parameter data: The raw bytes received from the network, expected
    ///   to be ASCII/UTF-8 text.
    /// - Returns: A decoded packet, or `nil` if the payload isn't valid
    ///   text, its type isn't recognized, or its fields don't match the
    ///   recognized type's expected shape.
    static func parse(_ data: Data) -> (any TelemetryPacket)? {
        guard let text = String(data: data, encoding: .utf8) else {
            AppLogger.telemetry.warning("Ignoring UDP packet: not valid UTF-8 text (\(data.count) bytes).")
            return nil
        }
        return parse(text)
    }

    /// Decodes an already-decoded text payload into a strongly typed packet.
    ///
    /// Exposed separately from `parse(_:Data)` so unit tests can exercise
    /// the parsing logic directly with plain strings.
    ///
    /// - Returns: A decoded packet, or `nil` if the text is empty, its type
    ///   isn't recognized, or its fields don't match the recognized type's
    ///   expected shape.
    static func parse(_ text: String) -> (any TelemetryPacket)? {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = line.split(separator: ",", omittingEmptySubsequences: false)

        guard let firstField = components.first else {
            AppLogger.telemetry.warning("Ignoring empty telemetry packet.")
            return nil
        }

        guard let matchedType = knownTypes.first(where: { firstField.hasPrefix($0.wirePrefix) }) else {
            AppLogger.telemetry.warning("Ignoring unknown telemetry packet type: \"\(firstField, privacy: .public)\"")
            return nil
        }

        let simulatorName = String(firstField.dropFirst(matchedType.wirePrefix.count))
        let remainingFields = Array(components.dropFirst())

        guard let packet = matchedType.init(simulatorName: simulatorName, fields: remainingFields) else {
            AppLogger.telemetry.error("Failed to parse \(matchedType.wirePrefix, privacy: .public) packet: \"\(line, privacy: .public)\"")
            return nil
        }

        return packet
    }
}
