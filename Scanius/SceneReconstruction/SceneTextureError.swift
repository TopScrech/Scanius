import Foundation

enum SceneTextureError: LocalizedError {
    case noCoverage, invalidPhoto, scanTooLarge

    var errorDescription: String? {
        switch self {
        case .noCoverage:
            "No photos matched the scanned surfaces — scan them again slowly in good light before saving"
        case .scanTooLarge:
            "This scan is too large to texture safely — capture smaller sections separately"
        case .invalidPhoto:
            "Unable to read or save a surface photo — check available storage and try again"
        }
    }
}
