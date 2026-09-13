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
                NavigationLink("New Scan") {
                    ScanningView()
                }
            }
        }
        .task {
            vm.fetchFiles()
        }
    }
}

#Preview {
    ScanList()
}
