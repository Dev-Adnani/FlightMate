//
//  AeroflyUserDirectoryLocating.swift
//  FlightMate
//
//  Locates the directory Aerofly stores per-user session files in
//  (main.mcf, tm.log, gc-map.mcf, ...). Kept behind a protocol so the exact
//  resolution strategy can vary per platform without any caller needing to
//  know a hardcoded path.
//

import Foundation

/// Resolves the directory Aerofly FS 4 stores user session/configuration
/// files in, without hardcoding an absolute path anywhere.
protocol AeroflyUserDirectoryLocating {
    /// - Returns: The user's Aerofly directory, or `nil` if it cannot be
    ///   found on this system (e.g. Aerofly has never been run).
    func locateUserDirectory() -> URL?
}

/// Minimal seam over the two `FileManager` calls this locator needs, so
/// tests can supply a fake filesystem instead of touching real disk paths.
protocol FileSystemLocating {
    func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL]
    func fileExists(atPath path: String) -> Bool
}

extension FileManager: FileSystemLocating {}

/// macOS implementation. Aerofly FS 4 for macOS stores per-user session
/// files in `~/Library/Application Support/Aerofly FS 4/`, resolved via
/// `FileManager` rather than a literal string.
struct MacOSAeroflyUserDirectoryLocator: AeroflyUserDirectoryLocating {
    private static let directoryName = "Aerofly FS 4"

    private let fileSystem: FileSystemLocating

    init(fileSystem: FileSystemLocating = FileManager.default) {
        self.fileSystem = fileSystem
    }

    func locateUserDirectory() -> URL? {
        guard let applicationSupport = fileSystem.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let candidate = applicationSupport.appendingPathComponent(Self.directoryName, isDirectory: true)
        return fileSystem.fileExists(atPath: candidate.path) ? candidate : nil
    }
}
