#!/bin/zsh
set -eu
project_root="$(cd "$(dirname "$0")/.." && pwd)"
test_workspace="$(mktemp -d /tmp/scanius-texture-tests.XXXXXX)"
trap 'rm -rf "$test_workspace"' EXIT
mkdir -p "$test_workspace/Sources/SceneTexturing" "$test_workspace/Tests/SceneTexturingTests"
for source in SceneMesh SceneTextureFrame SceneTexturePatch SceneTextureProjection SceneMeshSmoothing ScenePhotoPixels ScenePhotoWeights SceneExposureCorrection SceneTextureBaker SceneTextureTile SceneAtlasLayout SceneTextureError SceneScanMode; do
    cp "$project_root/Scanius/SceneReconstruction/$source.swift" "$test_workspace/Sources/SceneTexturing/"
done
cp "$project_root/Tests/SceneTexturingTests.swift" "$test_workspace/Tests/SceneTexturingTests/"
cat > "$test_workspace/Package.swift" <<'PACKAGE'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "SceneTexturing",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "SceneTexturing"),
        .testTarget(name: "SceneTexturingTests", dependencies: ["SceneTexturing"])
    ]
)
PACKAGE
swift test --package-path "$test_workspace"
