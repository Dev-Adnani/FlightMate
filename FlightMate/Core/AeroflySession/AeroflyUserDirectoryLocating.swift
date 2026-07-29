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

/// macOS implementation. Aerofly FS 4 stores per-user session files in
/// different places depending on distribution channel:
///
/// - Steam / direct: `~/Library/Application Support/Aerofly FS 4/`
/// - Mac App Store: `~/Library/Containers/com.aerofly.aerofly-fs-4-mac/Data/Library/Application Support/Aerofly FS 4/`
///
/// Prefer the most recently modified candidate when both exist (a leftover
/// empty Steam folder must not win over an active MAS install).
struct MacOSAeroflyUserDirectoryLocator: AeroflyUserDirectoryLocating {
    private static let directoryName = "Aerofly FS 4"
    private static let macAppStoreRelativePath =
        "Containers/com.aerofly.aerofly-fs-4-mac/Data/Library/Application Support/Aerofly FS 4"

    private let fileSystem: FileSystemLocating
    private let modificationDate: (URL) -> Date?

    init(
        fileSystem: FileSystemLocating = FileManager.default,
        modificationDate: @escaping (URL) -> Date? = { url in
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        }
    ) {
        self.fileSystem = fileSystem
        self.modificationDate = modificationDate
    }

    func locateUserDirectory() -> URL? {
        let candidates = candidateDirectories().filter {
            fileSystem.fileExists(atPath: $0.path)
        }
        guard !candidates.isEmpty else { return nil }

        // Prefer a directory that actually has main.mcf, then newest mtime.
        return candidates.max { lhs, rhs in
            let lhsHasMcf = fileSystem.fileExists(atPath: lhs.appendingPathComponent("main.mcf").path)
            let rhsHasMcf = fileSystem.fileExists(atPath: rhs.appendingPathComponent("main.mcf").path)
            if lhsHasMcf != rhsHasMcf { return !lhsHasMcf }
            let lhsDate = modificationDate(lhs) ?? .distantPast
            let rhsDate = modificationDate(rhs) ?? .distantPast
            return lhsDate < rhsDate
        }
    }

    private func candidateDirectories() -> [URL] {
        var urls: [URL] = []

        if let applicationSupport = fileSystem.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            urls.append(applicationSupport.appendingPathComponent(Self.directoryName, isDirectory: true))
        }

        if let library = fileSystem.urls(for: .libraryDirectory, in: .userDomainMask).first {
            urls.append(library.appendingPathComponent(Self.macAppStoreRelativePath, isDirectory: true))
        }

        return urls
    }
}
