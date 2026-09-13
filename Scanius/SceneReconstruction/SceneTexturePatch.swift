import RealityKit

struct SceneTexturePatch: Sendable {
    var positions: [SIMD3<Float>] = []
    var textureCoordinates: [SIMD2<Float>] = []

    @MainActor
    func entity(material: UnlitMaterial) throws -> ModelEntity {
        var descriptor = MeshDescriptor()
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(textureCoordinates)
        descriptor.primitives = .triangles((0..<positions.count).map(UInt32.init))
        let mesh = try MeshResource.generate(from: [descriptor])
        return ModelEntity(mesh: mesh, materials: [material])
    }
}
