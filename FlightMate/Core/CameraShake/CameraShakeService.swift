//
//  CameraShakeService.swift
//  FlightMate
//
//  Applies CameraPilot shake into the *user* aircraft folder via a minimal
//  parameters.tmd override (never Steam). Matches community guidance:
//  user …/aircraft/<code>/parameters.tmd.
//

import Foundation

enum CameraShakeServiceError: Error, LocalizedError, Equatable {
    case installAircraftNotFound
    case userDirectoryNotFound
    case aircraftFolderMissing(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .installAircraftNotFound:
            return "Could not find Aerofly’s installed aircraft folder (Steam/common)."
        case .userDirectoryNotFound:
            return "Could not find Aerofly user folder."
        case .aircraftFolderMissing(let code):
            return "Aircraft “\(code)” not found in the Aerofly install."
        case .writeFailed(let detail):
            return detail
        }
    }
}

protocol CameraShakeApplying {
    func apply(preset: CameraShakePreset) throws -> URL
    func apply(values: CameraShakeValues, aeroflyCode: String) throws -> URL
    func restoreBackup(aeroflyCode: String) throws -> URL?
    func hasUserOverride(aeroflyCode: String) -> Bool
    func removeUserOverride(aeroflyCode: String) throws
}

struct CameraShakeService: CameraShakeApplying {
    private static let overrideRelativePath = "parameters.tmd"

    private let userDirectoryLocator: any AeroflyUserDirectoryLocating
    private let installLocator: any AeroflyAircraftInstallLocating
    private let fileManager: FileManager

    init(
        userDirectoryLocator: any AeroflyUserDirectoryLocating = MacOSAeroflyUserDirectoryLocator(),
        installLocator: any AeroflyAircraftInstallLocating = MacOSAeroflyAircraftInstallLocator(),
        fileManager: FileManager = .default
    ) {
        self.userDirectoryLocator = userDirectoryLocator
        self.installLocator = installLocator
        self.fileManager = fileManager
    }

    func apply(preset: CameraShakePreset) throws -> URL {
        try apply(values: preset.values, aeroflyCode: preset.aeroflyCode)
    }

    func apply(values: CameraShakeValues, aeroflyCode: String) throws -> URL {
        try ensureAircraftExistsInInstall(aeroflyCode: aeroflyCode)
        let destinationURL = try userOverrideURL(aeroflyCode: aeroflyCode)

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let backupURL = destinationURL.appendingPathExtension("bak")
        if fileManager.fileExists(atPath: destinationURL.path),
           !fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.copyItem(at: destinationURL, to: backupURL)
        }

        let contents: String
        if fileManager.fileExists(atPath: destinationURL.path),
           let existing = try? String(contentsOf: destinationURL, encoding: .utf8),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Preserve other user overrides; upsert or insert CameraPilot only.
            do {
                contents = try CameraShakeTMDPatcher.insertingCameraPilot(values, into: existing)
            } catch {
                contents = CameraShakeParametersTMDBuilder.makeFile(values: values)
            }
        } else {
            contents = CameraShakeParametersTMDBuilder.makeFile(values: values)
        }

        do {
            try contents.write(to: destinationURL, atomically: true, encoding: .utf8)
        } catch {
            throw CameraShakeServiceError.writeFailed(error.localizedDescription)
        }
        return destinationURL
    }

    func restoreBackup(aeroflyCode: String) throws -> URL? {
        let destinationURL = try userOverrideURL(aeroflyCode: aeroflyCode)
        let backupURL = destinationURL.appendingPathExtension("bak")
        guard fileManager.fileExists(atPath: backupURL.path) else { return nil }
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: backupURL, to: destinationURL)
        return destinationURL
    }

    func hasUserOverride(aeroflyCode: String) -> Bool {
        guard let url = try? userOverrideURL(aeroflyCode: aeroflyCode) else { return false }
        return fileManager.fileExists(atPath: url.path)
    }

    func removeUserOverride(aeroflyCode: String) throws {
        let destinationURL = try userOverrideURL(aeroflyCode: aeroflyCode)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
    }

    private func ensureAircraftExistsInInstall(aeroflyCode: String) throws {
        guard let installRoot = installLocator.locateAircraftInstallDirectory() else {
            throw CameraShakeServiceError.installAircraftNotFound
        }
        let aircraftRoot = installRoot.appendingPathComponent(aeroflyCode, isDirectory: true)
        guard fileManager.fileExists(atPath: aircraftRoot.path) else {
            throw CameraShakeServiceError.aircraftFolderMissing(aeroflyCode)
        }
    }

    private func userOverrideURL(aeroflyCode: String) throws -> URL {
        guard let userRoot = userDirectoryLocator.locateUserDirectory() else {
            throw CameraShakeServiceError.userDirectoryNotFound
        }
        return userRoot
            .appendingPathComponent("aircraft", isDirectory: true)
            .appendingPathComponent(aeroflyCode, isDirectory: true)
            .appendingPathComponent(Self.overrideRelativePath)
    }
}
