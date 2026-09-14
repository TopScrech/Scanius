import simd

struct SceneMeshSmoothing {
    // Weld only nearly coincident vertices, including boundaries between ARKit anchors
    nonisolated static func prepare(_ meshes: [SceneMesh], iterations: Int = 2) throws -> SceneMesh {
        var positions: [SIMD3<Float>] = []
        var buckets: [SIMD3<Int32>: [Int]] = [:]
        var indices: [UInt32] = []
        let tolerance: Float = 0.001
        for mesh in meshes {
            try Task.checkCancellation()
            var remap: [UInt32] = []
            for point in mesh.positions {
                let cell = SIMD3<Int32>(Int32(floor(point.x / tolerance)), Int32(floor(point.y / tolerance)), Int32(floor(point.z / tolerance)))
                var match: Int?
                for x in -1...1 {
                    for y in -1...1 {
                        for z in -1...1 {
                            for candidate in buckets[cell &+ SIMD3(Int32(x), Int32(y), Int32(z)), default: []] {
                                if simd_distance(positions[candidate], point) < tolerance { match = candidate }
                            }
                        }
                    }
                }
                if let match {
                    remap.append(UInt32(match))
                } else {
                    remap.append(UInt32(positions.count))
                    buckets[cell, default: []].append(positions.count)
                    positions.append(point)
                }
            }
            for offset in stride(from: 0, to: mesh.indices.count, by: 3) {
                let triangle = (0..<3).map { remap[Int(mesh.indices[offset + $0])] }
                if Set(triangle).count == 3 { indices.append(contentsOf: triangle) }
            }
        }
        var neighbors = Array(repeating: Set<Int>(), count: positions.count)
        var edgeCounts: [SIMD2<UInt32>: Int] = [:]
        var normals = Array(repeating: SIMD3<Float>.zero, count: positions.count)
        var faceNormals = Array(repeating: [SIMD3<Float>](), count: positions.count)
        for offset in stride(from: 0, to: indices.count, by: 3) {
            let ids = (0..<3).map { Int(indices[offset + $0]) }
            let cross = simd_cross(positions[ids[1]] - positions[ids[0]], positions[ids[2]] - positions[ids[0]])
            guard simd_length_squared(cross) > 1e-12 else { continue }
            for i in 0..<3 {
                let a = ids[i], b = ids[(i + 1) % 3]
                neighbors[a].insert(b)
                neighbors[b].insert(a)
                edgeCounts[SIMD2(UInt32(min(a, b)), UInt32(max(a, b))), default: 0] += 1
                normals[a] += cross
                faceNormals[a].append(simd_normalize(cross))
            }
        }
        var pinned = Set<Int>()
        for (edge, count) in edgeCounts where count != 2 {
            pinned.insert(Int(edge.x))
            pinned.insert(Int(edge.y))
        }
        for i in positions.indices {
            if simd_length_squared(normals[i]) < 1e-12 { pinned.insert(i); continue }
            normals[i] = simd_normalize(normals[i])
            // Protect corners and thin structures with sharply disagreeing normals
            if faceNormals[i].contains(where: { simd_dot($0, normals[i]) < 0.8 }) { pinned.insert(i) }
        }
        let original = positions
        for _ in 0..<iterations {
            try Task.checkCancellation()
            var updated = positions
            for i in positions.indices where !pinned.contains(i) {
                let normal = normals[i]
                var total: Float = 0
                var displacement: Float = 0
                for j in neighbors[i] {
                    let delta = positions[j] - positions[i]
                    let height = simd_dot(delta, normal)
                    let weight = exp(-simd_length_squared(delta) / (2 * 0.08 * 0.08))
                        * exp(-height * height / (2 * 0.008 * 0.008))
                    total += weight
                    displacement += weight * height
                }
                guard total > 0 else { continue }
                let proposed = positions[i] + normal * (0.5 * displacement / total)
                let delta = proposed - original[i]
                let length = simd_length(delta)
                updated[i] = original[i] + delta * min(1, 0.005 / max(length, 1e-8))
            }
            positions = updated
        }
        return SceneMesh(positions: positions, indices: indices)
    }
}
