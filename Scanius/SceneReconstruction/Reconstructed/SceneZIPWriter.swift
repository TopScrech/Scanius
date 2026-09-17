import Foundation

nonisolated struct SceneZIPWriter {
    // Store entries without recompressing JPEGs or holding a whole scan in memory
    nonisolated static func write(directory: URL, to destination: URL) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let staging = destination.deletingLastPathComponent().appending(path: UUID().uuidString + ".partial")
        defer { try? manager.removeItem(at: staging) }
        guard manager.createFile(atPath: staging.path, contents: nil) else { throw SceneReconstructionError.archiveFailed }
        let output = try FileHandle(forWritingTo: staging)
        defer { try? output.close() }
        let table: [UInt32] = (0..<256).map {
            var value = UInt32($0)
            for _ in 0..<8 { value = (value >> 1) ^ (value & 1 == 0 ? 0 : 0xedb88320) }
            return value
        }
        let files = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
            .filter { try $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard files.count < 65_535 else { throw SceneReconstructionError.archiveFailed }
        var entries: [SceneZIPEntry] = []
        for file in files {
            try Task.checkCancellation()
            let offset = try output.offset()
            guard offset < UInt32.max else { throw SceneReconstructionError.archiveFailed }
            let name = Data(file.lastPathComponent.utf8)
            var header = Data()
            append(UInt32(0x04034b50), to: &header)
            for value: UInt16 in [20, 0x0808, 0, 0, 33] { append(value, to: &header) }
            for _ in 0..<3 { append(UInt32(0), to: &header) }
            append(UInt16(name.count), to: &header)
            append(UInt16(0), to: &header)
            header.append(name)
            try output.write(contentsOf: header)
            let input = try FileHandle(forReadingFrom: file)
            var crc: UInt32 = 0xffffffff
            var size: UInt64 = 0
            do {
                while let chunk = try input.read(upToCount: 65_536), !chunk.isEmpty {
                    try Task.checkCancellation()
                    size += UInt64(chunk.count)
                    guard size < UInt32.max else { throw SceneReconstructionError.archiveFailed }
                    for byte in chunk { crc = table[Int((crc ^ UInt32(byte)) & 0xff)] ^ (crc >> 8) }
                    try output.write(contentsOf: chunk)
                }
                try input.close()
            } catch {
                try? input.close()
                throw error
            }
            crc ^= 0xffffffff
            var descriptor = Data()
            for value in [UInt32(0x08074b50), crc, UInt32(size), UInt32(size)] { append(value, to: &descriptor) }
            try output.write(contentsOf: descriptor)
            entries.append(SceneZIPEntry(name: name, checksum: crc, size: UInt32(size), offset: UInt32(offset)))
        }
        let centralOffset = try output.offset()
        for entry in entries {
            var header = Data()
            append(UInt32(0x02014b50), to: &header)
            for value: UInt16 in [20, 20, 0x0808, 0, 0, 33] { append(value, to: &header) }
            for value in [entry.checksum, entry.size, entry.size] { append(value, to: &header) }
            append(UInt16(entry.name.count), to: &header)
            for _ in 0..<4 { append(UInt16(0), to: &header) }
            append(UInt32(0), to: &header)
            append(entry.offset, to: &header)
            header.append(entry.name)
            try output.write(contentsOf: header)
        }
        let end = try output.offset()
        guard end < UInt32.max else { throw SceneReconstructionError.archiveFailed }
        var footer = Data()
        append(UInt32(0x06054b50), to: &footer)
        append(UInt16(0), to: &footer)
        append(UInt16(0), to: &footer)
        append(UInt16(entries.count), to: &footer)
        append(UInt16(entries.count), to: &footer)
        append(UInt32(end - centralOffset), to: &footer)
        append(UInt32(centralOffset), to: &footer)
        append(UInt16(0), to: &footer)
        try output.write(contentsOf: footer)
        try output.synchronize()
        try output.close()
        if manager.fileExists(atPath: destination.path) {
            _ = try manager.replaceItemAt(destination, withItemAt: staging)
        } else {
            try manager.moveItem(at: staging, to: destination)
        }
    }

    nonisolated private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var value = value.littleEndian
        withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }
}
