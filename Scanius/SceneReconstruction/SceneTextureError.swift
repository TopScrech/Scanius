import Foundation

enum SceneTextureError: LocalizedError {
    case noCoverage

    var errorDescription: String? {
        "No photos matched the scanned surfaces — scan them again slowly in good light before saving"
    }
}
