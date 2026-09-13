import Foundation
import Testing
import simd
@testable import SceneTexturing

private func frame(depth: Float = 2, cameraZ: Float = 0) -> SceneTextureFrame {
    var transform = matrix_identity_float4x4
    transform.columns.3.z = cameraZ
    return SceneTextureFrame(
        imageURL: URL(filePath: "/tmp/test-photo.jpg"),
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
