import SwiftUI
import RealityKit

struct ObjectCaptureControlsView: View {
    @Environment(ObjectCaptureVM.self) private var vm
    
    var body: some View {
        VStack {
            if let message = vm.detectionMessage {
                Text(message)
            }
            
            if let session = vm.session {
                switch session.state {
                case .initializing:
                    ProgressView("Starting Camera")
                case .ready:
                    Text("Center the object in the frame")
                    Button("Detect Object", systemImage: "viewfinder", action: vm.detectObject)
                case .detecting:
                    Text("Adjust the box to fit your object, then start capturing")
                    Button("Start Capture", systemImage: "camera", action: vm.startCapturing)
                case .capturing:
                    Text("Move slowly around the object to capture every side")
                    Text("\(session.numberOfShotsTaken) photos captured")
                        .foregroundStyle(.secondary)
                    
                    if session.userCompletedScanPass {
                        Button("Capture Another Angle", systemImage: "arrow.triangle.2.circlepath", action: vm.nextPass)
                    }
                    
                    Button("Create 3D Model", systemImage: "cube", action: vm.finish)
                        .disabled(session.numberOfShotsTaken == 0)
                case .finishing, .completed:
                    ProgressView("Finishing Capture")
                case .failed:
                    EmptyView()
                @unknown default:
                    EmptyView()
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }
}
