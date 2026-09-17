import simd

nonisolated struct SceneDepthRegistration {
    nonisolated static func align(source: SceneTextureFrame, target: SceneTextureFrame) throws -> SceneRegistration? {
        let initial = target.worldToCamera * source.cameraTransform
        var transform = initial
        var samples: [SceneDepthSample] = []
        let step = max(1, source.depthWidth / 48)
        for y in stride(from: 1, to: source.depthHeight - 1, by: step) {
            for x in stride(from: 1, to: source.depthWidth - 1, by: step) {
                if let sample = SceneDepthGeometry.sample(frame: source, x: x, y: y) { samples.append(sample) }
            }
        }
        guard samples.count >= 24 else { return nil }
        var initialError: Float = 0
        for iteration in 0...8 {
            try Task.checkCancellation()
            var matrix = [Double](repeating: 0, count: 36)
            var vector = [Double](repeating: 0, count: 6)
            var normals = simd_float3x3(0)
            var error: Float = 0
            var count = 0
            let rotation = SceneRigidMath.rotation(transform)
            for sample in samples {
                let point = SceneDepthGeometry.transform(sample.point, by: transform)
                guard let pixel = SceneDepthGeometry.pixel(frame: target, point: point),
                      let match = SceneDepthGeometry.sample(frame: target, x: pixel.x, y: pixel.y),
                      simd_distance(point, match.point) < 0.12,
                      simd_dot(rotation.act(sample.normal), match.normal) > 0.8 else { continue }
                let residual = simd_dot(match.normal, point - match.point)
                guard abs(residual) < 0.08 else { continue }
                let weight = Double(sample.weight * match.weight * min(1, 0.015 / max(abs(residual), 1e-6)))
                let angular = simd_cross(point, match.normal)
                let jacobian = [angular.x, angular.y, angular.z, match.normal.x, match.normal.y, match.normal.z].map(Double.init)
                for row in 0..<6 {
                    vector[row] -= weight * jacobian[row] * Double(residual)
                    for column in 0..<6 { matrix[row * 6 + column] += weight * jacobian[row] * jacobian[column] }
                }
                for column in 0..<3 { normals[column] += match.normal * match.normal[column] }
                error += residual * residual
                count += 1
            }
            let overlap = Float(count) / Float(samples.count)
            guard count >= 24, overlap >= 0.25 else { return nil }
            let rmse = sqrt(error / Float(count))
            if iteration == 0 { initialError = rmse }
            if iteration == 8 {
                let correction = transform * initial.inverse
                guard rmse < 0.025, rmse <= initialError + 0.002,
                      simd_length(SceneRigidMath.position(correction)) < 0.12,
                      simd_length(SceneRigidMath.rotationVector(SceneRigidMath.rotation(correction))) < 0.08 else { return nil }
                return SceneRegistration(sourceToTarget: transform, residual: rmse, overlap: overlap,
                                         normalDiversity: simd_determinant(normals * (1 / Float(count))))
            }
            guard let delta = SceneRigidMath.solve(matrix: matrix, vector: vector) else { return nil }
            let angular = SIMD3(delta[0], delta[1], delta[2])
            let linear = SIMD3(delta[3], delta[4], delta[5])
            guard simd_length(angular) < 0.05, simd_length(linear) < 0.08 else { return nil }
            transform = SceneRigidMath.transform(rotation: angular, translation: linear) * transform
        }
        return nil
    }
}
