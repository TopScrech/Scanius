import simd

struct SceneAtlasLayout {
    nonisolated static func tiles(mesh: SceneMesh, frames: [SceneTextureFrame], photos: [ScenePhotoPixels], weights: [[Int: Float]]) throws -> [SceneTextureTile] {
        var sizes: [Int] = []
        for triangle in 0..<(mesh.indices.count / 3) {
            if triangle.isMultiple(of: 256) { try Task.checkCancellation() }
            let ids = (0..<3).map { Int(mesh.indices[triangle * 3 + $0]) }
            let sources = Set(ids.flatMap { weights[$0].keys })
            var pixels: Float = 8
            for source in sources {
                let uv = ids.compactMap { frames[source].project(mesh.positions[$0]) }
                guard uv.count == 3 else { continue }
                let resolution = SIMD2(Float(photos[source].width), Float(photos[source].height))
                pixels = max(pixels, simd_length((uv[0] - uv[1]) * resolution), simd_length((uv[0] - uv[2]) * resolution))
            }
            var size = 8
            while size < 128, Float(size - 3) < pixels { size *= 2 }
            sizes.append(size)
        }
        // Limit total decoded atlas pixels and favor resolution on large visible triangles
        while sizes.reduce(0, { $0 + $1 * $1 }) > 16_777_216, sizes.contains(where: { $0 > 8 }) {
            sizes = sizes.map { max(8, $0 / 2) }
        }
        guard sizes.reduce(0, { $0 + $1 * $1 }) <= 33_554_432 else { throw SceneTextureError.scanTooLarge }
        let order = sizes.indices.sorted { sizes[$0] == sizes[$1] ? $0 < $1 : sizes[$0] > sizes[$1] }
        var tiles: [SceneTextureTile] = []
        var x = 0, y = 0, rowHeight = 0, page = 0
        for triangle in order {
            let size = sizes[triangle]
            if x + size > 2048 { x = 0; y += rowHeight; rowHeight = 0 }
            if y + size > 2048 { page += 1; x = 0; y = 0; rowHeight = 0 }
            tiles.append(SceneTextureTile(triangle: triangle, size: size, x: x, y: y, page: page))
            x += size
            rowHeight = max(rowHeight, size)
        }
        return tiles
    }
}
