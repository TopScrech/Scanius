import simd

struct SceneTextureProjection: Sendable {
    var patches: [Int: SceneTexturePatch] = [:]
    var triangleCount = 0
    var texturedTriangleCount = 0

    nonisolated static func build(meshes: [SceneMesh], frames: [SceneTextureFrame]) throws -> Self {
        var result = Self()
        for mesh in meshes {
            for offset in stride(from: 0, to: mesh.indices.count, by: 3) {
                if offset.isMultiple(of: 300) { try Task.checkCancellation() }
                let a = mesh.positions[Int(mesh.indices[offset])]
                let b = mesh.positions[Int(mesh.indices[offset + 1])]
                let c = mesh.positions[Int(mesh.indices[offset + 2])]
                let cross = simd_cross(b - a, c - a)
                guard simd_length_squared(cross) > 0.00000001 else { continue }
                let normal = simd_normalize(cross)
                let center = (a + b + c) / 3
                var bestIndex = -1
                var bestScore: Float = 0
                var bestUVs: [SIMD2<Float>] = []
                for (index, frame) in frames.enumerated() {
                    let score = frame.score(center: center, normal: normal)
                    guard score > bestScore, frame.project(center) != nil,
                          let uvA = frame.project(a), let uvB = frame.project(b), let uvC = frame.project(c) else { continue }
                    bestIndex = index
                    bestScore = score
                    bestUVs = [uvA, uvB, uvC]
                }
                result.triangleCount += 1
                if bestIndex >= 0 { result.texturedTriangleCount += 1 }
                result.patches[bestIndex, default: SceneTexturePatch()].positions.append(contentsOf: [a, b, c])
                result.patches[bestIndex, default: SceneTexturePatch()].textureCoordinates.append(
                    contentsOf: bestIndex >= 0 ? bestUVs : [.zero, .zero, .zero]
                )
            }
        }
        return result
    }
}
