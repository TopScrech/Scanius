import SwiftUI

struct RoomPlanView: UIViewRepresentable {
    func makeUIView(context: Context) -> some UIView {
        RoomPlanController.instance.roomCaptureView
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {}
}
