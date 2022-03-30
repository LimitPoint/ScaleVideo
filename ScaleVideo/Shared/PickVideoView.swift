//
//  PickVideoView.swift
//  ScaleVideo
//
//  Created by Joseph Pagliaro on 3/14/22. 
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI
import AVKit

let tangerine = Color(red: 0.98, green: 0.57, blue: 0.21, opacity:0.9)

struct AlertInfo: Identifiable {
    
    enum AlertType {
        case urlNotLoaded
        case exporterSuccess
        case exporterFailed
    }
    
    let id: AlertType
    let title: String
    let message: String
}

struct PickVideoView: View {
    
    @ObservedObject var scaleVideoObservable:ScaleVideoObservable 
    
    @State private var showFileImporter: Bool = false
    @State private var showFileExporter: Bool = false
    
    @State private var alertInfo: AlertInfo?
    
    @State private var showURLLoadingProgress = false
    
    var body: some View {
        VStack {
            Button(action: { showFileImporter = true }, label: {
                Label("Import", systemImage: "square.and.arrow.down")
            })
            
            VideoPlayer(player: scaleVideoObservable.player)
            
            Text(scaleVideoObservable.videoURL.lastPathComponent)
            
            HStack {
                Button(action: { scaleVideoObservable.playOriginal() }, label: {
                    Label("Video", systemImage: "play.circle")
                })
                
                Button(action: { scaleVideoObservable.playScaled() }, label: {
                    Label("Scaled", systemImage: "play.circle.fill")
                })
                
                Button(action: { scaleVideoObservable.prepareToExportScaledVideo(); showFileExporter = true }, label: {
                    Label("Export", systemImage: "square.and.arrow.up.fill")
                })
            }
            .padding()
        }
        .padding()
        .fileExporter(isPresented: $showFileExporter, document: scaleVideoObservable.videoDocument, contentType: UTType.quickTimeMovie, defaultFilename: scaleVideoObservable.videoDocument?.filename) { result in
            if case .success = result {
                do {
                    let exportedURL: URL = try result.get()
                    alertInfo = AlertInfo(id: .exporterSuccess, title: "Scaled Video Saved", message: exportedURL.lastPathComponent)
                }
                catch {
                    
                }
            } else {
                alertInfo = AlertInfo(id: .exporterFailed, title: "Scaled Video Not Saved", message: (scaleVideoObservable.videoDocument?.filename ?? ""))
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.movie, .quickTimeMovie, .mpeg4Movie], allowsMultipleSelection: false) { result in
            do {
                showURLLoadingProgress = true
                guard let selectedURL: URL = try result.get().first else { return }
                scaleVideoObservable.loadSelectedURL(selectedURL) { wasLoaded in
                    if !wasLoaded {
                        alertInfo = AlertInfo(id: .urlNotLoaded, title: "Video Not Loaded", message: (scaleVideoObservable.errorMesssage ?? "No information available."))
                    }
                    showURLLoadingProgress = false
                }
            } catch {
                print(error.localizedDescription)
            }
        }
        .alert(item: $alertInfo, content: { alertInfo in
            Alert(title: Text(alertInfo.title), message: Text(alertInfo.message))
        })
        .overlay(Group {
            if showURLLoadingProgress {          
                ProgressView("Loading...")
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(tangerine))
            }
        })
    }
}

struct PickVideoView_Previews: PreviewProvider {
    static var previews: some View {
        PickVideoView(scaleVideoObservable: ScaleVideoObservable())
    }
}
