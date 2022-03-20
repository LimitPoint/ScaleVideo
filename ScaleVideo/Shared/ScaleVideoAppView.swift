//
//  ScaleVideoAppView.swift
//  Shared
//
//  Created by Joseph Pagliaro on 3/13/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

let tangerine = Color(red: 1.0, green: 0.7, blue: 0.1, opacity:0.9)

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
