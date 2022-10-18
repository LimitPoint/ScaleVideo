//
//  ScaleVideoAppView.swift
//  Shared
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/scale-video/
//
//  Created by Joseph Pagliaro on 3/13/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct ScaleVideoAppView: View {
    
    @ObservedObject var scaleVideoObservable:ScaleVideoObservable 
    
    var body: some View {
        
        if scaleVideoObservable.isScaling {
            ScaleProgressView(scaleVideoObservable: scaleVideoObservable)
        }
        else {
            VStack {
                HeaderView(scaleVideoObservable: scaleVideoObservable)
                PickVideoView(scaleVideoObservable: scaleVideoObservable)
                ScaleOptionsView(scaleVideoObservable: scaleVideoObservable)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ScaleVideoAppView(scaleVideoObservable: ScaleVideoObservable())
    }
}
