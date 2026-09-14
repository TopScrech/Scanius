import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Testing
import simd
@testable import SceneTexturing

private func frame(depth: Float = 2, cameraZ: Float = 0, url: URL = URL(filePath: "/tmp/test-photo.jpg")) -> SceneTextureFrame {
    var transform = matrix_identity_float4x4
    transform.columns.3.z = cameraZ
    return SceneTextureFrame(
        imageURL: url,
        cameraTransform: transform,
        worldToCamera: transform.inverse,
        intrinsics: simd_float3x3(SIMD3(100, 0, 0), SIMD3(0, 100, 0), SIMD3(50, 50, 1)),
        imageSize: SIMD2(100, 100),
        depths: Array(repeating: depth, count: 100),
        depthWidth: 10,
        depthHeight: 10
    )
}

@Test func projectsSensorCoordinatesIntoTextureUVs() throws {
    let uv = try #require(frame().project(SIMD3(-0.2, 0.2, -2)))
    #expect(abs(uv.x - 0.4) < 0.0001)
    #expect(abs(uv.y - 0.6) < 0.0001)
}

@Test func rejectsOccludedAndInvisibleSurfaces() {
    #expect(frame(depth: 1).project(SIMD3(0, 0, -2)) == nil)
    #expect(frame(depth: .nan).project(SIMD3(0, 0, -2)) == nil)
    #expect(frame().project(SIMD3(0, 0, 2)) == nil)
    #expect(frame().project(SIMD3(3, 0, -2)) == nil)
}

@Test func transformsWorldPositionsIntoCameraSpace() throws {
    let uv = try #require(frame(depth: 3, cameraZ: 1).project(SIMD3(0, 0, -2)))
    #expect(uv == SIMD2(0.5, 0.5))
}

@Test func selectsUnoccludedPhotoAndPreservesUncoveredGeometry() throws {
    let mesh = SceneMesh(
        positions: [SIMD3(-0.2, -0.2, -2), SIMD3(0.2, -0.2, -2), SIMD3(0, 0.2, -2),
                    SIMD3(3, 0, -2), SIMD3(4, 0, -2), SIMD3(3, 1, -2)],
        indices: [0, 1, 2, 3, 4, 5]
    )
    let result = try SceneTextureProjection.build(meshes: [mesh], frames: [frame(depth: 1), frame()])
    #expect(result.triangleCount == 2)
    #expect(result.texturedTriangleCount == 1)
    #expect(result.patches[0] == nil)
    #expect(result.patches[1]?.positions.count == 3)
    #expect(result.patches[-1]?.positions.count == 3)
    #expect(result.patches[1]?.textureCoordinates.count == 3)
}

@Test func handlesNoPhotosWithoutInventingTextureCoverage() throws {
    let mesh = SceneMesh(
        positions: [SIMD3(-0.2, -0.2, -2), SIMD3(0.2, -0.2, -2), SIMD3(0, 0.2, -2)],
        indices: [0, 1, 2]
    )
    let result = try SceneTextureProjection.build(meshes: [mesh], frames: [])
    #expect(result.texturedTriangleCount == 0)
    #expect(result.patches[-1]?.positions.count == 3)
}

private func photo(url: URL, width: Int = 32, height: Int = 32, pixel: (Int, Int) -> [UInt8]) throws {
    var bytes: [UInt8] = []
    for y in 0..<height {
        for x in 0..<width {
            bytes.append(contentsOf: pixel(x, y))
            bytes.append(255)
        }
    }
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
    let image = try #require(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                    bytesPerRow: width * 4, space: space,
                                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                    provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent))
    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
}

private func workspace() throws -> URL {
    let url = URL.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func smoothsSmallBumpsWithoutMovingOpenBoundaries() throws {
    let mesh = SceneMesh(
        positions: [SIMD3(-0.04, -0.04, 0), SIMD3(0.04, -0.04, 0),
                    SIMD3(0.04, 0.04, 0), SIMD3(-0.04, 0.04, 0), SIMD3(0, 0, 0.003)],
        indices: [0, 1, 4, 1, 2, 4, 2, 3, 4, 3, 0, 4]
    )
    let result = try SceneMeshSmoothing.prepare([mesh])
    #expect(abs(result.positions[4].z) < 0.003)
    for i in 0..<4 { #expect(result.positions[i] == mesh.positions[i]) }
    #expect(result.indices == mesh.indices)
}

@Test func weldsSharedAnchorBoundariesBeforeSmoothing() throws {
    let a = SceneMesh(positions: [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(1, 1, 0)], indices: [0, 1, 2])
    let b = SceneMesh(positions: [SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(0, 1, 0)], indices: [0, 1, 2])
    let result = try SceneMeshSmoothing.prepare([a, b])
    #expect(result.positions.count == 4)
    #expect(result.indices.count == 6)
    #expect(result.positions.allSatisfy { $0.z == 0 })
}

@Test func coverageUsesSurfaceAreaInsteadOfTriangleCount() throws {
    let mesh = SceneMesh(
        positions: [SIMD3(-0.1, -0.1, -2), SIMD3(0.1, -0.1, -2), SIMD3(0, 0.1, -2),
                    SIMD3(3, 0, -2), SIMD3(5, 0, -2), SIMD3(3, 2, -2)],
        indices: [0, 1, 2, 3, 4, 5]
    )
    let result = try SceneTextureProjection.build(meshes: [mesh], frames: [frame()])
    #expect(result.texturedTriangleCount == 1)
    #expect(result.texturedArea / result.surfaceArea < 0.02)
}

@Test func photoDecodePreservesTopAndBottomOrientation() throws {
    let directory = try workspace()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "orientation.png")
    try photo(url: url) { _, y in y < 16 ? [255, 0, 0] : [0, 0, 255] }
    let image = try ScenePhotoPixels(url: url)
    #expect(image.color(uv: SIMD2(0.5, 1)).x > 0.99)
    #expect(image.color(uv: SIMD2(0.5, 0)).z > 0.99)
}

@Test func exposureMatchingReducesBrightnessDifferenceOnSharedSurfaces() throws {
    let directory = try workspace()
    defer { try? FileManager.default.removeItem(at: directory) }
    let a = directory.appending(path: "dark.png"), b = directory.appending(path: "bright.png")
    try photo(url: a) { _, _ in [140, 140, 140] }
    try photo(url: b) { _, _ in [165, 165, 165] }
    let frames = [frame(url: a), frame(url: b)]
    let photos = try [a, b].map { try ScenePhotoPixels(url: $0) }
    let mesh = SceneMesh(positions: (0..<20).map { SIMD3(Float($0) * 0.01, 0, -2) }, indices: [])
    let weights = Array(repeating: [0: Float(0.5), 1: Float(0.5)], count: 20)
    let gains = try SceneExposureCorrection.gains(mesh: mesh, frames: frames, photos: photos, weights: weights)
    let ca = photos[0].color(uv: SIMD2(0.5, 0.5)), cb = photos[1].color(uv: SIMD2(0.5, 0.5))
    #expect(simd_length(ca * gains[0] - cb * gains[1]) < simd_length(ca - cb) * 0.5)
}

@Test func bakesContinuousColorsAcrossAdjacentTriangleCharts() throws {
    let directory = try workspace()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "gradient.png")
    try photo(url: url) { x, y in [UInt8(50 + x * 5), UInt8(50 + y * 5), 80] }
    let mesh = SceneMesh(
        positions: [SIMD3(-0.4, -0.4, -2), SIMD3(0.4, -0.4, -2), SIMD3(0.4, 0.4, -2), SIMD3(-0.4, 0.4, -2)],
        indices: [0, 1, 2, 0, 2, 3]
    )
    let result = try SceneScanMode.smoothed.process(meshes: [mesh], frames: [frame(url: url)], directory: directory)
    #expect(result.texturedArea / result.surfaceArea > 0.99)
    let patch = try #require(result.patches[0])
    let atlas = try ScenePhotoPixels(url: #require(result.atlasURLs[0]))
    let uvA = (patch.textureCoordinates[0] + patch.textureCoordinates[2]) / 2
    let uvB = (patch.textureCoordinates[3] + patch.textureCoordinates[4]) / 2
    #expect(simd_length(atlas.color(uv: uvA) - atlas.color(uv: uvB)) < 0.025)
    #expect(atlas.color(uv: uvA).x > 0.05)
}

@Test func blendsOverlappingPhotosInLinearColorSpace() throws {
    let directory = try workspace()
    defer { try? FileManager.default.removeItem(at: directory) }
    let red = directory.appending(path: "red.png"), blue = directory.appending(path: "blue.png")
    try photo(url: red) { _, _ in [255, 0, 0] }
    try photo(url: blue) { _, _ in [0, 0, 255] }
    let mesh = SceneMesh(
        positions: [SIMD3(-0.4, -0.4, -2), SIMD3(0.4, -0.4, -2), SIMD3(0, 0.4, -2)],
        indices: [0, 1, 2]
    )
    let result = try SceneTextureBaker.bake(meshes: [mesh], frames: [frame(url: red), frame(url: blue)], directory: directory)
    let patch = try #require(result.patches[0])
    let atlas = try ScenePhotoPixels(url: #require(result.atlasURLs[0]))
    let center = patch.textureCoordinates.reduce(SIMD2<Float>.zero, +) / 3
    let color = atlas.color(uv: center)
    #expect(abs(color.x - 0.5) < 0.02)
    #expect(color.y < 0.01)
    #expect(abs(color.z - 0.5) < 0.02)
}

@Test func originalModePreservesGeometryAndUsesUnblendedPhotos() throws {
    let mesh = SceneMesh(
        positions: [SIMD3(-0.2, -0.2, -2), SIMD3(0.2, -0.2, -2), SIMD3(0, 0.2, -1.997)],
        indices: [0, 1, 2]
    )
    let sample = frame()
    let result = try SceneScanMode.original.process(meshes: [mesh], frames: [sample], directory: .temporaryDirectory)
    let patch = try #require(result.patches[0])
    #expect(patch.positions == mesh.positions)
    #expect(result.atlasURLs[0] == sample.imageURL)
}
