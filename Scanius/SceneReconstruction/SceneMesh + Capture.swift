import ARKit

extension SceneMesh {
    init(anchor: ARMeshAnchor) {
        let geometry = anchor.geometry
        let vertices = geometry.vertices
        positions = (0..<vertices.count).map { index in
            let pointer = vertices.buffer.contents().advanced(by: vertices.offset + index * vertices.stride)
            let x = pointer.load(as: Float.self)
            let y = pointer.advanced(by: 4).load(as: Float.self)
            let z = pointer.advanced(by: 8).load(as: Float.self)
            let world = anchor.transform * SIMD4(x, y, z, 1)
            return SIMD3(world.x, world.y, world.z)
        }

        let faces = geometry.faces
        indices = (0..<(faces.count * faces.indexCountPerPrimitive)).map { index in
            let pointer = faces.buffer.contents().advanced(by: index * faces.bytesPerIndex)
            if faces.bytesPerIndex == 2 {
                return UInt32(pointer.load(as: UInt16.self))
            }
            return pointer.load(as: UInt32.self)
        }
    }

}
