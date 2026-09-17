import simd

nonisolated struct SceneDepthSample {
    let point: SIMD3<Float>
    let normal: SIMD3<Float>
    let weight: Float
}
