import Foundation

public final class SkinPackager {
    public static func exportSkin(_ skin: HUDSkin, to outputURL: URL) throws {
        let tempFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let assetsFolder = tempFolder.appendingPathComponent("assets")
        try FileManager.default.createDirectory(at: assetsFolder, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(skin)
        try jsonData.write(to: tempFolder.appendingPathComponent("skin.json"))

        let fileCoordinator = NSFileCoordinator()
        var error: NSError?
        fileCoordinator.coordinate(writingItemAt: tempFolder, options: .forDeleting, error: &error) { zipSource in
            let zipPath = outputURL
            if FileManager.default.fileExists(atPath: zipPath.path) {
                try? FileManager.default.removeItem(at: zipPath)
            }
            try? FileManager.default.copyItem(at: zipSource, to: zipPath)
        }
        if let err = error { throw err }
    }

    public static func importSkin(from packURL: URL) throws -> HUDSkin {
        let targetSkinsDir = HUDSkinManager.shared.userSkinsURL
        let tempExtract = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempExtract, withIntermediateDirectories: true)

        let jsonURL: URL
        if packURL.hasDirectoryPath {
            jsonURL = packURL.appendingPathComponent("skin.json")
        } else {
            try FileManager.default.copyItem(at: packURL, to: tempExtract.appendingPathComponent("pack"))
            let potentialJSON = tempExtract.appendingPathComponent("pack/skin.json")
            if FileManager.default.fileExists(atPath: potentialJSON.path) {
                jsonURL = potentialJSON
            } else {
                jsonURL = tempExtract.appendingPathComponent("pack")
            }
        }

        guard FileManager.default.fileExists(atPath: jsonURL.path),
              let data = try? Data(contentsOf: jsonURL),
              let skin = try? JSONDecoder().decode(HUDSkin.self, from: data) else {
            throw NSError(domain: "SkinPackager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invalid hudskinpack format"])
        }

        let skinDir = targetSkinsDir.appendingPathComponent(skin.id)
        if FileManager.default.fileExists(atPath: skinDir.path) {
            try? FileManager.default.removeItem(at: skinDir)
        }
        if packURL.hasDirectoryPath {
            try FileManager.default.copyItem(at: packURL, to: skinDir)
        } else {
            try FileManager.default.moveItem(at: tempExtract.appendingPathComponent("pack"), to: skinDir)
        }
        HUDSkinManager.shared.reloadSkins()
        return skin
    }
}
