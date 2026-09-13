import Foundation

@Observable
final class ScanListVM {
    private(set) var files: [URL] = []
    
    func fetchFiles() {
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
                includingPropertiesForKeys: nil
            )
        } catch {
            print("Error reading files from iCloud Documents directory:", error)
            files = []
        }
    }
    
    func deleteFile(offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            do {
                try FileManager.default.removeItem(at: files[index])
                files.remove(at: index)
            } catch {
                print("Error deleting file:", error)
            }
        }
    }
}
