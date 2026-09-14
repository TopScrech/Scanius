import Foundation

enum SceneScanMode: Sendable {
    case smoothed, original

    var title: String {
        switch self {
        case .smoothed: "LiDAR Mesh (Smoothed)"
        case .original: "LiDAR Mesh (Original)"
        }
    }

    var filePrefix: String {
        self == .smoothed ? "Mesh-Smoothed" : "Mesh-Original"
    }

    var processingMessage: String {
        self == .smoothed ? "Smoothing Surfaces and Blending Photos" : "Matching Photos to Surfaces"
    }

    nonisolated func process(meshes: [SceneMesh], frames: [SceneTextureFrame], directory: URL) throws -> SceneTextureProjection {
        switch self {
        case .smoothed:
            return try SceneTextureBaker.bake(meshes: meshes, frames: frames, directory: directory)
        case .original:
            var result = try SceneTextureProjection.build(meshes: meshes, frames: frames)
            for index in result.patches.keys where index >= 0 {
                result.atlasURLs[index] = frames[index].imageURL
            }
            return result
        }
    }
}
