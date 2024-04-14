import RoomPlan

@Observable
final class RoomPlanController: RoomCaptureViewDelegate, RoomCaptureSessionDelegate {
    static var instance = RoomPlanController()
    
    var roomCaptureView: RoomCaptureView
    var showExportButton = false
    var showShareSheet = false
    var exportUrl: URL?
    
    var sessionConfig: RoomCaptureSession.Configuration
    var finalResult: CapturedRoom?
    
    init() {
        roomCaptureView = RoomCaptureView(frame: .init(x: 0, y: 0, width: 42, height: 42))
        sessionConfig = RoomCaptureSession.Configuration()
        roomCaptureView.captureSession.delegate = self
        roomCaptureView.delegate = self
    }
    
    func startSession() {
        roomCaptureView.captureSession.run(configuration: sessionConfig)
    }
    
    func stopSession() {
        roomCaptureView.captureSession.stop(pauseARSession: false)
    }
    
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        true
    }
    
    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        finalResult = processedResult
    }
    
    func export() {
        guard let finalResult else {
            print("Error: final result is not available.")
            return
        }
        
        let filename = "\(UUID().uuidString).usdz"
        exportUrl = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try finalResult.export(to: exportUrl!)
        } catch {
            print("Error exporting usdz scan")
            return
        }
        
        guard FileManager.default.fileExists(atPath: exportUrl!.path) else {
            print("File doesn't exist at the export URL")
            return
        }
        
        // Get the iCloud container URL
        guard let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") else {
            print("Unable to access iCloud account")
            return
        }
        
        // Create the "Documents" directory in iCloud if it doesn't already exist
        do {
            try FileManager.default.createDirectory(at: iCloudDocumentsURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating iCloud Documents directory: \(error)")
            return
        }
        
        // Define the destination URL in iCloud
        let iCloudDestinationURL = iCloudDocumentsURL.appendingPathComponent(filename)
        
        // Move the file to iCloud
        do {
            try FileManager.default.setUbiquitous(true, itemAt: exportUrl!, destinationURL: iCloudDestinationURL)
        } catch {
            print("Error moving file to iCloud: \(error)")
            return
        }
        
        showShareSheet = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not needed.")
    }
    
    func encode(with coder: NSCoder) {
        fatalError("Not needed.")
    }
}
