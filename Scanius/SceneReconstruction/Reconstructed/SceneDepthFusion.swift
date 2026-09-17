import simd

nonisolated struct SceneDepthFusion {
    nonisolated static func reconstruct(frames: [SceneTextureFrame], voxelSize: Float = 0.03,
                                       maximumBlocks: Int = 4096, maximumTriangles: Int = 100_000) throws -> SceneMesh {
        guard frames.count >= 3 else { throw SceneReconstructionError.insufficientDepth }
        var blocks: [SIMD3<Int32>: SceneTSDFBlock] = [:]
        let blockSize = voxelSize * 8
        for frame in frames {
            try Task.checkCancellation()
            var active = Set<SIMD3<Int32>>()
            // Allocate only the narrow band around observed surfaces, never the whole room volume
            for y in stride(from: 1, to: frame.depthHeight - 1, by: 2) {
                for x in stride(from: 1, to: frame.depthWidth - 1, by: 2) {
                    guard let point = SceneDepthGeometry.point(frame: frame, x: x, y: y) else { continue }
                    for offset in [-voxelSize * 3, Float(0), voxelSize * 3] {
                        let shifted = point * ((-point.z + offset) / -point.z)
                        let world = SceneDepthGeometry.transform(shifted, by: frame.cameraTransform)
                        guard world.x.isFinite, world.y.isFinite, world.z.isFinite,
                              simd_length(world) < 500 else { continue }
                        active.insert(SIMD3(Int32(floor(world.x / blockSize)), Int32(floor(world.y / blockSize)),
                                            Int32(floor(world.z / blockSize))))
                    }
                }
            }
            guard blocks.count + active.filter({ blocks[$0] == nil }).count <= maximumBlocks else {
                throw SceneReconstructionError.capacity
            }
            for key in active {
                try Task.checkCancellation()
                blocks[key, default: SceneTSDFBlock()].integrate(frame: frame, key: key, voxelSize: voxelSize)
            }
        }
        return try SceneIsosurface.extract(blocks: blocks, voxelSize: voxelSize, maximumTriangles: maximumTriangles)
    }
}
