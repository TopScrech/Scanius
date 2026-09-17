import simd

nonisolated struct SceneRegistration {
    let sourceToTarget: simd_float4x4
    let residual: Float
    let overlap: Float
    let normalDiversity: Float
}
