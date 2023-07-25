import SwiftUI

struct RoomPlanView: UIViewRepresentable {
    func makeUIView(context: Context) -> some UIView {
        RoomPlanController.instance.roomCaptureView
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {}
}

struct ActivityViewControllerRep: UIViewControllerRepresentable {
    var items: [Any]
    var activities: [UIActivity]? = nil
    
    func makeUIViewController(
        context: UIViewControllerRepresentableContext<ActivityViewControllerRep>) -> UIActivityViewController {
            UIActivityViewController(activityItems: items, applicationActivities: activities)
        }
    
    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: UIViewControllerRepresentableContext<ActivityViewControllerRep>
    ) {}
}

struct ScanningView: View {
    private var captureController = RoomPlanController.instance
    
    var body: some View {
        @Bindable var binding = captureController
        
        ZStack(alignment: .bottom) {
            RoomPlanView()
            
            Button("Export") {
                captureController.export()
            }
            .title2()
            .buttonStyle(.borderedProminent)
            .clipShape(.capsule)
            .opacity(captureController.showExportButton ? 1 : 0)
            .padding()
        }
        .ignoresSafeArea()
        .onAppear {
            captureController.showExportButton = false
            captureController.startSession()
        }
        .onDisappear {
            captureController.stopSession()
        }
        .sheet($binding.showShareSheet) {
            ActivityViewControllerRep(items: [captureController.exportUrl!])
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    captureController.stopSession()
                    captureController.showExportButton = true
                }
            }
        }
    }
}

#Preview {
    ScanningView()
}
