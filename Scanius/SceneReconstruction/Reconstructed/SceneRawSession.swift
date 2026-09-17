import Foundation

nonisolated struct SceneRawSession {
    static var localDirectory: URL {
        URL.documentsDirectory.appending(path: "Raw Sessions")
    }

    nonisolated static func archiveURL(for scan: URL) -> URL {
        scan.deletingLastPathComponent().appending(path: "Raw Sessions")
            .appending(path: scan.deletingPathExtension().lastPathComponent + ".zip")
    }

    nonisolated static func prepare(frames: [SceneTextureFrame], directory: URL) throws -> URL {
        let raw = directory.appending(path: "Raw Session")
        try FileManager.default.createDirectory(at: raw, withIntermediateDirectories: true)
        let previousReport = raw.appending(path: "reconstruction.json")
        if FileManager.default.fileExists(atPath: previousReport.path) {
            try FileManager.default.removeItem(at: previousReport)
        }
        let records = frames.enumerated().map { SceneRawFrameRecord(frame: $0.element, index: $0.offset) }
        for (index, frame) in frames.enumerated() {
            try Task.checkCancellation()
            let record = records[index]
            let image = raw.appending(path: record.image)
            if !FileManager.default.fileExists(atPath: image.path) {
                try FileManager.default.copyItem(at: frame.imageURL, to: image)
            }
            let depths = frame.depths.map { $0.bitPattern.littleEndian }
            try depths.withUnsafeBytes { try Data($0).write(to: raw.appending(path: record.depth), options: .atomic) }
            try Data(frame.confidences).write(to: raw.appending(path: record.confidence), options: .atomic)
        }
        let manifest = SceneRawManifest(version: 1, coordinateSystem: "ARKit world, meters, +Y up, camera looks along -Z",
            depthEncoding: "Float32 little endian, camera Z distance in meters, row major",
            confidenceEncoding: "UInt8 row major, 0 low, 1 medium, 2 high",
            imageCoordinates: "Sensor orientation, scale intrinsics from reference dimensions to decoded JPEG dimensions",
            frames: records)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: raw.appending(path: "manifest.json"), options: .atomic)
        return raw
    }
}
