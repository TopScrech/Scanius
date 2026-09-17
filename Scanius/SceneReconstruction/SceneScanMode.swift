import Foundation

enum SceneScanMode: Sendable {
    case smoothed, original, reconstructed

    var title: String {
        switch self {
        case .smoothed: "LiDAR Mesh (Smoothed)"
        case .original: "LiDAR Mesh (Original)"
        case .reconstructed: "LiDAR Mesh (Reconstructed)"
        }
    }

    var filePrefix: String {
        switch self {
        case .smoothed: "Mesh-Smoothed"
        case .original: "Mesh-Original"
        case .reconstructed: "Mesh-Reconstructed"
        }
    }

    var processingMessage: String {
        switch self {
        case .smoothed: "Smoothing Surfaces and Blending Photos"
        case .original: "Matching Photos to Surfaces"
        case .reconstructed: "Reconstructing Surfaces from Depth"
        }
    }

    nonisolated func process(meshes: [SceneMesh], frames: [SceneTextureFrame], directory: URL,
                             archiveURL: URL? = nil, progress: @Sendable (String) -> Void = { _ in }) throws -> SceneTextureProjection {
        switch self {
        case .smoothed:
            return try SceneTextureBaker.bake(meshes: meshes, frames: frames, directory: directory)
        case .original:
            var result = try SceneTextureProjection.build(meshes: meshes, frames: frames)
            for index in result.patches.keys where index >= 0 {
                result.atlasURLs[index] = frames[index].imageURL
            }
            return result
        case .reconstructed:
            return try SceneReconstructedPipeline.process(frames: frames, directory: directory,
                                                           archiveURL: archiveURL, progress: progress)
        }
    }
}
