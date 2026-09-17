import ARKit
import CoreImage

extension SceneTextureFrame {
    init?(frame: ARFrame, imageURL: URL, context: CIContext, reconstructed: Bool = false) throws {
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
        timestamp = frame.timestamp
        if reconstructed {
            guard let confidence = frame.sceneDepth?.confidenceMap,
                  CVPixelBufferGetWidth(confidence) == depthWidth,
                  CVPixelBufferGetHeight(confidence) == depthHeight else { return nil }
            CVPixelBufferLockBaseAddress(confidence, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(confidence, .readOnly) }
            guard let confidenceBase = CVPixelBufferGetBaseAddress(confidence) else { return nil }
            let stride = CVPixelBufferGetBytesPerRow(confidence)
            confidences = (0..<depthHeight).flatMap { row in
                Array(UnsafeBufferPointer(start: confidenceBase.advanced(by: row * stride)
                    .assumingMemoryBound(to: UInt8.self), count: width))
            }
        }
        
        // Keep sensor orientation so the image and camera intrinsics share coordinates
        let image = CIImage(cvPixelBuffer: frame.capturedImage)
        let scale = min(1, 1024 / image.extent.width)
        let reduced = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        if reconstructed {
            let small = image.transformed(by: CGAffineTransform(scaleX: 128 / image.extent.width,
                                                               y: 128 / image.extent.width))
            let height = Int(small.extent.height)
            var pixels = [UInt8](repeating: 0, count: 128 * height * 4)
            pixels.withUnsafeMutableBytes {
                guard let base = $0.baseAddress else { return }
                context.render(small, toBitmap: base, rowBytes: 128 * 4,
                               bounds: CGRect(x: 0, y: 0, width: 128, height: height), format: .RGBA8, colorSpace: colorSpace)
            }
            let quality = ScenePhotoQuality.measure(bytes: pixels, width: 128, height: height)
            guard quality > 0 else { return nil }
            photoQuality = quality
        }
        try context.writeJPEGRepresentation(of: reduced, to: imageURL, colorSpace: colorSpace)
    }
}
