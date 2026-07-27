//
//  TelemetryPacket.swift
//  FlightMate
//
//  Common interface implemented by every decodable telemetry packet type.
//

import Foundation

/// A single telemetry message that can be decoded from a raw UDP payload.
///
/// FlightMate receives loosely-typed, comma-separated ASCII packets from
/// Aerofly FS 4 (the same wire format ForeFlight/X-Plane use for external
/// telemetry). Each concrete packet type — `XGPSPacket`, `XATTPacket`, and
/// so on — knows only how to decode *itself*; dispatching between types is
/// handled entirely by `TelemetryPacketParser`, which has no type-specific
/// logic of its own.
///
/// ## Wire shape
/// Every supported packet looks like:
/// ```
/// <PREFIX><simulatorName>,<field1>,<field2>,...
/// ```
/// For example, in `XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2`:
/// - `PREFIX` is `"XGPS"`
/// - `simulatorName` is `"Aerofly FS 4"` (concatenated directly after the
///   prefix, with no separator)
/// - the remaining comma-separated values are this packet type's fields
///
/// ## Adding a new packet type
/// 1. Create a new `struct` that conforms to `TelemetryPacket`.
/// 2. Implement `wirePrefix` with the packet's identifying prefix.
/// 3. Implement `init?(simulatorName:fields:)` to parse the fields that
///    follow the prefix + simulator name token.
/// 4. Register the new type in `TelemetryPacketParser.knownTypes`.
///
/// No other code needs to change.
protocol TelemetryPacket {
    /// The literal prefix identifying this packet type on the wire, e.g.
    /// `"XGPS"`. Must be unique across every registered packet type.
    static var wirePrefix: String { get }

    /// Attempts to decode an instance from the fields that follow the
    /// prefix + simulator name token in the raw packet.
    ///
    /// For `XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2`, `simulatorName`
    /// is `"Aerofly FS 4"` and `fields` is
    /// `["72.8754", "19.0818", "11.0", "314.1", "0.2"]`.
    ///
    /// - Returns: A decoded instance, or `nil` if `fields` does not match
    ///   this packet type's expected shape (wrong count, non-numeric value,
    ///   etc). A malformed packet is never treated as a fatal error.
    init?(simulatorName: String, fields: [Substring])
}
