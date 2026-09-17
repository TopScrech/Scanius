import Foundation

nonisolated struct SceneRawFrameRecord: Codable {
    let image: String
    let depth: String
    let confidence: String
    let timestamp: Double
    let cameraToWorldColumnMajor: [Float]
    let intrinsicsColumnMajor: [Float]
    let intrinsicsReferenceWidth: Float
    let intrinsicsReferenceHeight: Float
    let depthWidth: Int
    let depthHeight: Int
    let photoQuality: Float

    nonisolated init(frame: SceneTextureFrame, index: Int) {
        image = "frame-\(index).jpg"
        depth = "depth-\(index).f32"
        confidence = "confidence-\(index).u8"
        timestamp = frame.timestamp
        cameraToWorldColumnMajor = (0..<4).flatMap { column in (0..<4).map { frame.cameraTransform[column][$0] } }
        intrinsicsColumnMajor = (0..<3).flatMap { column in (0..<3).map { frame.intrinsics[column][$0] } }
        intrinsicsReferenceWidth = frame.imageSize.x
        intrinsicsReferenceHeight = frame.imageSize.y
        depthWidth = frame.depthWidth
        depthHeight = frame.depthHeight
        photoQuality = frame.photoQuality
    }
}
