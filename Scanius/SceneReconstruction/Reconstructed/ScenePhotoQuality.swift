import Foundation

nonisolated struct ScenePhotoQuality {
    // Flat walls are useful depth observations even when they contain little image detail
    nonisolated static func measure(bytes: [UInt8], width: Int, height: Int) -> Float {
        guard width > 2, height > 2, bytes.count == width * height * 4 else { return 0 }
        let luminance = stride(from: 0, to: bytes.count, by: 4).map {
            Float(bytes[$0]) * 0.2126 + Float(bytes[$0 + 1]) * 0.7152 + Float(bytes[$0 + 2]) * 0.0722
        }
        let count = Float(luminance.count)
        let mean = luminance.reduce(0, +) / count
        guard mean > 8, mean < 247 else { return 0 }
        let variance = luminance.reduce(Float(0)) { $0 + ($1 - mean) * ($1 - mean) } / count
        var energy: Float = 0
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let i = y * width + x
                let laplacian = 4 * luminance[i] - luminance[i - 1] - luminance[i + 1]
                    - luminance[i - width] - luminance[i + width]
                energy += laplacian * laplacian
            }
        }
        energy /= Float((width - 2) * (height - 2))
        if variance < 100 { return 0.5 }
        // Prefer sharp texture sources while retaining depth from softly lit walls
        let relativeDetail = energy / max(variance, 1)
        return min(1, max(0.2, sqrt(relativeDetail) * 2))
    }
}
