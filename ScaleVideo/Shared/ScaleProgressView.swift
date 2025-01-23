//
//  ScaleProgressView.swift
//  ScaleVideo
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/scale-video/
//
//  Created by Joseph Pagliaro on 3/15/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct ScaleProgressView: View {
    
    @ObservedObject var scaleVideoObservable: ScaleVideoObservable
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        VStack {
            if let cgimage = scaleVideoObservable.progressFrameImage
            {
                Image(cgimage, scale: 1, label: Text("Core Image"))
                    .resizable()
                    .scaledToFit()
            }
            else {
                Text("Processing…")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .scaleEffect(scale) // Adjusts the size
                    .animation(
                        Animation.easeInOut(duration: 0.8) // Smooth throbbing effect
                            .repeatForever(autoreverses: true),
                        value: scale
                    )
                    .onAppear {
                        scale = 1.2 // Start the throbbing by increasing the scale slightly
                    }
            }
            
            ProgressView(scaleVideoObservable.progressTitle, value: min(scaleVideoObservable.progress,1), total: 1)
                .padding()
                .frame(width: 300)
            
            Button("Cancel", action: { 
                scaleVideoObservable.cancel()
            }).padding()
        }
        
    }
}

struct ScaleProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ScaleProgressView(scaleVideoObservable: ScaleVideoObservable())
    }
}
