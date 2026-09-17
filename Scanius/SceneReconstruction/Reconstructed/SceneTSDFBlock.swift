import simd

nonisolated struct SceneTSDFBlock {
    var distances = [Float](repeating: 1, count: 512)
    var weights = [Float](repeating: 0, count: 512)
    var observations = [UInt8](repeating: 0, count: 512)

    nonisolated mutating func integrate(frame: SceneTextureFrame, key: SIMD3<Int32>, voxelSize: Float) {
        let truncation = voxelSize * 3
        let origin = SIMD3(Float(key.x * 8), Float(key.y * 8), Float(key.z * 8))
        for z in 0..<8 {
            for y in 0..<8 {
                for x in 0..<8 {
                    let position = (origin + SIMD3(Float(x) + 0.5, Float(y) + 0.5, Float(z) + 0.5)) * voxelSize
                    let camera = SceneDepthGeometry.transform(position, by: frame.worldToCamera)
                    guard let pixel = SceneDepthGeometry.pixel(frame: frame, point: camera) else { continue }
                    let confidence = SceneDepthGeometry.weight(frame: frame, x: pixel.x, y: pixel.y)
                    guard confidence > 0 else { continue }
                    let depth = frame.depths[pixel.y * frame.depthWidth + pixel.x]
                    let sdf = depth + camera.z
                    guard sdf >= -truncation, sdf <= truncation else { continue }
                    // Avoid extending foreground depth across a silhouette discontinuity
                    guard let sample = SceneDepthGeometry.sample(frame: frame, x: pixel.x, y: pixel.y) else { continue }
                    let incidence = max(0, simd_dot(sample.normal, simd_normalize(-camera)))
                    guard incidence > 0.2 else { continue }
                    let weight = confidence * incidence / max(1, depth * depth)
                    let index = z * 64 + y * 8 + x
                    let total = weights[index] + weight
                    distances[index] = (distances[index] * weights[index] + sdf / truncation * weight) / total
                    weights[index] = min(64, total)
                    observations[index] = min(254, observations[index]) + 1
                }
            }
        }
    }
}
