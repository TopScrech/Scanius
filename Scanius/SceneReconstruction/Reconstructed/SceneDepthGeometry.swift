import simd

nonisolated struct SceneDepthGeometry {
    nonisolated static func weight(frame: SceneTextureFrame, x: Int, y: Int) -> Float {
        guard x >= 0, y >= 0, x < frame.depthWidth, y < frame.depthHeight,
              frame.depths.count == frame.depthWidth * frame.depthHeight,
              frame.confidences.count == frame.depths.count else { return 0 }
        let i = y * frame.depthWidth + x
        let depth = frame.depths[i]
        guard depth.isFinite, depth >= 0.2, depth <= 5 else { return 0 }
        return frame.confidences[i] == 2 ? 1 : (frame.confidences[i] == 1 ? 0.25 : 0)
    }

    nonisolated static func point(frame: SceneTextureFrame, x: Int, y: Int) -> SIMD3<Float>? {
        guard weight(frame: frame, x: x, y: y) > 0,
              frame.intrinsics[0][0] > 0, frame.intrinsics[1][1] > 0 else { return nil }
        let z = frame.depths[y * frame.depthWidth + x]
        let u = (Float(x) + 0.5) * frame.imageSize.x / Float(frame.depthWidth)
        let v = (Float(y) + 0.5) * frame.imageSize.y / Float(frame.depthHeight)
        return SIMD3((u - frame.intrinsics[2][0]) * z / frame.intrinsics[0][0],
                     (frame.intrinsics[2][1] - v) * z / frame.intrinsics[1][1], -z)
    }

    nonisolated static func pixel(frame: SceneTextureFrame, point: SIMD3<Float>) -> SIMD2<Int>? {
        guard point.z < -0.1 else { return nil }
        let u = (frame.intrinsics[0][0] * point.x / -point.z + frame.intrinsics[2][0])
            * Float(frame.depthWidth) / frame.imageSize.x
        let v = (frame.intrinsics[2][1] - frame.intrinsics[1][1] * point.y / -point.z)
            * Float(frame.depthHeight) / frame.imageSize.y
        guard u.isFinite, v.isFinite, u >= 1, v >= 1,
              u < Float(frame.depthWidth - 1), v < Float(frame.depthHeight - 1) else { return nil }
        return SIMD2(Int(u), Int(v))
    }

    nonisolated static func sample(frame: SceneTextureFrame, x: Int, y: Int) -> SceneDepthSample? {
        guard let center = point(frame: frame, x: x, y: y),
              let right = point(frame: frame, x: x + 1, y: y),
              let down = point(frame: frame, x: x, y: y + 1) else { return nil }
        let tolerance = max(0.04, -center.z * 0.03)
        guard abs(right.z - center.z) < tolerance, abs(down.z - center.z) < tolerance else { return nil }
        let cross = simd_cross(down - center, right - center)
        guard simd_length_squared(cross) > 1e-12 else { return nil }
        return SceneDepthSample(point: center, normal: simd_normalize(cross),
                                weight: min(weight(frame: frame, x: x, y: y),
                                            weight(frame: frame, x: x + 1, y: y),
                                            weight(frame: frame, x: x, y: y + 1)))
    }

    nonisolated static func transform(_ point: SIMD3<Float>, by matrix: simd_float4x4) -> SIMD3<Float> {
        let value = matrix * SIMD4(point, 1)
        return SIMD3(value.x, value.y, value.z)
    }
}
