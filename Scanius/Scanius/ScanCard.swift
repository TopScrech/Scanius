import ScrechKit
import RoomPlan

struct ScanCard: View {
    private let file: URL
    
    init(_ file: URL) {
        self.file = file
    }
    
    var body: some View {
        NavigationLink {
            QuickLookView(file)
        } label: {
            VStack(alignment: .leading) {
                Text(file.lastPathComponent)
                    .title3()
                
                Text("Size: \(fileSize(file) ?? "-")")
                    .footnote()
                    .secondary()
            }
        }
    }
    
    private func loadCapturedRoom(_ url: URL) throws -> CapturedRoom? {
        let jsonData = try? Data(contentsOf: url)
        guard let data = jsonData else { return nil }
        
        let capturedRoom = try? JSONDecoder().decode(CapturedRoom.self, from: data)
        return capturedRoom
    }
    
    private func fileSize(_ url: URL) -> String? {
        let resourceKeys: Set<URLResourceKey> = [.fileSizeKey]
        
        do {
            let resourceValues = try url.resourceValues(forKeys: resourceKeys)
            
            return formatBytes(resourceValues.fileSize ?? 0)
        } catch {
            print("Error retrieving file size: \(error)")
            return nil
        }
    }
}

#Preview {
    List {
        ScanCard(
            Bundle.main.url(forResource: "example", withExtension: "usdz")!
        )
    }
}
