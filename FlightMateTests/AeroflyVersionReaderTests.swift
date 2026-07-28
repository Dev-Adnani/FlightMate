//
//  AeroflyVersionReaderTests.swift
//  FlightMateTests
//

import Foundation
import Testing
@testable import FlightMate

struct AeroflyVersionReaderTests {
    @Test func extractsVersionFromRealShapedLogContents() {
        let version = TmLogAeroflyVersionReader.extractVersion(from: AeroflySessionFixtures.tmLogWithVersion)
        #expect(version == "4.08.04.01")
    }

    @Test func returnsNilWhenLineIsMissing() {
        let version = TmLogAeroflyVersionReader.extractVersion(from: AeroflySessionFixtures.tmLogWithoutVersion)
        #expect(version == nil)
    }

    @Test func returnsNilForEmptyContents() {
        #expect(TmLogAeroflyVersionReader.extractVersion(from: "") == nil)
    }

    @Test func readVersionReturnsNilWhenFileDoesNotExist() {
        let reader = TmLogAeroflyVersionReader()
        let missingDirectory = URL(fileURLWithPath: "/tmp/FlightMateTests-nonexistent-\(UUID().uuidString)", isDirectory: true)
        #expect(reader.readVersion(in: missingDirectory) == nil)
    }

    @Test func readVersionReadsFromRealTemporaryFile() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("FlightMateTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let logURL = directory.appendingPathComponent("tm.log")
        try AeroflySessionFixtures.tmLogWithVersion.write(to: logURL, atomically: true, encoding: .utf8)

        let reader = TmLogAeroflyVersionReader()
        #expect(reader.readVersion(in: directory) == "4.08.04.01")
    }
}
