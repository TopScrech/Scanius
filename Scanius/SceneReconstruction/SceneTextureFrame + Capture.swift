import ARKit
import CoreImage

extension SceneTextureFrame {
    init?(frame: ARFrame, imageURL: URL, context: CIContext) throws {
        guard let depthMap = frame.sceneDepth?.depthMap else { return nil }
        cameraTransform = frame.camera.transform
        worldToCamera = frame.camera.transform.inverse
        intrinsics = frame.camera.intrinsics
        imageSize = SIMD2(Float(frame.camera.imageResolution.width), Float(frame.camera.imageResolution.height))
        self.imageURL = imageURL
        depthWidth = CVPixelBufferGetWidth(depthMap)
        depthHeight = CVPixelBufferGetHeight(depthMap)
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let rowBytes = CVPixelBufferGetBytesPerRow(depthMap)
        let width = depthWidth
        depths = (0..<depthHeight).flatMap { row in
            let values = base.advanced(by: row * rowBytes).assumingMemoryBound(to: Float.self)
            return Array(UnsafeBufferPointer(start: values, count: width))
        }
        
        // Keep sensor orientation so the image and camera intrinsics share coordinates
        let image = CIImage(cvPixelBuffer: frame.capturedImage)
        let scale = min(1, 1024 / image.extent.width)
        let reduced = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        try context.writeJPEGRepresentation(of: reduced, to: imageURL, colorSpace: colorSpace)
    }
}
