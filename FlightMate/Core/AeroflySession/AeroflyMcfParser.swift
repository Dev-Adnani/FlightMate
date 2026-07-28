//
//  AeroflyMcfParser.swift
//  FlightMate
//
//  Recursive-descent parser for Aerofly's ".mcf" tagged file format.
//
//  Grammar (informal):
//    node  ::= "<[" TYPE "][" KEY "][" VALUE "]" (leafClose | groupClose)
//    leafClose  ::= ">"
//    groupClose ::= node* ">"
//  TYPE/KEY/VALUE are read up to the next "]" — the format has no escaping,
//  so (like every other known parser for this format, including the
//  reference JS implementation) a literal "]" inside a value cannot be
//  represented and isn't handled specially here either.
//
//  Deliberately does NOT rely on indentation/nesting depth the way the
//  reference JS parser (fboes/aerofly-missions) does — this scans purely by
//  matching "<[...]...]...]" against its closing ">" wherever it occurs, so
//  there are no hardcoded depth assumptions anywhere.
//

import Foundation

enum AeroflyMcfParserError: Error, LocalizedError {
    case unexpectedCharacter(expected: Character, foundAt: Int)
    case unexpectedEndOfFile

    var errorDescription: String? {
        switch self {
        case .unexpectedCharacter(let expected, let foundAt):
            return "Expected '\(expected)' at character offset \(foundAt)."
        case .unexpectedEndOfFile:
            return "Unexpected end of file while parsing .mcf content."
        }
    }
}

enum AeroflyMcfParser {
    /// Parses the full contents of a `.mcf` file into its root node.
    ///
    /// Aerofly's own files always have a single root, e.g. `<[file][][] ... >`.
    static func parse(_ text: String) throws -> AeroflyMcfNode {
        let characters = Array(text)
        var index = 0
        skipWhitespace(characters, &index)
        return try parseNode(characters, &index)
    }

    private static func parseNode(_ characters: [Character], _ index: inout Int) throws -> AeroflyMcfNode {
        try expect("<", characters, &index)
        try expect("[", characters, &index)
        let type = readUntil("]", characters, &index)
        try expect("]", characters, &index)

        try expect("[", characters, &index)
        let key = readUntil("]", characters, &index)
        try expect("]", characters, &index)

        try expect("[", characters, &index)
        let value = readUntil("]", characters, &index)
        try expect("]", characters, &index)

        guard index < characters.count else { throw AeroflyMcfParserError.unexpectedEndOfFile }

        if characters[index] == ">" {
            index += 1
            return AeroflyMcfNode(type: type, key: key, value: value, children: [])
        }

        var children: [AeroflyMcfNode] = []
        while true {
            skipWhitespace(characters, &index)
            guard index < characters.count else { throw AeroflyMcfParserError.unexpectedEndOfFile }
            if characters[index] == ">" {
                index += 1
                break
            }
            children.append(try parseNode(characters, &index))
        }

        return AeroflyMcfNode(type: type, key: key, value: value, children: children)
    }

    private static func expect(_ character: Character, _ characters: [Character], _ index: inout Int) throws {
        guard index < characters.count, characters[index] == character else {
            throw AeroflyMcfParserError.unexpectedCharacter(expected: character, foundAt: index)
        }
        index += 1
    }

    /// Reads characters up to (but not including/consuming) the next
    /// occurrence of `terminator`.
    private static func readUntil(_ terminator: Character, _ characters: [Character], _ index: inout Int) -> String {
        var result = ""
        while index < characters.count, characters[index] != terminator {
            result.append(characters[index])
            index += 1
        }
        return result
    }

    private static func skipWhitespace(_ characters: [Character], _ index: inout Int) {
        while index < characters.count, characters[index].isWhitespace {
            index += 1
        }
    }
}
