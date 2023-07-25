//
//  ContentView.swift
//  Scanius
//
//  Created by Sergei Saliukov on 23/07/2023.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "camera.metering.matrix")
                .title()
                .foregroundColor(.accentColor)
            
            Text("Roomscanner")
                .title()
            
            ProgressView()
            
            Spacer().frame(height: 40)
            
            Text("Scan the room by pointing the camera at all surfaces. Model export supports usdz and obj format.")
            
            Spacer().frame(height: 40)
            
            NavigationLink("Start Scan") {
                ScanningView()
            }
            .title2()
            .clipShape(.capsule)
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    ContentView()
}
