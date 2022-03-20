//
//  HeaderView.swift
//  ScaleAudio
//
//  Created by Joseph Pagliaro on 2/11/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct HeaderView: View {
    
    @ObservedObject var scaleVideoObservable: ScaleVideoObservable
    
    var body: some View {
#if os(macOS)
        VStack {
            Text("Files generated into Documents folder")
                .fontWeight(.bold)
                .padding(2)
            Text("This app scales video and audio time.")
            
            Button("Go to Documents", action: { 
                NSWorkspace.shared.open(scaleVideoObservable.documentsURL)
            }).padding(2)
        }
#else 
        Text("Files generated into Documents folder")
            .fontWeight(.bold)
            .padding(2)
#endif
    }
}

struct HeaderView_Previews: PreviewProvider {
    static var previews: some View {
        HeaderView(scaleVideoObservable: ScaleVideoObservable())
    }
}
