//
//  AeroflyPositionConverterTests.swift
//  FlightMateTests
//

import Testing
@testable import FlightMate

struct AeroflyPositionConverterTests {
    @Test func convertsRealPositionVectorNearVABB() throws {
        // The exact position vector from a real main.mcf spawned at VABB
        // (Mumbai, ~19.09°N 72.87°E) — a real-world sanity check.
        let vector = [1779406.9660508, 5760810.88028256, 2074061.68167588]
        let coordinate = try #require(AeroflyPositionConverter.coordinate(fromPosition: vector))

        #expect(abs(coordinate.latitude - 19.09) < 0.1)
        #expect(abs(coordinate.longitude - 72.87) < 0.1)
    }

    @Test func returnsNilForVectorWithWrongComponentCount() {
        #expect(AeroflyPositionConverter.coordinate(fromPosition: [1, 2]) == nil)
        #expect(AeroflyPositionConverter.coordinate(fromPosition: []) == nil)
        #expect(AeroflyPositionConverter.coordinate(fromPosition: [1, 2, 3, 4]) == nil)
    }

    @Test func handlesNegativeXWithPositiveY() throws {
        // x < 0 branch of the lambda calculation.
        let coordinate = try #require(AeroflyPositionConverter.coordinate(fromPosition: [-1_000_000, 500_000, 4_000_000]))
        #expect(coordinate.longitude > 90 && coordinate.longitude < 180)
    }

    @Test func handlesZeroX() throws {
        // x == 0 branches of the lambda calculation.
        let positive = try #require(AeroflyPositionConverter.coordinate(fromPosition: [0, 1_000_000, 4_000_000]))
        #expect(positive.longitude == 90)

        let negative = try #require(AeroflyPositionConverter.coordinate(fromPosition: [0, -1_000_000, 4_000_000]))
        #expect(negative.longitude == 270)
    }
}
