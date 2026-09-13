import SwiftUI
import RealityKit

struct ObjectScanningView: View {
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var vm: ObjectCaptureVM

    init(mode: ObjectCaptureMode = .object) {
        _vm = State(initialValue: ObjectCaptureVM(mode: mode))
    }
    
    var body: some View {
        Group {
            if !vm.isSupported {
                ContentUnavailableView(
                    "\(vm.mode.title) Unavailable",
                    systemImage: "cube.transparent",
                    description: Text("This device does not support guided object capture and on-device 3D reconstruction")
                )
            } else if let error = vm.errorMessage {
                ContentUnavailableView(
                    "Unable to Create Capture",
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
                    Text("Keep Scanius open while your scan is reconstructed")
                        .secondary()
                }
                .padding()
            } else if let session = vm.session {
                ObjectCaptureCameraView(session: session, mode: vm.mode)
                    .safeAreaInset(edge: .bottom) {
                        ObjectCaptureControlsView()
                            .environment(vm)
                    }
            } else {
                ProgressView("Preparing Capture")
            }
        }
        .navigationTitle(vm.mode.title)
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
