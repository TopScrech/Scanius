import Foundation
import Testing
import simd
@testable import SceneTexturing

private func depthFrame(depth: Float = 2, pose: simd_float4x4 = matrix_identity_float4x4,
                        confidence: UInt8 = 2, corner: Bool = false) -> SceneTextureFrame {
    let width = 96, height = 72
    let focal: Float = 90
    var depths: [Float] = []
    for y in 0..<height {
        for x in 0..<width {
            let ray = SIMD3((Float(x) + 0.5 - Float(width) / 2) / focal,
                            (Float(height) / 2 - Float(y) - 0.5) / focal, -1)
            var distance = depth
            if corner {
                if ray.x > 0 { distance = min(distance, 0.65 / ray.x) }
                if ray.y < 0 { distance = min(distance, -0.45 / ray.y) }
            }
            depths.append(distance)
        }
    }
    var frame = SceneTextureFrame(imageURL: URL(filePath: "/tmp/source.jpg"), cameraTransform: pose,
        worldToCamera: pose.inverse,
        intrinsics: simd_float3x3(SIMD3(focal, 0, 0), SIMD3(0, focal, 0), SIMD3(Float(width) / 2, Float(height) / 2, 1)),
        imageSize: SIMD2(Float(width), Float(height)), depths: depths, depthWidth: width, depthHeight: height)
    frame.confidences = [UInt8](repeating: confidence, count: depths.count)
    return frame
}

@Test func rejectsLowConfidenceDepthAndKeepsCameraConvention() throws {
    let sample = depthFrame()
    let p = try #require(SceneDepthGeometry.point(frame: sample, x: 47, y: 35))
    #expect(p.x < 0 && p.y > 0 && p.z == -2)
    let pixel = try #require(SceneDepthGeometry.pixel(frame: sample, point: p))
    #expect(pixel == SIMD2(47, 35))
    let normal = try #require(SceneDepthGeometry.sample(frame: sample, x: 47, y: 35)).normal
    #expect(normal.z > 0.99)
    #expect(SceneDepthGeometry.point(frame: depthFrame(confidence: 0), x: 47, y: 35) == nil)
    #expect(depthFrame(confidence: 0).project(p) == nil)
}

@Test func refinesSmallDepthAlignmentError() throws {
    let target = depthFrame(corner: true)
    let pose = SceneRigidMath.transform(rotation: SIMD3(0.006, -0.005, 0.004), translation: SIMD3(0.015, -0.012, 0.02))
    let source = depthFrame(pose: pose, corner: true)
    let result = try #require(try SceneDepthRegistration.align(source: source, target: target))
    #expect(simd_length(SceneRigidMath.position(result.sourceToTarget)) < 0.008)
    #expect(simd_length(SceneRigidMath.rotationVector(SceneRigidMath.rotation(result.sourceToTarget))) < 0.006)
    #expect(result.residual < 0.005)
    #expect(result.normalDiversity > 0.002)
}

@Test func doesNotInventRegistrationForNonoverlappingFrames() throws {
    var pose = matrix_identity_float4x4
    pose.columns.3.x = 10
    #expect(try SceneDepthRegistration.align(source: depthFrame(pose: pose), target: depthFrame()) == nil)
}

@Test func planarObservationsDoNotBecomeLoopClosures() throws {
    let result = try ScenePoseRefinement.refine(Array(repeating: depthFrame(), count: 13))
    #expect(result.registeredPairs > 0)
    #expect(result.loopClosures == 0)
    #expect(result.frames.allSatisfy { simd_length(SceneRigidMath.position($0.cameraTransform)) < 0.0001 })
}

@Test func globalPoseConstraintsDistributeCorrectionAndKeepFirstPoseFixed() throws {
    var second = matrix_identity_float4x4
    second.columns.3.x = 0.025
    var third = matrix_identity_float4x4
    third.columns.3.x = 0.05
    let originals = [matrix_identity_float4x4, second, third]
    let edges = [ScenePoseConstraint(target: 0, source: 1, sourceToTarget: second, weight: 1),
                 ScenePoseConstraint(target: 1, source: 2, sourceToTarget: second, weight: 1),
                 ScenePoseConstraint(target: 0, source: 2, sourceToTarget: matrix_identity_float4x4, weight: 4)]
    let corrected = try ScenePoseRefinement.optimize(originals, constraints: edges)
    #expect(corrected[0] == originals[0])
    #expect(corrected[2].columns.3.x < 0.02)
    #expect(corrected[1].columns.3.x < second.columns.3.x)
}

@Test func fusesDepthIntoAccurateOrientedSurfaceAcrossBlockBoundaries() throws {
    let samples = [depthFrame(depth: 1.996), depthFrame(depth: 2.004), depthFrame(depth: 2)]
    let mesh = try SceneDepthFusion.reconstruct(frames: samples, voxelSize: 0.06)
    #expect(mesh.indices.count > 300)
    #expect(mesh.positions.allSatisfy { abs($0.z + 2) < 0.006 })
    #expect(mesh.positions.contains { $0.x < 0 } && mesh.positions.contains { $0.x > 0 })
    for offset in stride(from: 0, to: mesh.indices.count, by: 3) {
        let a = mesh.positions[Int(mesh.indices[offset])]
        let b = mesh.positions[Int(mesh.indices[offset + 1])]
        let c = mesh.positions[Int(mesh.indices[offset + 2])]
        #expect(simd_cross(b - a, c - a).z > 0)
    }
}

@Test func reconstructionRequiresRepeatedReliableObservations() throws {
    #expect(throws: SceneReconstructionError.self) {
        try SceneDepthFusion.reconstruct(frames: [depthFrame()], voxelSize: 0.06)
    }
    #expect(throws: SceneReconstructionError.self) {
        try SceneDepthFusion.reconstruct(frames: [depthFrame(), depthFrame(confidence: 0), depthFrame(confidence: 0)], voxelSize: 0.06)
    }
    #expect(throws: SceneReconstructionError.self) {
        try SceneDepthFusion.reconstruct(frames: Array(repeating: depthFrame(), count: 3), voxelSize: 0.06, maximumBlocks: 1)
    }
}

@Test func reconstructionHonorsCancellation() async {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try SceneDepthFusion.reconstruct(frames: Array(repeating: depthFrame(), count: 3))
    }
    do {
        _ = try await task.value
        Issue.record("Expected cancellation")
    } catch {
        #expect(error is CancellationError)
    }
}

@Test func photoQualityRetainsBlankWallsAndRejectsUnusableExposure() {
    let width = 32, height = 24
    let gray: [UInt8] = Array(repeating: [UInt8(128), 128, 128, 255], count: width * height).flatMap { $0 }
    let black = [UInt8](repeating: 0, count: width * height * 4)
    #expect(ScenePhotoQuality.measure(bytes: gray, width: width, height: height) > 0)
    #expect(ScenePhotoQuality.measure(bytes: black, width: width, height: height) == 0)
    var sharp: [UInt8] = [], soft: [UInt8] = []
    for _ in 0..<height {
        for x in 0..<width {
            let a: UInt8 = x < width / 2 ? 60 : 190
            let b = UInt8(60 + x * 4)
            sharp.append(contentsOf: [a, a, a, 255])
            soft.append(contentsOf: [b, b, b, 255])
        }
    }
    #expect(ScenePhotoQuality.measure(bytes: sharp, width: width, height: height)
        > ScenePhotoQuality.measure(bytes: soft, width: width, height: height))
}

@Test func rawSessionZIPCanBeReadByStandardToolsAndReplaced() throws {
    let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    var sample = depthFrame()
    let image = directory.appending(path: "photo.jpg")
    try Data([1, 2, 3, 4]).write(to: image)
    sample = SceneTextureFrame(imageURL: image, cameraTransform: sample.cameraTransform,
        worldToCamera: sample.worldToCamera, intrinsics: sample.intrinsics, imageSize: sample.imageSize,
        depths: sample.depths, depthWidth: sample.depthWidth, depthHeight: sample.depthHeight,
        confidences: sample.confidences)
    let raw = try SceneRawSession.prepare(frames: [sample], directory: directory)
    let archive = directory.appending(path: "test.zip")
    try SceneZIPWriter.write(directory: raw, to: archive)
    try Data("second pass".utf8).write(to: raw.appending(path: "report.txt"))
    try SceneZIPWriter.write(directory: raw, to: archive)
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/unzip")
    process.arguments = ["-p", archive.path, "manifest.json"]
    let pipe = Pipe()
    process.standardOutput = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)
    let manifest = try JSONDecoder().decode(SceneRawManifest.self, from: data)
    #expect(manifest.frames.count == 1)
    #expect(manifest.frames[0].depthWidth == sample.depthWidth)
    let verify = Process()
    verify.executableURL = URL(filePath: "/usr/bin/unzip")
    verify.arguments = ["-tqq", archive.path]
    try verify.run()
    verify.waitUntilExit()
    #expect(verify.terminationStatus == 0)
}

@Test func acceptsRevisitedCornerWithThreeDimensionalSupport() throws {
    let result = try ScenePoseRefinement.refine(Array(repeating: depthFrame(corner: true), count: 13))
    #expect(result.loopClosures == 1)
    #expect(result.frames.allSatisfy { simd_length(SceneRigidMath.position($0.cameraTransform)) < 0.001 })
}

@Test func stopsMeshingAtItsTriangleBudget() throws {
    #expect(throws: SceneReconstructionError.self) {
        try SceneDepthFusion.reconstruct(frames: Array(repeating: depthFrame(), count: 3), voxelSize: 0.06, maximumTriangles: 1)
    }
}
