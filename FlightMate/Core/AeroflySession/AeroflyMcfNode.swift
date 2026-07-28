//
//  AeroflyMcfNode.swift
//  FlightMate
//
//  Generic tree representation of Aerofly's ".mcf" tagged file format (used
//  by main.mcf, gc-map.mcf, and others). Carries no domain knowledge about
//  what any particular type/key means — that lives in AeroflySessionMapper.
//

import Foundation

/// A single node in a parsed `.mcf` file.
///
/// Every node looks like `<[type][key][value]>` in the source text. Leaf
/// nodes carry a scalar `value` and no children; group nodes carry an empty
/// (or index-like, e.g. `"0"` for list elements) `value` and one or more
/// `children`.
struct AeroflyMcfNode: Equatable {
    /// The bracketed type name, e.g. `"string8u"`, `"tmsettings_aircraft"`.
    let type: String

    /// The bracketed key name, e.g. `"name"`, `"aircraft"`, `"element"`.
    let key: String

    /// The bracketed scalar value. Empty for group nodes.
    let value: String

    /// Nested nodes. Empty for leaf nodes.
    let children: [AeroflyMcfNode]
}

extension AeroflyMcfNode {
    /// The first direct child with the given `key`, if any.
    func firstChild(key: String) -> AeroflyMcfNode? {
        children.first { $0.key == key }
    }

    /// All direct children with the given `key`, in document order. Used
    /// for repeated list entries, which all share the key `"element"`.
    func children(key: String) -> [AeroflyMcfNode] {
        children.filter { $0.key == key }
    }

    /// The first direct child with the given `type`, if any.
    ///
    /// Structural settings groups (e.g. `tmsettings_aircraft`,
    /// `tmsettings_flight`) are best identified by `type` rather than
    /// `key` — their `key` is often empty or only meaningful in context,
    /// while `type` acts as a stable namespace. Leaf fields (`string8u`,
    /// `float64`, ...) should instead be looked up by `key` via
    /// `firstChild(key:)`, since their `type` is just the generic wire
    /// type, not anything domain-meaningful.
    func firstChild(type: String) -> AeroflyMcfNode? {
        children.first { $0.type == type }
    }

    /// All direct children with the given `type`, in document order.
    func children(type: String) -> [AeroflyMcfNode] {
        children.filter { $0.type == type }
    }

    /// `value` parsed as a `Double`, or `nil` if it isn't numeric.
    var doubleValue: Double? { Double(value) }

    /// `value` parsed as an `Int`, or `nil` if it isn't an integer.
    var intValue: Int? { Int(value) }

    /// `value` parsed as a `Bool` (`"true"`/`"false"` only), or `nil`
    /// otherwise.
    var boolValue: Bool? {
        switch value {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    /// `value` split on whitespace and parsed as `Double`s — used for
    /// `vector3_float64`/`matrix3_float64`-style space-separated fields.
    /// Entries that aren't numeric are silently skipped.
    var doubleArray: [Double] {
        value.split(separator: " ").compactMap { Double($0) }
    }
}
