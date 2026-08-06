//
//  AeroflyMcfSerializer.swift
//  FlightMate
//
//  Serializes an AeroflyMcfNode tree back to IPACS .mcf text.
//

import Foundation

enum AeroflyMcfSerializer {
    /// Round-trips a node tree to Aerofly `.mcf` text.
    static func serialize(_ node: AeroflyMcfNode, indent: Int = 0) -> String {
        let pad = String(repeating: "    ", count: indent)
        let header = "<[\(node.type)][\(node.key)][\(node.value)]"
        if node.children.isEmpty {
            return "\(pad)\(header)>"
        }
        var lines = ["\(pad)\(header)"]
        for child in node.children {
            lines.append(serialize(child, indent: indent + 1))
        }
        lines.append("\(pad)>")
        return lines.joined(separator: "\n")
    }
}

extension AeroflyMcfNode {
    /// Returns a copy with `children` replaced.
    func replacingChildren(_ children: [AeroflyMcfNode]) -> AeroflyMcfNode {
        AeroflyMcfNode(type: type, key: key, value: value, children: children)
    }

    /// Replaces the first direct child matching `type`, or appends if missing.
    func replacingOrAppendingChild(type: String, with replacement: AeroflyMcfNode) -> AeroflyMcfNode {
        var next = children
        if let index = next.firstIndex(where: { $0.type == type }) {
            next[index] = replacement
        } else {
            next.append(replacement)
        }
        return replacingChildren(next)
    }

    /// Replaces the first direct child matching `key`, or appends if missing.
    func replacingOrAppendingChild(key: String, with replacement: AeroflyMcfNode) -> AeroflyMcfNode {
        var next = children
        if let index = next.firstIndex(where: { $0.key == key }) {
            next[index] = replacement
        } else {
            next.append(replacement)
        }
        return replacingChildren(next)
    }
}
