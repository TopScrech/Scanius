import Foundation

nonisolated struct SceneReconstructionReport: Codable {
    let version: Int
    let voxelSizeMeters: Float
    let registeredPairs: Int
    let loopClosures: Int
    let triangles: Int
    let correctedFrames: [SceneRawFrameRecord]
}
