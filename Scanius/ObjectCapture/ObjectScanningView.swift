import SwiftUI
import RealityKit

struct ObjectScanningView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var vm = ObjectCaptureVM()
    
    var body: some View {
        Group {
            if !vm.isSupported {
                ContentUnavailableView(
                    "Object Capture Unavailable",
                    systemImage: "cube.transparent",
                    description: Text("This device does not support guided object capture and on-device 3D reconstruction")
                )
            } else if let error = vm.errorMessage {
                ContentUnavailableView(
                    "Unable to Create Object Capture",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if let url = vm.resultURL {
                QuickLookView(url)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            ShareLink(item: url)
                        }
                    }
            } else if vm.isProcessing {
                VStack {
                    ProgressView("Creating 3D Model", value: vm.progress)
                    Text("Keep Scanius open while your object is reconstructed")
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else if let session = vm.session {
                ObjectCaptureView(session: session)
                    .safeAreaInset(edge: .bottom) {
                        ObjectCaptureControlsView()
                            .environment(vm)
                    }
            } else {
                ProgressView("Preparing Object Capture")
            }
        }
        .navigationTitle("Object Capture")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.run()
        }
        .onChange(of: scenePhase) {
            vm.updateScenePhase(scenePhase)
        }
        .onDisappear {
            vm.stop()
        }
    }
}
