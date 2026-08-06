//
//  AeroflyMcfWriter.swift
//  FlightMate
//
//  Loads main.mcf, applies weather/route patches, backs up, and writes atomically.
//  Aerofly must be quit — settings apply on next launch (Startgerät model).
//

import Foundation

enum AeroflyMcfWriterError: Error, LocalizedError, Equatable {
    case userDirectoryNotFound
    case mainMcfMissing
    case unexpectedStructure(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .userDirectoryNotFound: return "Aerofly user directory not found."
        case .mainMcfMissing: return "main.mcf not found."
        case .unexpectedStructure(let detail): return "Unexpected main.mcf structure: \(detail)"
        case .writeFailed(let detail): return "Failed to write main.mcf: \(detail)"
        }
    }
}

protocol AeroflyMcfWriting {
    func apply(weather: AeroflyEditableWeather?, route: SimBriefOFP?) throws
}

struct AeroflyMcfWriter: AeroflyMcfWriting {
    private let directoryLocator: any AeroflyUserDirectoryLocating
    private let fileManager: FileManager

    init(
        directoryLocator: any AeroflyUserDirectoryLocating = MacOSAeroflyUserDirectoryLocator(),
        fileManager: FileManager = .default
    ) {
        self.directoryLocator = directoryLocator
        self.fileManager = fileManager
    }

    func apply(weather: AeroflyEditableWeather?, route: SimBriefOFP?) throws {
        guard weather != nil || route != nil else { return }
        guard let directory = directoryLocator.locateUserDirectory() else {
            throw AeroflyMcfWriterError.userDirectoryNotFound
        }
        let mcfURL = directory.appendingPathComponent("main.mcf")
        guard fileManager.fileExists(atPath: mcfURL.path) else {
            throw AeroflyMcfWriterError.mainMcfMissing
        }

        let text = try String(contentsOf: mcfURL, encoding: .utf8)
        var root = try AeroflyMcfParser.parse(text)

        if let weather {
            root = try AeroflyMcfPatcher.applying(weather: weather, to: root)
        }
        if let route {
            root = try AeroflyMcfPatcher.applying(route: route, to: root)
        }

        let backupURL = directory.appendingPathComponent("main.mcf.bak")
        if !fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.copyItem(at: mcfURL, to: backupURL)
        }

        let serialized = AeroflyMcfSerializer.serialize(root) + "\n"
        let tempURL = directory.appendingPathComponent("main.mcf.tmp")
        do {
            try serialized.write(to: tempURL, atomically: true, encoding: .utf8)
            _ = try fileManager.replaceItemAt(mcfURL, withItemAt: tempURL)
        } catch {
            throw AeroflyMcfWriterError.writeFailed(error.localizedDescription)
        }
    }
}
