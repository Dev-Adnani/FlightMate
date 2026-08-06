//
//  CameraShakeTMDPatcher.swift
//  FlightMate
//
//  Patches only the CameraPilot camera_head block inside a .tmd string.
//  Missing Kf/Df/Kt/Dt are inserted (parameters.tmd often only has R0).
//

import Foundation

enum CameraShakeTMDPatcherError: Error, LocalizedError, Equatable {
    case cameraPilotNotFound
    case fieldMissing(String)
    case blockMalformed

    var errorDescription: String? {
        switch self {
        case .cameraPilotNotFound:
            return "No CameraPilot camera_head block found in this .tmd file."
        case .fieldMissing(let name):
            return "CameraPilot block is missing field \(name)."
        case .blockMalformed:
            return "CameraPilot block could not be updated."
        }
    }
}

enum CameraShakeTMDPatcher {
    private static let pilotMarker = "<[camera_head][CameraPilot][]"

    /// Returns patched file text, upserting Kf/Df/Kt/Dt and optional R0/Direction
    /// inside the first `CameraPilot` block only.
    static func applying(_ values: CameraShakeValues, to text: String) throws -> String {
        guard let range = pilotBlockRange(in: text) else {
            throw CameraShakeTMDPatcherError.cameraPilotNotFound
        }
        var block = String(text[range])
        block = try upsertFloat64(named: "Kf", with: values.kf, in: block)
        block = try upsertFloat64(named: "Df", with: values.df, in: block)
        block = try upsertFloat64(named: "Kt", with: values.kt, in: block)
        block = try upsertFloat64(named: "Dt", with: values.dt, in: block)
        if let r0 = values.r0 {
            block = try upsertVector3(named: "R0", with: r0, in: block)
        }
        if let direction = values.direction {
            block = try upsertVector3(named: "Direction", with: direction, in: block)
        }
        return text.replacingCharacters(in: range, with: block)
    }

    /// Inserts a CameraPilot override after the DynamicObjects list opens when absent.
    static func insertingCameraPilot(_ values: CameraShakeValues, into text: String) throws -> String {
        if pilotBlockRange(in: text) != nil {
            return try applying(values, to: text)
        }
        let needle = "<[pointer_list_tmuniverse][DynamicObjects][]"
        guard let open = text.range(of: needle) else {
            throw CameraShakeTMDPatcherError.blockMalformed
        }
        let insertAt = open.upperBound
        let block = """

            // FlightMate camera shake override
            <[camera_head][CameraPilot][]
\(cameraPilotInnerLines(values: values))
            >
"""
        var result = text
        result.insert(contentsOf: block, at: insertAt)
        return result
    }

    /// Locates the first CameraPilot group (from marker through its closing `>`).
    static func pilotBlockRange(in text: String) -> Range<String.Index>? {
        guard let startRange = text.range(of: pilotMarker) else { return nil }
        let searchFrom = startRange.upperBound
        let searchRange = searchFrom..<text.endIndex

        if let nextCamera = text.range(of: "<[camera", options: [], range: searchRange) {
            let beforeNext = text[searchFrom..<nextCamera.lowerBound]
            if let close = beforeNext.range(of: ">", options: .backwards) {
                return startRange.lowerBound..<close.upperBound
            }
        }

        if let close = text.range(of: ">", options: .backwards, range: searchRange) {
            var idx = close.lowerBound
            while true {
                if idx > text.startIndex {
                    let before = text.index(before: idx)
                    if text[before] != "]" {
                        return startRange.lowerBound..<text.index(after: idx)
                    }
                }
                guard idx > searchFrom else { break }
                let prior = text[searchFrom..<idx]
                guard let previous = prior.range(of: ">", options: .backwards) else { break }
                idx = previous.lowerBound
            }
        }
        return nil
    }

    private static func cameraPilotInnerLines(values: CameraShakeValues) -> String {
        var lines: [String] = []
        if let r0 = values.r0, r0.count == 3 {
            lines.append("                <[tmvector3d][R0][ \(format(r0[0])) \(format(r0[1])) \(format(r0[2])) ]>")
        }
        if let direction = values.direction, direction.count == 3 {
            lines.append(
                "                <[tmvector3d][Direction][ \(format(direction[0])) \(format(direction[1])) \(format(direction[2])) ]>"
            )
        }
        lines.append("                <[float64][Kf][\(format(values.kf))]>")
        lines.append("                <[float64][Df][\(format(values.df))]>")
        lines.append("                <[float64][Kt][\(format(values.kt))]>")
        lines.append("                <[float64][Dt][\(format(values.dt))]>")
        return lines.joined(separator: "\n")
    }

    private static func upsertFloat64(named name: String, with value: Double, in block: String) throws -> String {
        let pattern = #"<\[float64\]\[\#(name)\]\[[^\]]*\]>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            throw CameraShakeTMDPatcherError.fieldMissing(name)
        }
        let range = NSRange(block.startIndex..<block.endIndex, in: block)
        let replacement = "<[float64][\(name)][\(format(value))]>"
        let replaced = regex.stringByReplacingMatches(
            in: block,
            range: range,
            withTemplate: NSRegularExpression.escapedTemplate(for: replacement)
        )
        if replaced != block { return replaced }
        return try insertBeforeGroupClose(
            "                <[float64][\(name)][\(format(value))]>\n",
            in: block
        )
    }

    private static func upsertVector3(named name: String, with value: [Double], in block: String) throws -> String {
        guard value.count == 3 else { throw CameraShakeTMDPatcherError.fieldMissing(name) }
        let pattern = #"<\[tmvector3d\]\[\#(name)\]\[[^\]]*\]>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            throw CameraShakeTMDPatcherError.fieldMissing(name)
        }
        let range = NSRange(block.startIndex..<block.endIndex, in: block)
        let vector = value.map { format($0) }.joined(separator: " ")
        let replacement = "<[tmvector3d][\(name)][ \(vector) ]>"
        let replaced = regex.stringByReplacingMatches(
            in: block,
            range: range,
            withTemplate: NSRegularExpression.escapedTemplate(for: replacement)
        )
        if replaced != block { return replaced }
        return try insertBeforeGroupClose(
            "                <[tmvector3d][\(name)][ \(vector) ]>\n",
            in: block
        )
    }

    private static func insertBeforeGroupClose(_ line: String, in block: String) throws -> String {
        guard let close = block.range(of: ">", options: .backwards) else {
            throw CameraShakeTMDPatcherError.blockMalformed
        }
        var result = block
        result.insert(contentsOf: line, at: close.lowerBound)
        return result
    }

    private static func format(_ value: Double) -> String {
        String(format: "%g", value)
    }
}
