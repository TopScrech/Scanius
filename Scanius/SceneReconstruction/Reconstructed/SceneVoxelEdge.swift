import simd

nonisolated struct SceneVoxelEdge: Hashable {
    let a: SIMD3<Int32>
    let b: SIMD3<Int32>

    nonisolated init(_ a: SIMD3<Int32>, _ b: SIMD3<Int32>) {
        let ascending = a.x != b.x ? a.x < b.x : (a.y != b.y ? a.y < b.y : a.z < b.z)
        self.a = ascending ? a : b
        self.b = ascending ? b : a
    }
}
