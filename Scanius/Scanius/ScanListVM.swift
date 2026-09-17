import Foundation

@Observable
final class ScanListVM {
    private(set) var files: [URL] = []
    private(set) var rawSessions: [URL] = []
    
    func fetchFiles() {
        rawSessions = ((try? FileManager.default.contentsOfDirectory(
            at: SceneRawSession.localDirectory, includingPropertiesForKeys: nil
        )) ?? []).filter { $0.pathExtension == "zip" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard let documentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appending(path: "Documents") else {
            print("Unable to access iCloud account")
            files = []
            return
        }
        
        do {
            try FileManager.default.createDirectory(
                at: documentsURL,
                withIntermediateDirectories: true
            )
            
            files = try FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.isDirectoryKey]
            ).filter { try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory != true }
        } catch {
            print("Error reading files from iCloud Documents directory:", error)
            files = []
        }
    }

    func deleteRawSessions(offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            do {
                try FileManager.default.removeItem(at: rawSessions[index])
                rawSessions.remove(at: index)
            } catch {
                print("Unable to delete raw scan:", error)
            }
        }
    }
    
    func deleteFile(offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            do {
                let raw = SceneRawSession.archiveURL(for: files[index])
                if FileManager.default.fileExists(atPath: raw.path) {
                    try FileManager.default.removeItem(at: raw)
                }
                try FileManager.default.removeItem(at: files[index])
                files.remove(at: index)
            } catch {
                print("Error deleting file:", error)
            }
        }
    }
}
