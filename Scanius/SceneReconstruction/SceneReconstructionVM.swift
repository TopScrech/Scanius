import SwiftUI
import ARKit
import RealityKit
import AVFoundation
import CoreImage

@available(iOS 18, *)
@MainActor
@Observable
final class SceneReconstructionVM: NSObject, ARSessionDelegate {
    let session = ARSession()
    private(set) var meshCount = 0
    private(set) var isRunning = false
    private(set) var isSaving = false
    private(set) var resultURL: URL?
    private(set) var errorMessage: String?
    private(set) var trackingMessage = "Move slowly to scan walls, floors, and furniture"
    private(set) var textureFrameCount = 0
    private(set) var textureCoverage: Double?
    private(set) var saveMessage = "Saving Scan"
    private var textureFrames: [SceneTextureFrame] = []
    private let textureDirectory = URL.temporaryDirectory.appending(path: UUID().uuidString)
    private let imageContext = CIContext(options: [.cacheIntermediates: false])
    private var projectionTask: Task<SceneTextureProjection, Error>?
    private var started = false
    private var stopped = false
    private var isActive = true

    var isSupported: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    func run() async {
        guard isSupported, !started, !stopped else { return }
        started = true
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            errorMessage = "Allow camera access in Settings to scan spaces"
            return
        }
        guard !Task.isCancelled, !stopped else { return }
        session.delegate = self
        if isActive { resume() }

        while !Task.isCancelled, !stopped, resultURL == nil {
            if isRunning, let frame = session.currentFrame {
                meshCount = frame.anchors.compactMap { $0 as? ARMeshAnchor }.count
                switch frame.camera.trackingState {
                case .normal:
                    captureTexture(frame)
                    trackingMessage = textureFrameCount >= 120
                        ? "Photo limit reached — save this scan and start another for more space"
                        : "Move slowly and view each surface from several angles"
                case .limited:
                    trackingMessage = "Tracking is limited — move slowly toward an area already scanned"
                case .notAvailable:
                    trackingMessage = "Waiting for camera tracking"
                }
            }
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }
        }
    }

    func save() async {
        guard !isSaving, resultURL == nil, !stopped else { return }
        guard let anchors = session.currentFrame?.anchors.compactMap({ $0 as? ARMeshAnchor }), !anchors.isEmpty else {
            errorMessage = "Scan some surfaces before saving"
            return
        }
        guard let documents = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appending(path: "Documents") else {
            errorMessage = "Sign in to iCloud to save LiDAR meshes"
            return
        }

        if let frame = session.currentFrame { captureTexture(frame) }
        guard !textureFrames.isEmpty else {
            errorMessage = "No surface photos captured yet — move slowly in good light and try again"
            return
        }
        isSaving = true
        errorMessage = nil
        session.pause()
        isRunning = false
        let temporary = URL.temporaryDirectory.appending(path: "Mesh-\(UUID().uuidString).reality")
        defer {
            isSaving = false
            projectionTask = nil
            if stopped { clearTextures() }
            try? FileManager.default.removeItem(at: temporary)
        }

        do {
            let root = Entity()
            root.name = "LiDAR Scan"
            saveMessage = "Matching Photos to Surfaces"
            let meshes = anchors.map { SceneMesh(anchor: $0) }
            let frames = textureFrames
            let task = Task.detached(priority: .userInitiated) {
                try SceneTextureProjection.build(meshes: meshes, frames: frames)
            }
            projectionTask = task
            let projection = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            projectionTask = nil
            guard projection.texturedTriangleCount > 0 else {
                throw SceneTextureError.noCoverage
            }
            textureCoverage = Double(projection.texturedTriangleCount) / Double(projection.triangleCount)
            for (index, patch) in projection.patches.sorted(by: { $0.key < $1.key }) {
                try Task.checkCancellation()
                guard !stopped else { return }
                saveMessage = "Applying Surface Photos"
                var material = UnlitMaterial(applyPostProcessToneMap: false)
                material.faceCulling = .none
                if index >= 0 {
                    let texture = try await TextureResource(
                        contentsOf: frames[index].imageURL,
                        options: .init(semantic: .color)
                    )
                    material.color = .init(texture: .init(texture))
                } else {
                    material.color = .init(tint: .gray)
                }
                root.addChild(try patch.entity(material: material))
                await Task.yield()
            }
            saveMessage = "Saving Textured Scan"
            try await root.write(to: temporary)
            try Task.checkCancellation()
            guard !stopped else { return }
            try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
            let destination = documents.appending(path: temporary.lastPathComponent)
            try FileManager.default.setUbiquitous(true, itemAt: temporary, destinationURL: destination)
            resultURL = destination
            clearTextures()
        } catch {
            guard !stopped, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            if isActive { resume() }
        }
    }

    func updateScenePhase(_ phase: ScenePhase) {
        isActive = phase == .active
        guard started, !stopped, resultURL == nil, !isSaving,
              AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        if isActive {
            resume()
        } else {
            session.pause()
            isRunning = false
        }
    }

    var canResume: Bool {
        isActive && !isRunning && !isSaving && !stopped && resultURL == nil
            && AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    func resumeScanning() {
        guard canResume else { return }
        errorMessage = nil
        resume()
    }

    func stop() {
        stopped = true
        projectionTask?.cancel()
        session.pause()
        session.delegate = nil
        if !isSaving { clearTextures() }
        isRunning = false
    }

    private func captureTexture(_ frame: ARFrame) {
        guard !isSaving, textureFrames.count < 120,
              case .normal = frame.camera.trackingState else { return }
        if let last = textureFrames.last {
            let previous = last.cameraTransform
            let current = frame.camera.transform
            let moved = simd_distance(previous.columns.3, current.columns.3) > 0.15
            let turned = simd_dot(previous.columns.2, current.columns.2) < 0.985
            guard moved || turned else { return }
        }
        do {
            try FileManager.default.createDirectory(at: textureDirectory, withIntermediateDirectories: true)
            let url = textureDirectory.appending(path: "Photo-\(textureFrames.count).jpg")
            if let sample = try SceneTextureFrame(frame: frame, imageURL: url, context: imageContext) {
                textureFrames.append(sample)
                textureFrameCount = textureFrames.count
            }
        } catch {
            errorMessage = "Unable to capture surface photos: \(error.localizedDescription)"
        }
    }

    private func clearTextures() {
        textureFrames.removeAll()
        try? FileManager.default.removeItem(at: textureDirectory)
    }

    private func resume() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        configuration.frameSemantics.insert(.sceneDepth)
        session.run(configuration)
        isRunning = true
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            guard let self, !self.stopped else { return }
            self.errorMessage = message
            self.isRunning = false
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor [weak self] in
            guard let self, !self.stopped else { return }
            self.isRunning = false
            self.trackingMessage = "Scanning interrupted — keep this screen open to resume"
        }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor [weak self] in
            guard let self, self.isActive, !self.stopped, !self.isSaving, self.resultURL == nil else { return }
            self.resume()
        }
    }
}
