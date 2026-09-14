import simd

struct ScenePhotoWeights {
    nonisolated static func build(mesh: SceneMesh, frames: [SceneTextureFrame]) throws -> [[Int: Float]] {
        var normals = Array(repeating: SIMD3<Float>.zero, count: mesh.positions.count)
        var neighbors = Array(repeating: Set<Int>(), count: mesh.positions.count)
        for offset in stride(from: 0, to: mesh.indices.count, by: 3) {
            let ids = (0..<3).map { Int(mesh.indices[offset + $0]) }
            let cross = simd_cross(mesh.positions[ids[1]] - mesh.positions[ids[0]], mesh.positions[ids[2]] - mesh.positions[ids[0]])
            for i in 0..<3 {
                normals[ids[i]] += cross
                neighbors[ids[i]].insert(ids[(i + 1) % 3])
                neighbors[ids[i]].insert(ids[(i + 2) % 3])
            }
        }
        var weights = Array(repeating: [Int: Float](), count: mesh.positions.count)
        for i in mesh.positions.indices {
            if i.isMultiple(of: 256) { try Task.checkCancellation() }
            guard simd_length_squared(normals[i]) > 1e-12 else { continue }
            let normal = simd_normalize(normals[i])
            for (index, frame) in frames.enumerated() {
                guard let uv = frame.project(mesh.positions[i]) else { continue }
                let edge = min(uv.x, uv.y, 1 - uv.x, 1 - uv.y)
                let score = frame.score(center: mesh.positions[i], normal: normal) * min(1, edge * 8)
                if score > 0 { weights[i][index] = score }
            }
            let candidates = weights[i].sorted {
                $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value
            }.prefix(6)
            weights[i] = Dictionary(uniqueKeysWithValues: candidates.map { ($0.key, $0.value) })
        }
        // Favor photos that also cover connected neighboring vertices
        let original = weights
        for i in weights.indices {
            for (photo, score) in original[i] {
                let support = neighbors[i].reduce(Float(0)) { $0 + (original[$1][photo] ?? 0) }
                weights[i][photo] = score * 0.5 + support / Float(max(1, neighbors[i].count)) * 0.5
            }
            let best = weights[i].sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.prefix(3)
            let sum = best.reduce(Float(0)) { $0 + $1.value }
            weights[i] = Dictionary(uniqueKeysWithValues: best.map { ($0.key, $0.value / max(sum, 1e-8)) })
        }
        return weights
    }
}
