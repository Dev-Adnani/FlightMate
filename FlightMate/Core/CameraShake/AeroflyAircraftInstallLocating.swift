//
//  AeroflyAircraftInstallLocating.swift
//  FlightMate
//
//  Finds the Aerofly FS 4 install `aircraft/` folder (Steam / common paths).
//

import Foundation

protocol AeroflyAircraftInstallLocating {
    /// Root `…/Aerofly FS 4 …/aircraft` directory, or nil if not found.
    func locateAircraftInstallDirectory() -> URL?
}

struct MacOSAeroflyAircraftInstallLocator: AeroflyAircraftInstallLocating {
    private let fileManager: FileManager
    private let homeDirectory: URL

    init(
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
    }

    func locateAircraftInstallDirectory() -> URL? {
        candidateAircraftRoots().first { fileManager.fileExists(atPath: $0.path) }
    }

    private func candidateAircraftRoots() -> [URL] {
        let steam = homeDirectory
            .appendingPathComponent("Library/Application Support/Steam/steamapps/common", isDirectory: true)
            .appendingPathComponent("Aerofly FS 4 Flight Simulator/aircraft", isDirectory: true)

        let applications = URL(fileURLWithPath: "/Applications/Aerofly FS 4.app/Contents/Resources/aircraft", isDirectory: true)

        return [steam, applications]
    }
}
