import RoomPlan

@Observable
final class RoomPlanController: RoomCaptureViewDelegate, RoomCaptureSessionDelegate {
    static var instance = RoomPlanController()

    var roomCaptureView: RoomCaptureView
    private(set) var isSaving = false
    private(set) var savedURL: URL?
    private(set) var errorMessage: String?
    private var isSessionRunning = false

    var sessionConfig: RoomCaptureSession.Configuration
    var finalResult: CapturedRoom?

    init() {
        roomCaptureView = RoomCaptureView(frame: .init(x: 0, y: 0, width: 42, height: 42))
        sessionConfig = RoomCaptureSession.Configuration()
        roomCaptureView.captureSession.delegate = self
        roomCaptureView.delegate = self
    }

    func startSession() {
        finalResult = nil
        savedURL = nil
        errorMessage = nil
        isSaving = false
        isSessionRunning = true
        roomCaptureView.captureSession.run(configuration: sessionConfig)
    }

    func stopSession() {
        guard isSessionRunning else { return }
        isSessionRunning = false
        roomCaptureView.captureSession.stop(pauseARSession: true)
    }

    func cancel() {
        isSaving = false
        stopSession()
    }

    func save() {
        guard !isSaving else { return }
        errorMessage = nil
        isSaving = true

        if finalResult != nil {
            export()
        } else if isSessionRunning {
            stopSession()
        } else {
            isSaving = false
            errorMessage = "Unable to process this room — return to the list and start a new scan"
        }
    }

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        if let error {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }

        return true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        if let error {
            errorMessage = error.localizedDescription
            isSaving = false
            return
        }

        finalResult = processedResult
        if isSaving {
            export()
        }
    }

    private func export() {
        guard let finalResult else { return }
        defer { isSaving = false }

        guard let documentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appending(path: "Documents") else {
            errorMessage = "Sign in to iCloud to save room plans"
            return
        }

        let filename = "\(UUID().uuidString).usdz"
        let temporaryURL = URL.temporaryDirectory.appending(path: filename)
        let destinationURL = documentsURL.appending(path: filename)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        do {
            try finalResult.export(to: temporaryURL)
            try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
            try FileManager.default.setUbiquitous(true, itemAt: temporaryURL, destinationURL: destinationURL)
            savedURL = destinationURL
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    required init?(coder: NSCoder) {
        fatalError("Not needed.")
    }

    func encode(with coder: NSCoder) {
        fatalError("Not needed.")
    }
}
