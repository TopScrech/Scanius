import SwiftUI
import RealityKit

struct ObjectCaptureCameraView: View {
    let session: ObjectCaptureSession
    let mode: ObjectCaptureMode

    var body: some View {
        if #available(iOS 18, *) {
            ObjectCaptureView(session: session)
                .hideObjectReticle(mode == .area)
        } else {
            ObjectCaptureView(session: session)
        }
    }
}
