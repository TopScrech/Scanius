import SwiftUI
import RealityKit

@MainActor
@Observable
final class ObjectCaptureVM {
    private(set) var session: ObjectCaptureSession?
    private(set) var isProcessing = false
    private(set) var progress = 0.0
    private(set) var resultURL: URL?
    private(set) var errorMessage: String?
    private(set) var detectionMessage: String?
    
    private var reconstruction: PhotogrammetrySession?
    private var stopped = false
    
    var isSupported: Bool {
        ObjectCaptureSession.isSupported && PhotogrammetrySession.isSupported
    }
    
    func run() async {
        guard isSupported, session == nil, !stopped else { return }
        
        let workspace = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let images = workspace.appending(path: "Images")
        let checkpoints = workspace.appending(path: "Checkpoints")
        
        do {
            guard let documents = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appending(path: "Documents") else {
                errorMessage = "Sign in to iCloud to save object captures"
                return
            }
            
            try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: checkpoints, withIntermediateDirectories: true)
            
            let capture = ObjectCaptureSession()
            session = capture
            var configuration = ObjectCaptureSession.Configuration()
            configuration.checkpointDirectory = checkpoints
            capture.start(imagesDirectory: images, configuration: configuration)
            
            for await state in capture.stateUpdates {
                guard !Task.isCancelled, !stopped else { return }
                
                switch state {
                case .completed:
                    session = nil
                    try await reconstruct(images: images, checkpoints: checkpoints, documents: documents, workspace: workspace)
                    return
                case .failed(let error):
                    throw error
                default:
                    break
                }
            }
        } catch {
            guard !Task.isCancelled, !stopped else { return }
            errorMessage = error.localizedDescription
            session?.cancel()
            session = nil
            reconstruction?.cancel()
            reconstruction = nil
            isProcessing = false
        }
    }
    
    func detectObject() {
        detectionMessage = session?.startDetecting() == true
            ? nil
            : "Keep the object in view and try detecting it again"
    }
    
    func startCapturing() {
        detectionMessage = nil
        session?.startCapturing()
    }
    
    func nextPass() {
        session?.beginNewScanPass()
    }
    
    func finish() {
        session?.finish()
    }
    
    func stop() {
        stopped = true
        session?.cancel()
        reconstruction?.cancel()
    }
    
    func updateScenePhase(_ phase: ScenePhase) {
        guard let session, !stopped else { return }
        
        switch session.state {
        case .ready, .detecting, .capturing:
            if phase == .active {
                session.resume()
            } else {
                session.pause()
            }
        default:
            break
        }
    }
    
    private func reconstruct(images: URL, checkpoints: URL, documents: URL, workspace: URL) async throws {
        isProcessing = true
        defer {
            isProcessing = false
            reconstruction = nil
        }
        
        let output = workspace.appending(path: "Object-\(UUID().uuidString).usdz")
        let configuration = PhotogrammetrySession.Configuration(checkpointDirectory: checkpoints)
        let processor = try PhotogrammetrySession(input: images, configuration: configuration)
        reconstruction = processor
        try processor.process(requests: [.modelFile(url: output, detail: .reduced)])
        
        for try await event in processor.outputs {
            try Task.checkCancellation()
            guard !stopped else { return }
            
            switch event {
            case .requestProgress(_, let fraction):
                progress = fraction
            case .requestError(_, let error):
                processor.cancel()
                throw error
            case .processingComplete:
                let destination = documents.appending(path: output.lastPathComponent)
                try FileManager.default.setUbiquitous(true, itemAt: output, destinationURL: destination)
                resultURL = destination
                try? FileManager.default.removeItem(at: workspace)
                return
            case .processingCancelled:
                return
            default:
                break
            }
        }
    }
}
