import Foundation

nonisolated struct SceneRawManifest: Codable {
    let version: Int
    let coordinateSystem: String
    let depthEncoding: String
    let confidenceEncoding: String
    let imageCoordinates: String
    let frames: [SceneRawFrameRecord]
}
