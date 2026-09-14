import simd

struct SceneExposureCorrection {
    nonisolated static func gains(mesh: SceneMesh, frames: [SceneTextureFrame], photos: [ScenePhotoPixels], weights: [[Int: Float]]) throws -> [SIMD3<Float>] {
        var ratios: [SIMD2<Int>: [SIMD3<Float>]] = [:]
        let step = max(1, mesh.positions.count / 4000)
        for vertex in stride(from: 0, to: mesh.positions.count, by: step) {
            try Task.checkCancellation()
            let candidates = weights[vertex].keys.sorted()
            for (offset, a) in candidates.enumerated() {
                for b in candidates.dropFirst(offset + 1) {
                    guard let uvA = frames[a].project(mesh.positions[vertex]), let uvB = frames[b].project(mesh.positions[vertex]) else { continue }
                    let ca = photos[a].color(uv: uvA), cb = photos[b].color(uv: uvB)
                    guard ca.min() > 0.03, cb.min() > 0.03, ca.max() < 0.9, cb.max() < 0.9 else { continue }
                    ratios[SIMD2(a, b), default: []].append(SIMD3(log(ca.x / cb.x), log(ca.y / cb.y), log(ca.z / cb.z)))
                }
            }
        }
        var differences: [SIMD2<Int>: SIMD3<Float>] = [:]
        for (pair, values) in ratios where values.count >= 8 {
            differences[pair] = SIMD3((0..<3).map { channel in values.map { $0[channel] }.sorted()[values.count / 2] })
        }
        var logs = Array(repeating: SIMD3<Float>.zero, count: photos.count)
        for _ in 0..<12 {
            var sums = Array(repeating: SIMD3<Float>.zero, count: photos.count)
            var counts = Array(repeating: Float(1), count: photos.count)
            for pair in differences.keys.sorted(by: { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }) {
                guard let difference = differences[pair] else { continue }
                sums[pair.x] += logs[pair.y] - difference
                sums[pair.y] += logs[pair.x] + difference
                counts[pair.x] += 1
                counts[pair.y] += 1
            }
            for i in logs.indices { logs[i] = simd_clamp(sums[i] / counts[i], SIMD3(repeating: -0.22), SIMD3(repeating: 0.22)) }
        }
        return logs.map { SIMD3(exp($0.x), exp($0.y), exp($0.z)) }
    }
}
