//
//  VideoWriter.swift
//  ScaleVideo
//
//  Created by Joseph Pagliaro on 3/22/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import AVFoundation
import CoreImage

func testVideoWriter() {
    let fm = FileManager.default
    let docsurl = try! fm.url(for:.documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    
    let destinationPath = docsurl.appendingPathComponent("DefaultVideoCopy.mov").path
    let videoWriter = VideoWriter(path: kDefaultURL.path, destination: destinationPath, progress: { p, _ in
        print("p = \(p)")
    }, completion: { result, error in
        print("result = \(String(describing: result))")
    })
    
    videoWriter?.start()
}

/*
 
 Base class for reading and writing video: copies video using passthourgh read and write.
 
 ScaleVideo subclass overrides to read uncompressed video samples for processing to scale video and audio.
    
 */
class VideoWriter {
    
    var videoAsset:AVAsset
    
    var videoURL: URL
    var generatedMovieURL: URL
    
    var progressAction: ((CGFloat, CIImage?) -> Void) = { progress,_ in print("progress = \(progress)")}
    var completionAction: ((URL?, String?) -> Void) = { url,error in (url == nil ? print("Failed! - \(String(describing: error))") : print("Success!")) }
    
    var movieSize:CGSize
    
    var assetWriter:AVAssetWriter!
    
    var videoWriterInput:AVAssetWriterInput!
    var audioWriterInput:AVAssetWriterInput!
    
    var videoReader: AVAssetReader!
    var videoReaderOutput:AVAssetReaderTrackOutput!
    var audioReader: AVAssetReader?
    var audioReaderOutput:AVAssetReaderTrackOutput?
    
    var writingVideoFinished = false
    var writingAudioFinished = false
    
    var frameCount:Int = 0
    var currentFrameCount:Int = 0 // video
    
    let videoQueue: DispatchQueue = DispatchQueue(label: "com.limit-point.time-scale-video-generator-queue")
    let audioQueue: DispatchQueue = DispatchQueue(label: "com.limit-point.time-scale-audio-generator-queue")
    
    var isCancelled = false
    
    init?(path : String, destination: String, progress: @escaping (CGFloat, CIImage?) -> Void, completion: @escaping (URL?, String?) -> Void) {
        
        videoURL = URL(fileURLWithPath: path)
        generatedMovieURL = URL(fileURLWithPath: destination)
        
        progressAction = progress
        completionAction = completion
        
        videoAsset = AVURLAsset(url: videoURL)
        
        guard let videoTrack = videoAsset.tracks(withMediaType: .video).first else {
            return nil
        }
        
        movieSize = CGSize(width: videoTrack.naturalSize.width, height: videoTrack.naturalSize.height)

        self.frameCount = videoAsset.estimatedFrameCount()
    }
    
    func start() {
        
        if FileManager.default.fileExists(atPath: generatedMovieURL.path) {
            try? FileManager.default.removeItem(at: generatedMovieURL)
        }
        
        createAssetWriter()
        
        prepareForReading()
        prepareForWriting()
        
        startAssetWriter()
        
        writeVideoAndAudio()
    }
    
        // VideoWriter is passthough
    func videoReaderSettings() -> [String : Any]? {
        return nil
    }
    
        // VideoWriter is passthough
    func videoWriterSettings() -> [String : Any]? {
        return nil
    }
    
        // VideoWriter is passthough
    func audioReaderSettings() -> [String : Any]? {
        return nil
    }
    
        // VideoWriter is passthough
    func audioWriterSettings() -> [String : Any]? {
        return nil
    }
    
    func createAssetWriter() {
        guard let writer = try? AVAssetWriter(outputURL: generatedMovieURL, fileType: AVFileType.mov) else {
            failed()
            return
        }
        
        self.assetWriter = writer
    }
    
    func startAssetWriter() {
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: CMTime.zero)
    }
    
    func writeVideoAndAudio() {
        self.writeVideoOnQueue(self.videoQueue)
        self.writeAudioOnQueue(self.audioQueue)
    }
    
    func completed() {
        if self.isCancelled {
            completionAction(nil, "Cancelled")
        }
        else {
            self.completionAction(self.generatedMovieURL, nil)
        }
    }
    
    func failed() {
        
        var errorMessage:String?
        
        if let error = assetWriter?.error {
            print("failed \(error)")
            print("Error")
            errorMessage = error.localizedDescription
        }
        
        if self.isCancelled {
            errorMessage = "Cancelled"
        }
        
        completionAction(nil, errorMessage)
    }
    
    func didCompleteWriting() {
        guard writingVideoFinished && writingAudioFinished else { return }
        assetWriter.finishWriting {
            switch self.assetWriter.status {
                case .failed:
                    self.failed()
                case .completed:
                    self.completed()
                default:
                    self.failed()
            }
            
            return
        }
    }
    
    func finishVideoWriting() {
        if writingVideoFinished == false {
            writingVideoFinished = true
            videoWriterInput.markAsFinished()
        }
        
        didCompleteWriting()
    }
    
    func finishAudioWriting() {
        if writingAudioFinished == false {
            writingAudioFinished = true
            audioWriterInput?.markAsFinished()
        }
        
        didCompleteWriting()
    }
    
    func createVideoWriterInput() {
        
        let outputSettings = videoWriterSettings()
        
        if assetWriter.canApply(outputSettings: outputSettings, forMediaType: AVMediaType.video) {
            
            let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
            
            if let transform = videoAsset.assetTrackTransform() {
                videoWriterInput.transform = transform
            }
           
            videoWriterInput.expectsMediaDataInRealTime = true
            
            if assetWriter.canAdd(videoWriterInput) {
                assetWriter.add(videoWriterInput)
                self.videoWriterInput = videoWriterInput
            }
        }
    }
    
    func createAudioWriterInput() {
        
        let outputSettings = audioWriterSettings()
        
        let audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: outputSettings)
        
        audioWriterInput.expectsMediaDataInRealTime = false
        
        if assetWriter.canAdd(audioWriterInput) {
            assetWriter.add(audioWriterInput)
            self.audioWriterInput = audioWriterInput
        }
    }
    
    func prepareForReading() {
                
            // Video Reader
        let (_, videoReader, videoReaderOutput) = videoAsset.videoReader(outputSettings: videoReaderSettings())
        
        if let videoReader = videoReader, let videoReaderOutput = videoReaderOutput, videoReader.canAdd(videoReaderOutput) {
            
            if videoReader.canAdd(videoReaderOutput) {
                videoReader.add(videoReaderOutput)
                
                self.videoReader = videoReader
                self.videoReaderOutput = videoReaderOutput
            }
        }
        
            // Audio Reader
        let (_, audioReader, audioReaderOutput) = videoAsset.audioReader(outputSettings: audioReaderSettings())
        
        if let audioReader = audioReader, let audioReaderOutput = audioReaderOutput, audioReader.canAdd(audioReaderOutput) {
            
            if audioReader.canAdd(audioReaderOutput) {
                audioReader.add(audioReaderOutput)
                
                self.audioReader = audioReader
                self.audioReaderOutput = audioReaderOutput
            }
        }
    }
    
    func prepareForWriting() {
        self.createVideoWriterInput()
        self.createAudioWriterInput()
    }
    
    func writeVideoOnQueue(_ serialQueue:DispatchQueue) {
        
        guard self.videoReader.startReading() else {
            self.finishVideoWriting()
            return
        }
        
        videoWriterInput.requestMediaDataWhenReady(on: serialQueue) {
            
            while self.videoWriterInput.isReadyForMoreMediaData, self.writingVideoFinished == false {
                
                autoreleasepool { () -> Void in
                    
                    guard self.isCancelled == false else {
                        self.videoReader?.cancelReading()
                        self.finishVideoWriting()
                        return
                    }
                    
                    guard let sampleBuffer = self.videoReaderOutput?.copyNextSampleBuffer() else {
                        self.finishVideoWriting()
                        return
                    }
                    
                    guard self.videoWriterInput.append(sampleBuffer) else {
                        self.videoReader?.cancelReading()
                        self.finishVideoWriting()
                        return
                    }
                    
                    self.currentFrameCount += 1
                    let percent = min(CGFloat(self.currentFrameCount) / CGFloat(self.frameCount), 1.0)
                    self.progressAction(percent, nil)
                    
                }
            }
        }
    }
    
    func writeAudioOnQueue(_ serialQueue:DispatchQueue) {
        
        guard let audioReader = self.audioReader, let audioWriterInput = self.audioWriterInput, let audioReaderOutput = self.audioReaderOutput, audioReader.startReading() else {
            self.finishAudioWriting()
            return
        }
        
        audioWriterInput.requestMediaDataWhenReady(on: serialQueue) {
            
            while audioWriterInput.isReadyForMoreMediaData, self.writingAudioFinished == false {
                
                autoreleasepool { () -> Void in
                    
                    guard self.isCancelled == false else {
                        audioReader.cancelReading()
                        self.finishAudioWriting()
                        return
                    }
                    
                    guard let sampleBuffer = audioReaderOutput.copyNextSampleBuffer() else {
                        self.finishAudioWriting()
                        return
                    }
                    
                    guard audioWriterInput.append(sampleBuffer) else {
                        audioReader.cancelReading()
                        self.finishAudioWriting()
                        return
                    }
                    
                }
            }
        }
    }
}
