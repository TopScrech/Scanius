import ScrechKit
import RoomPlan

struct ScanList: View {
    @State private var files: [URL] = []
    
    var body: some View {
        List {
            if files.isEmpty {
                ContentUnavailableView(
                    "You have no scans yet",
                    systemImage: "doc.viewfinder",
                    description: Text("Consider creating a new one")
                )
            } else {
                ForEach(files, id: \.self) { file in
                    ScanCard(file)
                }
                .onDelete(perform: deleteFile)
            }
            
            Section {
                NavigationLink("New Scan") {
                    ScanningView()
                }
            }
        }
        .task {
            files = fetchFiles()
        }
    }
        
    func deleteFile(offsets: IndexSet) {
        for index in offsets {
            do {
                try FileManager.default.removeItem(at: files[index])
                print("File successfully deleted.")
            } catch {
                print("Error deleting file: \(error)")
            }
        }
    }
    
    private func fetchFiles() -> [URL] {
        guard let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") else {
            print("Unable to access iCloud account")
            return []
        }
        
        do {
            // Create the "Documents" directory if it doesn't exist
            try FileManager.default.createDirectory(
                at: iCloudDocumentsURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            let urls = try FileManager.default.contentsOfDirectory(
                at: iCloudDocumentsURL,
                includingPropertiesForKeys: nil
            )
            
            return urls
        } catch {
            print("Error reading files from iCloud Documents directory: \(error)")
            return []
        }
    }
    //    private func fetchFiles() -> [URL] {
    //        // Get the iCloud container URL
    //        guard let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") else {
    //            print("Unable to access iCloud account")
    //            return []
    //        }
    //
    //        do {
    //            let urls = try FileManager.default.contentsOfDirectory(
    //                at: iCloudDocumentsURL,
    //                includingPropertiesForKeys: nil
    //            )
    //
    //            return urls
    //        } catch {
    //            print("Error reading files from iCloud Documents directory: \(error)")
    //            return []
    //        }
    //    }
    //    private func getFilesFromDocumentsDirectory() -> [URL]? {
    //        let documentsDirectory = FileManager.default.urls(
    //            for: .documentDirectory,
    //            in: .userDomainMask
    //        ).first!
    //
    //        do {
    //            let urls = try FileManager.default.contentsOfDirectory(
    //                at: documentsDirectory,
    //                includingPropertiesForKeys: nil
    //            )
    //            return urls
    //        } catch {
    //            print("Error reading files from documents directory.")
    //            return nil
    //        }
    //    }
}

#Preview {
    ScanList()
}
