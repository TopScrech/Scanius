import Foundation
import simd

struct SceneTextureFrame: Sendable {
    let imageURL: URL
    let cameraTransform: simd_float4x4
    let worldToCamera: simd_float4x4
    let intrinsics: simd_float3x3
    let imageSize: SIMD2<Float>
    let depths: [Float]
    let depthWidth: Int
    let depthHeight: Int

    nonisolated func project(_ point: SIMD3<Float>) -> SIMD2<Float>? {
        let camera = worldToCamera * SIMD4(point.x, point.y, point.z, 1)
        let distance = -camera.z
        guard distance > 0.1 else { return nil }
        let u = (intrinsics[0][0] * camera.x / distance + intrinsics[2][0]) / imageSize.x
        let v = (intrinsics[2][1] - intrinsics[1][1] * camera.y / distance) / imageSize.y
        guard u > 0.01, u < 0.99, v > 0.01, v < 0.99 else { return nil }
        let x = min(depthWidth - 1, Int(u * Float(depthWidth)))
        let y = min(depthHeight - 1, Int(v * Float(depthHeight)))
        let measured = depths[y * depthWidth + x]
        // Reject surfaces hidden behind foreground geometry or missing depth readings
        guard measured.isFinite, measured > 0,
              abs(measured - distance) < max(0.08, distance * 0.04) else { return nil }
        return SIMD2(u, 1 - v)
    }

    nonisolated func score(center: SIMD3<Float>, normal: SIMD3<Float>) -> Float {
        let position = cameraTransform.columns.3
        let direction = SIMD3(position.x, position.y, position.z) - center
        let distanceSquared = simd_length_squared(direction)
        guard distanceSquared > 0.01 else { return 0 }
        let alignment = abs(simd_dot(normal, simd_normalize(direction)))
        guard alignment > 0.25 else { return 0 }
        return alignment * alignment / distanceSquared
    }
}
