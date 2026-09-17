import simd

nonisolated struct SceneIsosurface {
    nonisolated static func extract(blocks: [SIMD3<Int32>: SceneTSDFBlock], voxelSize: Float,
                                    maximumTriangles: Int) throws -> SceneMesh {
        let offsets: [SIMD3<Int32>] = [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(1, 1, 0), SIMD3(0, 1, 0),
                                      SIMD3(0, 0, 1), SIMD3(1, 0, 1), SIMD3(1, 1, 1), SIMD3(0, 1, 1)]
        let tetrahedra = [[0, 5, 1, 6], [0, 1, 2, 6], [0, 2, 3, 6], [0, 3, 7, 6], [0, 7, 4, 6], [0, 4, 5, 6]]
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        var vertices: [SceneVoxelEdge: UInt32] = [:]
        let keys = blocks.keys.sorted {
            $0.x != $1.x ? $0.x < $1.x : ($0.y != $1.y ? $0.y < $1.y : $0.z < $1.z)
        }
        for key in keys {
            try Task.checkCancellation()
            for z in 0..<8 {
                for y in 0..<8 {
                    for x in 0..<8 {
                        let base = key &* SIMD3(repeating: 8) &+ SIMD3(Int32(x), Int32(y), Int32(z))
                        let corners = offsets.map { base &+ $0 }
                        let values = corners.compactMap { distance(at: $0, blocks: blocks) }
                        guard values.count == 8, values.contains(where: { $0 < 0 }), values.contains(where: { $0 >= 0 }) else { continue }
                        for tetra in tetrahedra {
                            let inside = tetra.filter { values[$0] < 0 }
                            let outside = tetra.filter { values[$0] >= 0 }
                            guard !inside.isEmpty, !outside.isEmpty else { continue }
                            // Orient faces toward increasing signed distance, toward observed free space
                            let direction = outside.reduce(SIMD3<Float>.zero) { $0 + point(corners[$1], voxelSize: voxelSize) } / Float(outside.count)
                                - inside.reduce(SIMD3<Float>.zero) { $0 + point(corners[$1], voxelSize: voxelSize) } / Float(inside.count)
                            let edges: [(Int, Int)]
                            if inside.count == 1 {
                                edges = outside.map { (inside[0], $0) }
                            } else if outside.count == 1 {
                                edges = inside.map { ($0, outside[0]) }
                            } else {
                                edges = [(inside[0], outside[0]), (inside[0], outside[1]),
                                         (inside[1], outside[1]), (inside[1], outside[0])]
                            }
                            var polygon: [UInt32] = []
                            for (a, b) in edges {
                                let edge = SceneVoxelEdge(corners[a], corners[b])
                                if let vertex = vertices[edge] {
                                    polygon.append(vertex)
                                } else {
                                    let t = values[a] / (values[a] - values[b])
                                    let p = point(corners[a], voxelSize: voxelSize) * (1 - t) + point(corners[b], voxelSize: voxelSize) * t
                                    let vertex = UInt32(positions.count)
                                    vertices[edge] = vertex
                                    positions.append(p)
                                    polygon.append(vertex)
                                }
                            }
                            for i in 1..<(polygon.count - 1) {
                                let a = polygon[0], b = polygon[i], c = polygon[i + 1]
                                let normal = simd_cross(positions[Int(b)] - positions[Int(a)], positions[Int(c)] - positions[Int(a)])
                                guard simd_length_squared(normal) > 1e-14 else { continue }
                                indices.append(contentsOf: simd_dot(normal, direction) >= 0 ? [a, b, c] : [a, c, b])
                            }
                            guard indices.count / 3 <= maximumTriangles else { throw SceneReconstructionError.capacity }
                        }
                    }
                }
            }
        }
        guard !indices.isEmpty else { throw SceneReconstructionError.noSurface }
        return SceneMesh(positions: positions, indices: indices)
    }

    nonisolated private static func point(_ grid: SIMD3<Int32>, voxelSize: Float) -> SIMD3<Float> {
        (SIMD3(Float(grid.x), Float(grid.y), Float(grid.z)) + SIMD3(repeating: 0.5)) * voxelSize
    }

    nonisolated private static func distance(at grid: SIMD3<Int32>, blocks: [SIMD3<Int32>: SceneTSDFBlock]) -> Float? {
        let key = SIMD3(Int32(floor(Float(grid.x) / 8)), Int32(floor(Float(grid.y) / 8)), Int32(floor(Float(grid.z) / 8)))
        let local = grid &- key &* SIMD3(repeating: 8)
        guard let block = blocks[key] else { return nil }
        let index = Int(local.z * 64 + local.y * 8 + local.x)
        guard block.observations[index] >= 2, block.weights[index] > 0.05 else { return nil }
        return block.distances[index]
    }
}
