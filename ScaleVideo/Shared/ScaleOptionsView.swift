//
//  ScaleOptionsView.swift
//  ScaleVideo
//
//  Created by Joseph Pagliaro on 3/15/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct ScaleOptionsView: View {
    @ObservedObject var scaleVideoObservable: ScaleVideoObservable
    
    @State private var isEditing = false
    
    var body: some View {
        
        VStack {
            Slider(
                value: $scaleVideoObservable.factor,
                in: 0.1...2
            ) {
                Text("Factor")
            } minimumValueLabel: {
                Text("0.1")
            } maximumValueLabel: {
                Text("2")
            } onEditingChanged: { editing in
                isEditing = editing
            }
            Text(String(format: "%.2f", scaleVideoObservable.factor))
                .foregroundColor(isEditing ? .red : .blue)
            
            Picker("Frame Rate", selection: $scaleVideoObservable.fps) {
                Text("24").tag(FPS.twentyFour)
                Text("30").tag(FPS.thirty)
                Text("60").tag(FPS.sixty)
            }
            .pickerStyle(.segmented)
            
            Button(action: { scaleVideoObservable.scale() }, label: {
                Label("Scale", systemImage: "timelapse")
            })
            .padding()
            
        }
        .padding()
    }
}

struct ScaleOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        ScaleOptionsView(scaleVideoObservable: ScaleVideoObservable())
    }
}
