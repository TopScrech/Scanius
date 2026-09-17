import Foundation

enum SceneReconstructionError: LocalizedError {
    case insufficientDepth, noSurface, capacity, archiveFailed

    var errorDescription: String? {
        switch self {
        case .insufficientDepth: "Capture at least three clear depth views — move slowly around the surfaces"
        case .noSurface: "Not enough overlapping depth observations — scan each surface from several nearby viewpoints"
        case .capacity: "This space exceeds the reconstruction limit — scan smaller sections separately"
        case .archiveFailed: "Unable to save the raw scan session — check available storage and try again"
        }
    }
}
