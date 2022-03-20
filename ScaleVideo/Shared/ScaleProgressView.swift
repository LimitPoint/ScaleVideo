//
//  ScaleProgressView.swift
//  ScaleVideo
//
//  Created by Joseph Pagliaro on 3/15/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct ScaleProgressView: View {
    
    @ObservedObject var scaleVideoObservable: ScaleVideoObservable
    
    var body: some View {
        VStack {
            if let cgimage = scaleVideoObservable.progressFrameImage
            {
                Image(cgimage, scale: 1, label: Text("Core Image"))
                    .resizable()
                    .scaledToFit()
            }
            else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100, alignment: .center)
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
