//
//  ScaleVideoObservable.swift
//  ScaleVideo
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/scale-video/#scale-video-observable
//
//  Created by Joseph Pagliaro on 3/13/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import SwiftUI
import AVFoundation

let kDefaultURL = Bundle.main.url(forResource: "DefaultVideo", withExtension: "mov")!

enum FPS: Int, CaseIterable, Identifiable {
    case twentyFour = 24, thirty = 30, sixty = 60
    var id: Self { self }
}

class ScaleVideoObservable:ObservableObject {
    
    var videoURL = kDefaultURL
    var scaledVideoURL = kDefaultURL
    var documentsURL:URL
    var scaleVideo:ScaleVideo?
    var videoDocument:VideoDocument?
    
    @Published var progressFrameImage:CGImage?
    @Published var progress:Double = 0
    @Published var progressTitle:String = "Progress"
    @Published var isScaling:Bool = false
    
    @Published var factor:Double = 1.5 
    @Published var fps:FPS = .thirty
    
    var errorMesssage:String?
    @Published var player:AVPlayer
    
    init() {
        player = AVPlayer(url: videoURL)
        
        documentsURL = try! FileManager.default.url(for:.documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        print("path = \(documentsURL.path)")

        #if os(iOS)        
        if let uiimage = UIImage(named: "ScaleVideo.png") {
            progressFrameImage = uiimage.cgImage
        }
        #else
        if let nsimage = NSImage(named: "ScaleVideo.png") {
            progressFrameImage = nsimage.cgImage(forProposedRect:nil, context: nil, hints: nil)
        }
        #endif
    }
    
    func tryDownloadingUbiquitousItem(_ url: URL, completion: @escaping (URL?) -> ()) {
        
        var downloadedURL:URL?
        
        if FileManager.default.isUbiquitousItem(at: url) {
            
            let queue = DispatchQueue(label: "com.limit-point.startDownloadingUbiquitousItem")
            let group = DispatchGroup()
            group.enter()
            
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now()) {
                
                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: url)
                    let error:NSErrorPointer = nil
                    let coordinator = NSFileCoordinator(filePresenter: nil)
                    coordinator.coordinate(readingItemAt: url, options: NSFileCoordinator.ReadingOptions.withoutChanges, error: error) { readURL in
                        downloadedURL = readURL
                    }
                    if let error = error {
                        self.errorMesssage = error.pointee?.localizedFailureReason
                        print("Can't download the URL: \(self.errorMesssage ?? "No avaialable error from NSFileCoordinator")")
                    }
                    group.leave()
                }
                catch {
                    self.errorMesssage = error.localizedDescription
                    print("Can't download the URL: \(error.localizedDescription)")
                    group.leave()
                }
            }
            
            group.notify(queue: queue, execute: {
                completion(downloadedURL)
            })
        }
        else {
            self.errorMesssage = "URL is not ubiquitous item"
            completion(nil)
        }
    }
    
    func copyURL(_ url: URL, completion: @escaping (URL?) -> ()) {
        
        let filename = url.lastPathComponent
        
        if let copiedURL = FileManager.documentsURL("\(filename)") {
            
            try? FileManager.default.removeItem(at: copiedURL)
            
            do {
                try FileManager.default.copyItem(at: url, to: copiedURL)
                completion(copiedURL)
            }
            catch {
                tryDownloadingUbiquitousItem(url) { downloadedURL in
                    
                    if let downloadedURL = downloadedURL {
                        do {
                            try FileManager.default.copyItem(at: downloadedURL, to: copiedURL)
                            completion(copiedURL)
                        }
                        catch {
                            self.errorMesssage = error.localizedDescription
                            completion(nil)
                        }
                    }
                    else {
                        self.errorMesssage = error.localizedDescription
                        completion(nil)
                    }
                }
            }
        }
        else {
            completion(nil)
        }
    }
    
    func loadSelectedURL(_ url:URL, completion: @escaping (Bool) -> ()) {
        
        let scoped = url.startAccessingSecurityScopedResource()
        
        copyURL(url) { copiedURL in
            
            if scoped { 
                url.stopAccessingSecurityScopedResource() 
            }
            
            DispatchQueue.main.async {
                if let copiedURL = copiedURL {
                    self.videoURL = copiedURL
                    
                    self.player = AVPlayer(url: copiedURL)
                    completion(true)
                }
                else {
                    completion(false)
                }
            }
        }
    }
    
    func play(_ url:URL) {
        self.player.pause()
        self.player = AVPlayer(url: url)
        self.player.play()
    }
    
    func playOriginal() {
        play(videoURL)
    }
    
    func playScaled() {
        play(scaledVideoURL)
    }
    
    func scale() {
        
        self.player.pause()
        
        isScaling = true
        
        let filename = self.videoURL.deletingPathExtension().lastPathComponent + "-scaled.mov"
        
        let destinationPath = FileManager.documentsURL("\(filename)")!.path 
        let asset = AVAsset(url: self.videoURL)
                    
        DispatchQueue.global(qos: .userInitiated).async {
            
            var lastDate = Date()
            var updateProgressImage = true
            var totalElapsed:TimeInterval = 0
            
            let desiredDuration:Float64 = asset.duration.seconds * self.factor
            
            self.scaleVideo = ScaleVideo(path: self.videoURL.path, desiredDuration: desiredDuration, frameRate: Int32(self.fps.rawValue), destination: destinationPath, progress: { (value, ciimage) in
                
                DispatchQueue.main.async {
                    self.progress = value
                    self.progressTitle = "Progress \(Int(value * 100))%"
                }
                
                let elapsed = Date().timeIntervalSince(lastDate)
                lastDate = Date()
                
                totalElapsed += elapsed
                
                if totalElapsed > 0.3 && updateProgressImage {
                    
                    updateProgressImage = false
                    
                    totalElapsed = 0
                    
                    var previewImage:CGImage?
                    
                    autoreleasepool {
                        if let image = ciimage {
                            previewImage = image.cgimage()
                        }
                    }
                    
                    DispatchQueue.main.async {
                        autoreleasepool {
                            if let previewImage = previewImage {
                                self.progressFrameImage = previewImage
                            }
                        }
                        
                        updateProgressImage = true
                    }
                }
                
            }, completion: { (resultURL, errorMessage) in
                                
                DispatchQueue.main.async {
                    
                    self.progress = 0
                    
                    if let resultURL = resultURL, self.scaleVideo?.isCancelled == false {
                        self.scaledVideoURL = resultURL
                    }
                    else {
                        self.scaledVideoURL = kDefaultURL
                    }
                    
                    self.playScaled()
                    
                    self.isScaling = false
                }
            })
            
            self.scaleVideo?.start()
        }
    }
    
    func cancel() {
        self.scaleVideo?.isCancelled = true
    }
    
    func prepareToExportScaledVideo() {
        videoDocument = VideoDocument(url:self.scaledVideoURL)
    }
}
