# LiDAR reconstruction mode

New Scan → LiDAR Mesh (Reconstructed) runs a separate native processing pipeline

The Original and Smoothed modes keep their existing processing behavior, and all three modes use the existing ARKit wireframe preview

## Relationship to Polycam

This is Scanius code inspired by public technical disclosures, not Polycam's implementation or SDK

Polycam documents ARKit depth/confidence capture, camera pose optimization before mesh reconstruction, and image undistortion in its [Polyform README](https://github.com/PolyCam/polyform)

Polycam exposes depth range, voxel size and pre-texturing simplification in its [Space Mode documentation](https://learn.poly.cam/hc/en-us/articles/36655587097620-How-to-Use-Space-Mode-LiDAR-Devices)

Their exact meshing, alignment and texture optimization algorithms are not disclosed by those sources

## Pipeline

1. Capture up to 120 keyframes using the existing movement/rotation criteria, with original ARKit scene depth, confidence, camera intrinsics, camera pose and timestamp
2. Prefer sharper photos, reject unusable exposure and fast motion between nearby accepted keyframes, and retain low-texture views for their depth observations
3. Archive raw inputs before reconstruction so failures after that point do not discard the observations
4. Refine neighboring frames using robust projective point-to-plane ICP, initialized from ARKit poses
5. Add conservative loop constraints for nearby revisits with sufficient overlap and three-dimensional normal support, then distribute corrections through a pose graph anchored at the first frame
6. Fuse aligned depth into a sparse, confidence- and incidence-weighted truncated signed distance field
7. Extract the zero surface with marching tetrahedra, sharing edge vertices across voxel blocks and requiring at least two depth observations
8. Bake the existing exposure-corrected photographic textures using corrected poses, without the Smoothed mode's additional bilateral displacement passes
9. Save the textured RealityKit model and its raw ZIP companion to iCloud

## Limits and behavior

- This is bounded depth-based pose refinement, not feature-based global relocalization or full photogrammetric bundle adjustment
- The implementation does not add lens-distortion calibration or image undistortion
- Loop candidates must already be within 0.6 m and face similar directions; blank planes cannot establish loop closures
- Corrections are bounded to 15 cm and approximately 5.7 degrees relative to ARKit's original pose
- Reconstruction starts at 3 cm voxels, with a 3-voxel truncation band
- A 4096-block / 100,000-triangle budget bounds reconstruction memory; capacity failures retry at 4.5, 6.75 and 10.125 cm voxels, then return an error
- The effective voxel size, accepted alignment pairs, loop count and corrected poses are recorded in reconstruction.json
- Texture decoding is limited to at most 48 photos selected across the trajectory; original capture photos remain in the ZIP
- Low-confidence samples, large depth discontinuities and geometry seen only once are omitted, so thin objects and poorly covered areas may be incomplete
- No automatic hole filling, learned geometry inference or fidelity guarantee is provided
- Physical iPhone/iPad testing is still required to assess scan quality, latency, memory pressure and thermal behavior

## Raw session format

The ZIP uses standard uncompressed ZIP entries and streaming CRC-32 checksums

- manifest.json: versioned metadata and original camera poses
- frame-N.jpg: sensor-oriented, downscaled camera image
- depth-N.f32: row-major Float32 little-endian camera-Z depth in meters
- confidence-N.u8: row-major ARKit confidence, 0 low / 1 medium / 2 high
- reconstruction.json: processing report and corrected poses, included after successful reconstruction

Matrices are column-major, world coordinates use meters, +Y is up and the camera looks along -Z

Camera intrinsics reference the original captured-image dimensions in the manifest; scale them for decoded JPEG or depth dimensions

Failed or interrupted processing after initial archival leaves a local ZIP under Documents/Raw Sessions, accessible from the scan list's Raw Sessions on This Device section

Successful processing moves the ZIP into the iCloud Raw Sessions folder beside the model's parent directory; Export Raw Session is available from the result and saved scan

Deleting a saved scan also removes its associated iCloud raw archive

## Verification

Tests/run-scene-texture-tests.sh runs Swift Testing on macOS without launching an iOS simulator

Coverage includes pose correction, conservative loop acceptance/rejection, depth coordinate conventions, confidence filtering, noise fusion, face orientation, capacity limits, cancellation, photo weighting, archive compatibility and failure retention, and the full third-mode pipeline independent of ARKit mesh geometry
