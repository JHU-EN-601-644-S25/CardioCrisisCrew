//
//  EkgXmlParser.swift
//  ccc
//
//  Created by Lily Wheeler on 4/8/25.
//


import Foundation

class EkgXmlParser: NSObject, XMLParserDelegate {
    private var readings: [Float] = []
    private var timestamp: String = ""
    private var heartRate: Int = 0
    private var currentElement = ""

    func parse(data: Data) -> EkgData {
        readings = []
        timestamp = ""
        heartRate = 0
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return EkgData(readings: readings, timestamp: timestamp, heartRate: heartRate)
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch currentElement {
        case "reading":
            if let value = Float(trimmed) {
                readings.append(value)
            }
        case "timestamp":
            timestamp = trimmed
        case "heartRate":
            heartRate = Int(trimmed) ?? 0
        default:
            break
        }
    }
}
