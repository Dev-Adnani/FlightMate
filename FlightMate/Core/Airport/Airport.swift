//
//  Airport.swift
//  FlightMate
//
//  Domain model describing an airport relevant to the current flight
//  (departure, destination, or nearby diversion).
//

import Foundation

/// Represents an airport known to Aerofly FS 4.
///
/// Decodes directly from a single GeoJSON `Feature` in the bundled
/// `airports.geojson` resource (sourced verbatim from fboes/aerofly-data's
/// `data/airports.geojson`). That file is the most complete airport list
/// available from the source repo — see `Resources/Airports/Airports.md`
/// for why it was chosen over the smaller coordinate-only files.
///
/// `runways` is not present in that source and defaults to empty — see
/// `Runway` for details.
struct Airport: Equatable, Hashable, Codable, Identifiable {
    /// ICAO identifier, e.g. "KSFO". Used as the stable identity.
    let icaoCode: String

    /// Human-readable airport name, e.g. "San Francisco International Airport".
    let name: String

    let latitude: Double
    let longitude: Double

    /// Field elevation, in feet, when known.
    let elevationFt: Double?

    /// Nearest municipality/town, when known.
    let municipality: String?

    /// Airfield classification (large/medium/small airport, heliport, etc.),
    /// when the source's `type` value is recognized.
    let category: AirportCategory?

    /// Known runways. Empty when the underlying data source has no
    /// runway-level detail (currently always the case — see `Runway`).
    let runways: [Runway]

    var id: String { icaoCode }

    var coordinate: GeoCoordinate {
        GeoCoordinate(latitude: latitude, longitude: longitude)
    }

    init(
        icaoCode: String,
        name: String,
        latitude: Double,
        longitude: Double,
        elevationFt: Double? = nil,
        municipality: String? = nil,
        category: AirportCategory? = nil,
        runways: [Runway] = []
    ) {
        self.icaoCode = icaoCode
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.elevationFt = elevationFt
        self.municipality = municipality
        self.category = category
        self.runways = runways
    }

    // MARK: GeoJSON Feature decoding

    private enum FeatureKeys: String, CodingKey {
        case geometry
        case properties
    }

    private enum GeometryKeys: String, CodingKey {
        case coordinates
    }

    private enum PropertyKeys: String, CodingKey {
        case title
        case description
        case type
        case elevation
        case municipality
    }

    init(from decoder: Decoder) throws {
        let feature = try decoder.container(keyedBy: FeatureKeys.self)
        let geometry = try feature.nestedContainer(keyedBy: GeometryKeys.self, forKey: .geometry)
        let properties = try feature.nestedContainer(keyedBy: PropertyKeys.self, forKey: .properties)

        // GeoJSON coordinates are ordered [longitude, latitude, altitude?].
        let coordinates = try geometry.decode([Double].self, forKey: .coordinates)
        guard coordinates.count >= 2 else {
            throw DecodingError.dataCorruptedError(
                forKey: .coordinates,
                in: geometry,
                debugDescription: "Expected at least [longitude, latitude]."
            )
        }

        icaoCode = try properties.decode(String.self, forKey: .title)
        name = try properties.decode(String.self, forKey: .description)
        longitude = coordinates[0]
        latitude = coordinates[1]
        elevationFt = try properties.decodeIfPresent(Double.self, forKey: .elevation)
        municipality = try properties.decodeIfPresent(String.self, forKey: .municipality)

        let rawCategory = try properties.decodeIfPresent(String.self, forKey: .type)
        category = rawCategory.flatMap(AirportCategory.init(rawValue:))

        runways = []
    }

    func encode(to encoder: Encoder) throws {
        // Encoding isn't needed for the app's current use (read-only bundled
        // data), but is provided to keep `Codable` conformance symmetrical
        // for tests and any future caching. Encodes the flat shape, not
        // GeoJSON — this type is not round-trippable through GeoJSON.
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(icaoCode, forKey: .icaoCode)
        try container.encode(name, forKey: .name)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encodeIfPresent(elevationFt, forKey: .elevationFt)
        try container.encodeIfPresent(municipality, forKey: .municipality)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encode(runways, forKey: .runways)
    }

    private enum CodingKeys: String, CodingKey {
        case icaoCode, name, latitude, longitude, elevationFt, municipality, category, runways
    }
}
