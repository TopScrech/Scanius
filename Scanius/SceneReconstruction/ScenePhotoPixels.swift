import Foundation
import CoreGraphics
import ImageIO
import simd

struct ScenePhotoPixels: Sendable {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    nonisolated init(url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { throw SceneTextureError.invalidPhoto }
        width = image.width
        height = image.height
        var storage = [UInt8](repeating: 0, count: width * height * 4)
        let rendered = storage.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: image.width * 4, space: colorSpace,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard rendered else { throw SceneTextureError.invalidPhoto }
        bytes = storage
    }

    nonisolated func color(uv: SIMD2<Float>) -> SIMD3<Float> {
        let x = min(Float(width - 1), max(0, uv.x * Float(width) - 0.5))
        let y = min(Float(height - 1), max(0, (1 - uv.y) * Float(height) - 0.5))
        let ix = Int(x), iy = Int(y)
        let dx = x - Float(ix), dy = y - Float(iy)
        return pixel(ix, iy) * (1 - dx) * (1 - dy)
            + pixel(min(ix + 1, width - 1), iy) * dx * (1 - dy)
            + pixel(ix, min(iy + 1, height - 1)) * (1 - dx) * dy
            + pixel(min(ix + 1, width - 1), min(iy + 1, height - 1)) * dx * dy
    }

    nonisolated private func pixel(_ x: Int, _ y: Int) -> SIMD3<Float> {
        let offset = (y * width + x) * 4
        return SIMD3(Self.linear(bytes[offset]), Self.linear(bytes[offset + 1]), Self.linear(bytes[offset + 2]))
    }

    nonisolated static func linear(_ byte: UInt8) -> Float {
        let value = Float(byte) / 255
        return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    nonisolated static func encoded(_ value: Float) -> UInt8 {
        let clamped = min(1, max(0, value))
        let srgb = clamped <= 0.0031308 ? clamped * 12.92 : 1.055 * pow(clamped, 1 / 2.4) - 0.055
        return UInt8(clamping: Int((srgb * 255).rounded()))
    }
}
