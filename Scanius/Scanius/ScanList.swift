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
            }
        }
    }
}

#Preview {
    ScanList()
}
