// PhantomKnob/Model/AppSettings.swift
import Foundation

struct AppSettings: Codable {
    var activeScheme: String = "fixed"
    var enableKeyboardNumberMultiplier: Bool = true
    var fixed: FixedSchemeConfig = FixedSchemeConfig()
    var cvk: ScaleConfigCVK = ScaleConfigCVK(minRadius: 10.0, maxRadius: 35.0, minScale: 0.2, maxScale: 1.0)

    var defaultThemeColor: String = "#0A84FF"
    var defaultOverlayStyle: String = "hud"
    var defaultRotationStyle: String = "ticks"

    struct FixedSchemeConfig: Codable {
        var zones: [RadiusZone] = [
            RadiusZone(minRadius: 5.0, maxRadius: 100.0, margin: 2.0, scale: 1.0)
        ]
    }

    static var shared: AppSettings = {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PhantomKnob")
        let fileURL = folder.appendingPathComponent("settings.jsonc")
        
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let defaults = AppSettings()
            if let data = try? JSONEncoder().encode(defaults) {
                try? data.write(to: fileURL)
            }
            return defaults
        }
        
        guard let data = try? Data(contentsOf: fileURL),
              let config = try? JSONCParser.decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return config
    }()
}

struct JSONCParser {
    static func stripComments(from jsonString: String) -> String {
        let pattern = #"(?:/\*(?:[^*]|\*(?!/))*\*/)|(?://.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return jsonString
        }
        let range = NSRange(jsonString.startIndex..., in: jsonString)
        return regex.stringByReplacingMatches(in: jsonString, options: [], range: range, withTemplate: "")
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard let rawString = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Invalid UTF-8"))
        }
        let cleanString = stripComments(from: rawString)
        guard let cleanData = cleanString.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "UTF-8 conversion failed"))
        }
        return try JSONDecoder().decode(type, from: cleanData)
    }
}
