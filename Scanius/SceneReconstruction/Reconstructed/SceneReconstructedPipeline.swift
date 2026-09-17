import Foundation

nonisolated struct SceneReconstructedPipeline {
    nonisolated static func process(frames: [SceneTextureFrame], directory: URL, archiveURL: URL?,
                                     progress: @Sendable (String) -> Void) throws -> SceneTextureProjection {
        guard frames.count >= 3 else { throw SceneReconstructionError.insufficientDepth }
        let archive = archiveURL ?? directory.appending(path: "Raw-Session.zip")
        progress("Preserving Raw Scan")
        let raw = try SceneRawSession.prepare(frames: frames, directory: directory)
        // Keep the original observations even when a later processing stage fails
        try SceneZIPWriter.write(directory: raw, to: archive)
        progress("Refining Camera Alignment")
        let alignment = try ScenePoseRefinement.refine(frames)
        var voxelSize: Float = 0.03
        var mesh: SceneMesh?
        for _ in 0..<4 {
            try Task.checkCancellation()
            progress("Reconstructing Surfaces")
            do {
                mesh = try SceneDepthFusion.reconstruct(frames: alignment.frames, voxelSize: voxelSize)
                break
            } catch SceneReconstructionError.capacity {
                voxelSize *= 1.5
            }
        }
        guard let mesh else { throw SceneReconstructionError.capacity }
        let report = SceneReconstructionReport(version: 1, voxelSizeMeters: voxelSize,
            registeredPairs: alignment.registeredPairs, loopClosures: alignment.loopClosures,
            triangles: mesh.indices.count / 3,
            correctedFrames: alignment.frames.enumerated().map { SceneRawFrameRecord(frame: $0.element, index: $0.offset) })
        try JSONEncoder().encode(report).write(to: raw.appending(path: "reconstruction.json"), options: .atomic)
        try SceneZIPWriter.write(directory: raw, to: archive)
        progress("Blending Surface Photos")
        // Bound decoded image memory while retaining coverage across the whole trajectory
        let stride = max(1, Int(ceil(Double(alignment.frames.count) / 48)))
        let photos = alignment.frames.indices.filter { $0.isMultiple(of: stride) }.map { start in
            alignment.frames[start..<min(start + stride, alignment.frames.count)].max { $0.photoQuality < $1.photoQuality }
                ?? alignment.frames[start]
        }
        // Fusion already regularizes the surface; avoid applying the separate smoothing mode again
        var result = try SceneTextureBaker.bake(meshes: [mesh], frames: photos, directory: directory, smooth: false)
        result.rawSessionURL = archive
        return result
    }
}
