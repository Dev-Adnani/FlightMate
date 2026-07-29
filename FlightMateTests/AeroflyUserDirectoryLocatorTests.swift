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
    var libraryURLs: [URL] = []
    var existingPaths: Set<String>

    func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        switch directory {
        case .applicationSupportDirectory: return applicationSupportURLs
        case .libraryDirectory: return libraryURLs
        default: return []
        }
    }

    func fileExists(atPath path: String) -> Bool {
        existingPaths.contains(path)
    }
}

struct AeroflyUserDirectoryLocatorTests {
    @Test func returnsSteamStyleDirectoryWhenItExists() {
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

    @Test func prefersDirectoryThatContainsMainMcf() {
        let appSupport = URL(fileURLWithPath: "/fake/Library/Application Support", isDirectory: true)
        let library = URL(fileURLWithPath: "/fake/Library", isDirectory: true)
        let steam = appSupport.appendingPathComponent("Aerofly FS 4", isDirectory: true)
        let mas = library.appendingPathComponent(
            "Containers/com.aerofly.aerofly-fs-4-mac/Data/Library/Application Support/Aerofly FS 4",
            isDirectory: true
        )
        let fileSystem = FakeFileSystemLocating(
            applicationSupportURLs: [appSupport],
            libraryURLs: [library],
            existingPaths: [
                steam.path,
                mas.path,
                mas.appendingPathComponent("main.mcf").path
            ]
        )
        let locator = MacOSAeroflyUserDirectoryLocator(
            fileSystem: fileSystem,
            modificationDate: { _ in Date(timeIntervalSince1970: 1) }
        )

        #expect(locator.locateUserDirectory() == mas)
    }
}
