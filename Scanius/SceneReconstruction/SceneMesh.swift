import simd

struct SceneMesh: Sendable {
    let positions: [SIMD3<Float>]
    let indices: [UInt32]
}
