import SwiftUI

struct ScanningView: View {
    @Environment(\.dismiss) private var dismiss
    private var captureController = RoomPlanController.instance
    
    var body: some View {
        RoomPlanView()
            .ignoresSafeArea()
            .safeAreaInset(edge: .bottom) {
                if let error = captureController.errorMessage {
                    Text(error)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                }
            }
            .task {
                captureController.startSession()
            }
            .onDisappear {
                captureController.cancel()
            }
            .onChange(of: captureController.savedURL) {
                if captureController.savedURL != nil {
                    dismiss()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if captureController.isSaving {
                        ProgressView()
                    } else {
                        Button("Save", systemImage: "checkmark", action: captureController.save)
                    }
                }
            }
    }
}
