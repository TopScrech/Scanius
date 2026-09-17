import simd

nonisolated struct ScenePoseRefinement {
    nonisolated static func refine(_ frames: [SceneTextureFrame]) throws -> SceneAlignmentResult {
        guard frames.count > 1 else { return SceneAlignmentResult(frames: frames, registeredPairs: 0, loopClosures: 0) }
        var constraints: [ScenePoseConstraint] = []
        var registered = 0
        var loops = 0
        for source in 1..<frames.count {
            try Task.checkCancellation()
            // Retain odometry connections even when depth geometry cannot constrain alignment
            constraints.append(ScenePoseConstraint(target: source - 1, source: source,
                sourceToTarget: frames[source - 1].worldToCamera * frames[source].cameraTransform, weight: 0.25))
            for target in max(0, source - 2)..<source {
                if let match = try SceneDepthRegistration.align(source: frames[source], target: frames[target]) {
                    constraints.append(ScenePoseConstraint(target: target, source: source,
                        sourceToTarget: match.sourceToTarget, weight: match.overlap))
                    registered += 1
                }
            }
            guard source >= 12 else { continue }
            let position = SceneRigidMath.position(frames[source].cameraTransform)
            let candidates = (0..<(source - 10)).filter {
                simd_distance(position, SceneRigidMath.position(frames[$0].cameraTransform)) < 0.6
                    && simd_dot(frames[source].cameraTransform.columns.2, frames[$0].cameraTransform.columns.2) > 0.85
            }.sorted {
                simd_distance(position, SceneRigidMath.position(frames[$0].cameraTransform))
                    < simd_distance(position, SceneRigidMath.position(frames[$1].cameraTransform))
            }.prefix(2)
            for target in candidates {
                guard let match = try SceneDepthRegistration.align(source: frames[source], target: frames[target]),
                      match.overlap > 0.55, match.residual < 0.012,
                      match.normalDiversity > 0.002 else { continue }
                // Three-dimensional support is required to avoid false closures on blank planes
                constraints.append(ScenePoseConstraint(target: target, source: source,
                    sourceToTarget: match.sourceToTarget, weight: 2 * match.overlap))
                loops += 1
                break
            }
        }
        let originals = frames.map(\.cameraTransform)
        let poses = try optimize(originals, constraints: constraints)
        return SceneAlignmentResult(frames: zip(frames, poses).map { $0.aligned(to: $1) },
                                    registeredPairs: registered, loopClosures: loops)
    }

    nonisolated static func optimize(_ originals: [simd_float4x4], constraints: [ScenePoseConstraint]) throws -> [simd_float4x4] {
        var poses = originals
        guard !poses.isEmpty else { return poses }
        for _ in 0..<40 {
            try Task.checkCancellation()
            var translations = [SIMD3<Float>](repeating: .zero, count: poses.count)
            var rotations = translations
            var weights = [Float](repeating: 0.05, count: poses.count)
            for i in poses.indices {
                translations[i] = (SceneRigidMath.position(originals[i]) - SceneRigidMath.position(poses[i])) * 0.05
                rotations[i] = SceneRigidMath.rotationVector(SceneRigidMath.rotation(originals[i])
                    * SceneRigidMath.rotation(poses[i]).inverse) * 0.05
            }
            for edge in constraints {
                let desiredSource = poses[edge.target] * edge.sourceToTarget
                let desiredTarget = poses[edge.source] * edge.sourceToTarget.inverse
                for (index, desired) in [(edge.source, desiredSource), (edge.target, desiredTarget)] {
                    let displacement = SceneRigidMath.position(desired) - SceneRigidMath.position(poses[index])
                    let weight = edge.weight * min(1, 0.05 / max(simd_length(displacement), 1e-6))
                    translations[index] += displacement * weight
                    rotations[index] += SceneRigidMath.rotationVector(SceneRigidMath.rotation(desired)
                        * SceneRigidMath.rotation(poses[index]).inverse) * weight
                    weights[index] += weight
                }
            }
            for i in poses.indices where i != 0 {
                let position = SceneRigidMath.position(poses[i]) + translations[i] * (0.5 / weights[i])
                let delta = SceneRigidMath.transform(rotation: rotations[i] * (0.5 / weights[i]), translation: .zero)
                var proposed = delta * poses[i]
                proposed.columns.3 = SIMD4(position, 1)
                // Corrections are deliberately bounded; this is not a relocalization system
                if simd_distance(position, SceneRigidMath.position(originals[i])) < 0.15,
                   simd_length(SceneRigidMath.rotationVector(SceneRigidMath.rotation(proposed)
                       * SceneRigidMath.rotation(originals[i]).inverse)) < 0.1 {
                    poses[i] = proposed
                }
            }
        }
        return poses
    }
}
