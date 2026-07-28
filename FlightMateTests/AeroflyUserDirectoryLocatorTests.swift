//
//  AeroflyUserDirectoryLocatorTests.swift
//  FlightMateTests
//
//  Exercises MacOSAeroflyUserDirectoryLocator via an injected
//  FileSystemLocating fake — never touches real disk paths.
//

import Foundation
import Testing
@testable import FlightMate

private struct FakeFileSystemLocating: FileSystemLocating {
    var applicationSupportURLs: [URL]
    var existingPaths: Set<String>

    func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        guard directory == .applicationSupportDirectory else { return [] }
        return applicationSupportURLs
    }

    func fileExists(atPath path: String) -> Bool {
        existingPaths.contains(path)
    }
}

struct AeroflyUserDirectoryLocatorTests {
    @Test func returnsDirectoryWhenItExists() {
        let appSupport = URL(fileURLWithPath: "/fake/Library/Application Support", isDirectory: true)
        let expected = appSupport.appendingPathComponent("Aerofly FS 4", isDirectory: true)
        let fileSystem = FakeFileSystemLocating(
            applicationSupportURLs: [appSupport],
            existingPaths: [expected.path]
        )

        let locator = MacOSAeroflyUserDirectoryLocator(fileSystem: fileSystem)
        #expect(locator.locateUserDirectory() == expected)
    }

    @Test func returnsNilWhenDirectoryDoesNotExist() {
        let appSupport = URL(fileURLWithPath: "/fake/Library/Application Support", isDirectory: true)
        let fileSystem = FakeFileSystemLocating(applicationSupportURLs: [appSupport], existingPaths: [])

        let locator = MacOSAeroflyUserDirectoryLocator(fileSystem: fileSystem)
        #expect(locator.locateUserDirectory() == nil)
    }

    @Test func returnsNilWhenApplicationSupportItselfIsUnavailable() {
        let fileSystem = FakeFileSystemLocating(applicationSupportURLs: [], existingPaths: [])
        let locator = MacOSAeroflyUserDirectoryLocator(fileSystem: fileSystem)
        #expect(locator.locateUserDirectory() == nil)
    }
}
