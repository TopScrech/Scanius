import simd

nonisolated struct SceneRigidMath {
    nonisolated static func position(_ transform: simd_float4x4) -> SIMD3<Float> {
        SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }

    nonisolated static func rotation(_ transform: simd_float4x4) -> simd_quatf {
        simd_quatf(transform)
    }

    nonisolated static func rotationVector(_ quaternion: simd_quatf) -> SIMD3<Float> {
        let q = quaternion.real < 0 ? simd_quatf(vector: -quaternion.vector) : quaternion
        let length = simd_length(q.imag)
        guard length > 1e-8 else { return .zero }
        return q.imag * (2 * atan2(length, q.real) / length)
    }

    nonisolated static func transform(rotation: SIMD3<Float>, translation: SIMD3<Float>) -> simd_float4x4 {
        let angle = simd_length(rotation)
        let quaternion = angle > 1e-8 ? simd_quatf(angle: angle, axis: rotation / angle) : simd_quatf(angle: 0, axis: SIMD3(0, 1, 0))
        var matrix = simd_float4x4(quaternion)
        matrix.columns.3 = SIMD4(translation, 1)
        return matrix
    }

    // Damped normal equations retain ARKit's estimate along unconstrained directions
    nonisolated static func solve(matrix: [Double], vector: [Double]) -> [Float]? {
        guard matrix.count == 36, vector.count == 6 else { return nil }
        var a = matrix
        var b = vector
        let scale = (0..<6).map { a[$0 * 6 + $0] }.max() ?? 1
        for i in 0..<6 { a[i * 6 + i] += max(1e-5, scale * 1e-5) }
        for column in 0..<6 {
            let pivot = (column..<6).max { abs(a[$0 * 6 + column]) < abs(a[$1 * 6 + column]) } ?? column
            guard abs(a[pivot * 6 + column]) > 1e-10 else { return nil }
            if pivot != column {
                for j in 0..<6 { a.swapAt(column * 6 + j, pivot * 6 + j) }
                b.swapAt(column, pivot)
            }
            let divisor = a[column * 6 + column]
            for j in column..<6 { a[column * 6 + j] /= divisor }
            b[column] /= divisor
            for row in 0..<6 where row != column {
                let factor = a[row * 6 + column]
                for j in column..<6 { a[row * 6 + j] -= factor * a[column * 6 + j] }
                b[row] -= factor * b[column]
            }
        }
        guard b.allSatisfy(\.isFinite) else { return nil }
        return b.map(Float.init)
    }
}
