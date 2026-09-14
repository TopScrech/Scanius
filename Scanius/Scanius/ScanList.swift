import ScrechKit

struct ScanList: View {
    @State private var vm = ScanListVM()
    
    var body: some View {
        List {
            if vm.files.isEmpty {
                ContentUnavailableView(
                    "You have no scans yet",
                    systemImage: "doc.viewfinder",
                    description: Text("Consider creating a new one")
                )
            } else {
                ForEach(vm.files, id: \.self) {
                    ScanCard($0)
                }
                .onDelete(perform: vm.deleteFile)
            }
            
            Section {
                Menu("New Scan", systemImage: "plus") {
                    NavigationLink("Room Plan", value: ScanType.roomPlan)
                    NavigationLink("Object Capture", value: ScanType.objectCapture)
                    NavigationLink("Area Capture", value: ScanType.areaCapture)
                    NavigationLink("LiDAR Mesh (Smoothed)", value: ScanType.sceneReconstruction)
                    NavigationLink("LiDAR Mesh (Original)", value: ScanType.originalSceneReconstruction)
                }
            }
        }
        .task {
            vm.fetchFiles()
        }
        .navigationDestination(for: ScanType.self) {
            switch $0 {
            case .roomPlan:
                ScanningView()
            case .objectCapture:
                ObjectScanningView()
            case .areaCapture:
                if #available(iOS 18, *) {
                    ObjectScanningView(mode: .area)
                } else {
                    ContentUnavailableView("Area Capture Requires iOS 18", systemImage: "viewfinder")
                }
            case .sceneReconstruction, .originalSceneReconstruction:
                if #available(iOS 18, *) {
                    SceneScanningView(mode: $0 == .originalSceneReconstruction ? .original : .smoothed)
                } else {
                    ContentUnavailableView("LiDAR Mesh Requires iOS 18", systemImage: "cube.transparent")
                }
            }
        }
    }
}

#Preview {
    ScanList()
}
