import SwiftUI

@available(iOS 18, *)
struct SceneCaptureControlsView: View {
    @Environment(SceneReconstructionVM.self) private var vm

    var body: some View {
        VStack {
            Text(vm.trackingMessage)

            Text("\(vm.meshCount) mesh sections captured")
                .secondary()

            Text("\(vm.textureFrameCount) surface photos captured")
                .footnote()
                .secondary()

            if let error = vm.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }

            if vm.canResume {
                Button("Resume Scanning", systemImage: "play", action: vm.resumeScanning)
            }

            if vm.isSaving {
                ProgressView(vm.saveMessage)
            } else {
                Button("Save Textured Scan", systemImage: "checkmark") {
                    Task { await vm.save() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.meshCount == 0 || !vm.isRunning)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }
}
