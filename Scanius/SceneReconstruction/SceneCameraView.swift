import SwiftUI
import RealityKit

@available(iOS 18, *)
struct SceneCameraView: UIViewRepresentable {
    @Environment(SceneReconstructionVM.self) private var vm
    
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        view.session = vm.session
        view.debugOptions.insert(.showSceneUnderstanding)
        return view
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        uiView.session.pause()
    }
}
