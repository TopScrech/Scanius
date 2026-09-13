import SwiftUI

@available(iOS 18, *)
struct SceneScanningView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var vm = SceneReconstructionVM()

    var body: some View {
        Group {
            if !vm.isSupported {
                ContentUnavailableView(
                    "LiDAR Mesh Unavailable",
                    systemImage: "cube.transparent",
                    description: Text("Scanning spaces requires an iPhone or iPad with a LiDAR scanner")
                )
            } else if let url = vm.resultURL {
                QuickLookView(url)
                    .safeAreaInset(edge: .bottom) {
                        if let coverage = vm.textureCoverage {
                            Text("Photo coverage: \(coverage, format: .percent.precision(.fractionLength(0))) — gray surfaces need more camera views")
                                .font(.footnote)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(.regularMaterial)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            ShareLink(item: url)
                        }
                    }
            } else {
                SceneCameraView()
                    .safeAreaInset(edge: .bottom) {
                        SceneCaptureControlsView()
                    }
            }
        }
        .environment(vm)
        .navigationTitle("LiDAR Mesh")
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
