import Foundation

nonisolated struct SceneZIPEntry {
    let name: Data
    let checksum: UInt32
    let size: UInt32
    let offset: UInt32
}
