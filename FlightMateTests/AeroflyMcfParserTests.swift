//
//  AeroflyMcfParserTests.swift
//  FlightMateTests
//

import Testing
@testable import FlightMate

struct AeroflyMcfParserTests {
    @Test func parsesSimpleLeafNode() throws {
        let node = try AeroflyMcfParser.parse("<[string8u][name][a350_1000]>")
        #expect(node.type == "string8u")
        #expect(node.key == "name")
        #expect(node.value == "a350_1000")
        #expect(node.children.isEmpty)
    }

    @Test func parsesEmptyValueLeafNode() throws {
        let node = try AeroflyMcfParser.parse("<[list_string8u][options][]>")
        #expect(node.value == "")
        #expect(node.children.isEmpty)
    }

    @Test func parsesNestedGroupWithChildren() throws {
        let text = """
        <[tmsettings_aircraft][aircraft][]
            <[string8u][name][a350_1000]>
            <[string8u][paintscheme][qatar_oneworld]>
        >
        """
        let node = try AeroflyMcfParser.parse(text)
        #expect(node.type == "tmsettings_aircraft")
        #expect(node.key == "aircraft")
        #expect(node.children.count == 2)
        #expect(node.firstChild(key: "name")?.value == "a350_1000")
        #expect(node.firstChild(key: "paintscheme")?.value == "qatar_oneworld")
    }

    @Test func parsesEmptySelfClosedGroupWithNoChildren() throws {
        let text = """
        <[pointer_list_tmnav_route_way][Ways][]
        >
        """
        let node = try AeroflyMcfParser.parse(text)
        #expect(node.type == "pointer_list_tmnav_route_way")
        #expect(node.children.isEmpty)
    }

    @Test func parsesRepeatedListElementsPreservingOrder() throws {
        let text = """
        <[list_tmsettings_aircraft][aircraft_list][]
            <[tmsettings_aircraft][element][0]
                <[string8u][name][b787_9]>
            >
            <[tmsettings_aircraft][element][1]
                <[string8u][name][a380]>
            >
        >
        """
        let node = try AeroflyMcfParser.parse(text)
        let elements = node.children(key: "element")
        #expect(elements.count == 2)
        #expect(elements[0].value == "0")
        #expect(elements[0].firstChild(key: "name")?.value == "b787_9")
        #expect(elements[1].value == "1")
        #expect(elements[1].firstChild(key: "name")?.value == "a380")
    }

    @Test func waypointNodeKeyIsTheIdentifierNotElement() throws {
        // Confirmed against a real main.mcf with a flight plan: each
        // waypoint's `key` is its identifier (airport/runway/waypoint
        // name), not a generic "element".
        let text = """
        <[tmnav_route_destination][EGPH][7]
            <[string8u][Identifier][EGPH]>
        >
        """
        let node = try AeroflyMcfParser.parse(text)
        #expect(node.type == "tmnav_route_destination")
        #expect(node.key == "EGPH")
        #expect(node.value == "7")
    }

    @Test func parsesFullSyntheticMainMcfTree() throws {
        let root = try AeroflyMcfParser.parse(AeroflySessionFixtures.mainMcf())
        #expect(root.type == "file")
        #expect(root.firstChild(type: "tmsettings_sim") != nil)
    }

    @Test func throwsOnMissingBracket() {
        #expect(throws: (any Error).self) {
            _ = try AeroflyMcfParser.parse("<[type][key]missing_bracket>")
        }
    }

    @Test func throwsOnUnterminatedGroup() {
        #expect(throws: (any Error).self) {
            _ = try AeroflyMcfParser.parse("<[type][key][]\n<[leaf][k][v]>")
        }
    }
}
