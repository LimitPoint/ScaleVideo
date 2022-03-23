//
//  AVAsset-extensions.swift
//  ScaleVideo
//
//  Created by Joseph Pagliaro on 3/14/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import AVFoundation
import CoreImage

extension AVAsset {
    
    func audioReader(outputSettings: [String : Any]?) -> (audioTrack:AVAssetTrack?, audioReader:AVAssetReader?, audioReaderOutput:AVAssetReaderTrackOutput?) {
        
        if let audioTrack = self.tracks(withMediaType: .audio).first {
            if let audioReader = try? AVAssetReader(asset: self)  {
                let audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
                return (audioTrack, audioReader, audioReaderOutput)
            }
        }
        
        return (nil, nil, nil)
    }
    
    func videoReader(outputSettings: [String : Any]?) -> (videoTrack:AVAssetTrack?, videoReader:AVAssetReader?, videoReaderOutput:AVAssetReaderTrackOutput?) {
        
        if let videoTrack = self.tracks(withMediaType: .video).first {
            if let videoReader = try? AVAssetReader(asset: self)  {
                let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
                return (videoTrack, videoReader, videoReaderOutput)
            }
        }
        
        return (nil, nil, nil)
    }
    
    func audioSampleBuffer(outputSettings: [String : Any]?) -> CMSampleBuffer? {
        
        var buffer:CMSampleBuffer?
        
        if let audioTrack = self.tracks(withMediaType: .audio).first, let audioReader = try? AVAssetReader(asset: self)  {
            
            let audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
            
            if audioReader.canAdd(audioReaderOutput) {
                audioReader.add(audioReaderOutput)
                
                if audioReader.startReading() {
                    buffer = audioReaderOutput.copyNextSampleBuffer()
                    
                    audioReader.cancelReading()
                }
            }
        }
        
        return buffer
    }
    
        // Note: the number of samples per buffer may change, resulting in different bufferCounts
    func audioBufferAndSampleCounts(_ outputSettings:[String : Any]) -> (bufferCount:Int, sampleCount:Int) {
        
        var sampleCount:Int = 0
        var bufferCount:Int = 0
        
        guard let audioTrack = self.tracks(withMediaType: .audio).first else {
            return (bufferCount, sampleCount)
        }
        
        if let audioReader = try? AVAssetReader(asset: self)  {
            
            let audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
            audioReader.add(audioReaderOutput)
            
            if audioReader.startReading() {
                
                while audioReader.status == .reading {
                    if let sampleBuffer = audioReaderOutput.copyNextSampleBuffer() {
                        sampleCount += sampleBuffer.numSamples
                        bufferCount += 1
                    }
                    else {
                        audioReader.cancelReading()
                    }
                }
            }
        }
        
        return (bufferCount, sampleCount)
    }
    
    func assetTrackTransform() -> CGAffineTransform? {
        guard let track = self.tracks(withMediaType: AVMediaType.video).first else { return nil }
        return track.preferredTransform
    }
    
    func estimatedFrameCount() -> Int {
        
        var frameCount = 0
        
        guard let videoTrack = self.tracks(withMediaType: .video).first else {
            return 0
        }
        
        frameCount = Int(CMTimeGetSeconds(self.duration) * Float64(videoTrack.nominalFrameRate))
        
        return frameCount
    }
    
    func ciOrientationTransform() -> CGAffineTransform {
        var orientationTransform = CGAffineTransform.identity
        if let videoTransform = self.assetTrackTransform() {
            orientationTransform = videoTransform.inverted()
        }
        return orientationTransform
    }
    
}

