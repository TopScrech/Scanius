import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import simd

struct SceneTextureBaker {
    nonisolated static func bake(meshes: [SceneMesh], frames: [SceneTextureFrame], directory: URL) throws -> SceneTextureProjection {
        let mesh = try SceneMeshSmoothing.prepare(meshes)
        let weights = try ScenePhotoWeights.build(mesh: mesh, frames: frames)
        let photos = try frames.map { try ScenePhotoPixels(url: $0.imageURL) }
        let gains = try SceneExposureCorrection.gains(mesh: mesh, frames: frames, photos: photos, weights: weights)
        let tiles = try SceneAtlasLayout.tiles(mesh: mesh, frames: frames, photos: photos, weights: weights)
        let pages = Dictionary(grouping: tiles, by: \.page)
        let atlasSize = 2048
        var result = SceneTextureProjection()
        for page in pages.keys.sorted() {
            try Task.checkCancellation()
            var bytes = [UInt8](repeating: 255, count: atlasSize * atlasSize * 4)
            var patch = SceneTexturePatch()
            for tile in pages[page, default: []] {
                let triangle = tile.triangle
                let tileSize = tile.size
                if triangle.isMultiple(of: 32) { try Task.checkCancellation() }
                let ids = (0..<3).map { Int(mesh.indices[triangle * 3 + $0]) }
                let a = mesh.positions[ids[0]], b = mesh.positions[ids[1]], c = mesh.positions[ids[2]]
                let area = simd_length(simd_cross(b - a, c - a)) / 2
                guard area > 1e-8 else { continue }
                let sources = Set(ids.flatMap { weights[$0].keys }).sorted()
                let originX = tile.x
                let originY = tile.y
                let gutter: Float = 1.5
                let span = Float(tileSize) - 2 * gutter
                let atlasUVs = [SIMD2(gutter, gutter), SIMD2(gutter + span, gutter), SIMD2(gutter, gutter + span)]
                patch.positions.append(contentsOf: [a, b, c])
                patch.textureCoordinates.append(contentsOf: atlasUVs.map {
                    SIMD2((Float(originX) + $0.x) / Float(atlasSize), 1 - (Float(originY) + $0.y) / Float(atlasSize))
                })
                var covered = 0
                var sampled = 0
                for y in 0..<tileSize {
                    for x in 0..<tileSize {
                        var wb = max(0, (Float(x) + 0.5 - gutter) / span)
                        var wc = max(0, (Float(y) + 0.5 - gutter) / span)
                        let interior = wb + wc <= 1 && Float(x) + 0.5 >= gutter && Float(y) + 0.5 >= gutter
                        if wb + wc > 1 {
                            let sum = wb + wc
                            wb /= sum
                            wc /= sum
                        }
                        let wa = 1 - wb - wc
                        let point = a * wa + b * wb + c * wc
                        var color = SIMD3<Float>.zero
                        var total: Float = 0
                        for source in sources {
                            let weight = (weights[ids[0]][source] ?? 0) * wa
                                + (weights[ids[1]][source] ?? 0) * wb
                                + (weights[ids[2]][source] ?? 0) * wc
                            guard weight > 0.0001, let uv = frames[source].project(point) else { continue }
                            color += photos[source].color(uv: uv) * gains[source] * weight
                            total += weight
                        }
                        if interior {
                            sampled += 1
                            if total > 0 { covered += 1 }
                        }
                        color = total > 0 ? color / total : SIMD3(repeating: 0.18)
                        let offset = ((originY + y) * atlasSize + originX + x) * 4
                        bytes[offset] = ScenePhotoPixels.encoded(color.x)
                        bytes[offset + 1] = ScenePhotoPixels.encoded(color.y)
                        bytes[offset + 2] = ScenePhotoPixels.encoded(color.z)
                    }
                }
                result.triangleCount += 1
                if covered > 0 { result.texturedTriangleCount += 1 }
                result.surfaceArea += Double(area)
                result.texturedArea += Double(area) * Double(covered) / Double(max(1, sampled))
            }
            let url = directory.appending(path: "Atlas-\(page).png")
            try write(bytes: bytes, size: atlasSize, url: url)
            result.patches[page] = patch
            result.atlasURLs[page] = url
        }
        return result
    }

    nonisolated private static func write(bytes: [UInt8], size: Int, url: URL) throws {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: size * 4, space: colorSpace,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw SceneTextureError.invalidPhoto
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw SceneTextureError.invalidPhoto }
    }
}
