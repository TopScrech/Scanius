import simd

nonisolated struct ScenePoseConstraint {
    let target: Int
    let source: Int
    let sourceToTarget: simd_float4x4
    let weight: Float
}
