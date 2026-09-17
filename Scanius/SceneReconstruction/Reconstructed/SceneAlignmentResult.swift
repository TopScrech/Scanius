import simd

nonisolated struct SceneAlignmentResult {
    let frames: [SceneTextureFrame]
    let registeredPairs: Int
    let loopClosures: Int
}
