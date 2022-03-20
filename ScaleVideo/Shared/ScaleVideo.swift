//
//  ScaleVideo.swift
//  ScaleVideo
//
//  Created by Joseph Pagliaro on 3/14/22. 
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import AVFoundation
import CoreServices
import CoreImage
import Accelerate
import simd

let kVideoReaderSettings = [kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)]

let kAudioReaderSettings = [
    AVFormatIDKey: Int(kAudioFormatLinearPCM) as AnyObject,
    AVLinearPCMBitDepthKey: 16 as AnyObject,
    AVLinearPCMIsBigEndianKey: false as AnyObject,
    AVLinearPCMIsFloatKey: false as AnyObject,
    AVLinearPCMIsNonInterleaved: false as AnyObject]

extension Array {
    func blocks(size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

extension Array where Element == Int16  {
    
        // Create a control point ramp from `0` to `count-1` (corresponding to an arbitrary array of `count` items)
    static func control(length:Int, count:Int, smoothly:Bool) -> [Double] {
        
        guard length > 0 else {
            return []
        }
        
        let stride = vDSP_Stride(1)
        var control:[Double]
        
        if smoothly, length > count {
            let denominator = Double(length - 1) / Double(count - 1)
            
            control = (0...length - 1).map {
                let x = Double($0) / denominator
                return floor(x) + simd_smoothstep(0, 1, simd_fract(x))
            }
        }
        else {
            var base: Double = 0
            var end = Double(count - 1)
            control = [Double](repeating: 0, count: length)
            
            vDSP_vgenD(&base, &end, &control, stride, vDSP_Length(length))
        }
        
            // Ensure last control point is indeed `count-1` with no fractional part, since the calculations above can produce endpoints like `6.9999999999999991` when it should be `7`
        if control.count > 1 {
            control[control.count-1] = Double(count - 1)
        }
        
        return control
    }
    
    func scaleToD(control:[Double], smoothly:Bool) -> [Element] {
        
        let length = control.count
        
        guard length > 0 else {
            return []
        }
        
        let stride = vDSP_Stride(1)
        
        var result = [Double](repeating: 0, count: length)
        
        var double_array = vDSP.integerToFloatingPoint(self, floatingPointType: Double.self)
        
        let lastControl = control[control.count-1]
        let lastControlTrunc = Int(trunc(lastControl))
        if lastControlTrunc > self.count - 2 {
            let zeros = [Double](repeating: 0, count: lastControlTrunc - self.count + 2)
            double_array.append(contentsOf: zeros)
        }
        
        vDSP_vlintD(double_array,
                    control, stride,
                    &result, stride,
                    vDSP_Length(length),
                    vDSP_Length(double_array.count))
        
        
        
        return vDSP.floatingPointToInteger(result, integerType: Int16.self, rounding: .towardNearestInteger)
    }
    
    func extract_array_channel(channelIndex:Int, channelCount:Int) -> [Int16]? {
        
        guard channelIndex >= 0, channelIndex < channelCount, self.count > 0 else { return nil }
        
        let channel_array_length = self.count / channelCount
        
        guard channel_array_length > 0 else { return nil }
        
        var channel_array = [Int16](repeating: 0, count: channel_array_length)
        
        for index in 0...channel_array_length-1 {
            let array_index = channelIndex + index * channelCount
            channel_array[index] = self[array_index]
        }
        
        return channel_array
    }
    
    func extract_array_channels(channelCount:Int) -> [[Int16]] {
        
        var channels:[[Int16]] = []
        
        guard channelCount > 0 else { return channels }
        
        for channel_index in 0...channelCount-1 {
            if let channel = self.extract_array_channel(channelIndex: channel_index, channelCount: channelCount) {
                channels.append(channel)
            }
            
        }
        
        return channels
    }
}

func testScaleVideo() {
    let fm = FileManager.default
    let docsurl = try! fm.url(for:.documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    
    let destinationPath = docsurl.appendingPathComponent("DefaultVideoScaled.mov").path
    let scaleVideo = ScaleVideo(path: kDefaultURL.path, desiredDuration: 8, frameRate: 30, expedited: false, destination: destinationPath) { p, _ in
        print("p = \(p)")
    } completion: { result, error in
        print("result = \(String(describing: result))")
    }
    
    scaleVideo?.start()
}

class ScaleVideo {
    
    var videoURL: URL
    var ciOrientationTransform:CGAffineTransform = CGAffineTransform.identity
    
    var videoAsset:AVAsset!
    var audioAsset:AVAsset?
    
    var frameCount:Int = 0
    
    var assetWriter:AVAssetWriter!
    
    var movieSize:CGSize
    
    var videoWriterInput:AVAssetWriterInput!
    var audioWriterInput:AVAssetWriterInput?
    
    var videoReader: AVAssetReader!
    var videoReaderOutput:AVAssetReaderTrackOutput!
    var audioReader: AVAssetReader?
    var audioReaderOutput:AVAssetReaderTrackOutput?
    
    var writingVideoFinished = false
    var writingAudioFinished = false
        
    var generatedMovieURL: URL
    
    var progressAction: ((CGFloat, CIImage?) -> Void) = { progress,_ in print("progress = \(progress)")}
    var completionAction: ((URL?, String?) -> Void) = { url,error in (url == nil ? print("Failed! - \(String(describing: error))") : print("Success!")) }
    
    var isCancelled = false
    
        // video scaling
    var desiredDuration:Float64 = 0
    var timeScaleFactor:Float64 = 0
    var expedited:Bool = false
    
        // audio scaling
    var outputBufferSize:Int = 0
    var channelCount:Int = 0
    var totalSampleCount:Int = 0
    var sourceFormat:CMFormatDescription?
    
    var currentIndex:Int = 0
    var sampleBuffer:CMSampleBuffer?
    var sampleBufferPresentationTime:CMTime?
    var frameDuration:CMTime
    var currentTime:CMTime = CMTime.zero
    
    var progressFactor:CGFloat = 1.0 / 3.0 // 3 contributors
    var cumulativeProgress:CGFloat = 0
    
    let videoQueue: DispatchQueue = DispatchQueue(label: "com.limit-point.time-scale-video-generator-queue")
    let audioQueue: DispatchQueue = DispatchQueue(label: "com.limit-point.time-scale-audio-generator-queue")

        // MARK: Init and Start    
    init?(path : String, desiredDuration: Float64, frameRate: Int32, expedited:Bool, destination: String, progress: @escaping (CGFloat, CIImage?) -> Void, completion: @escaping (URL?, String?) -> Void) {
        
        guard frameRate > 0 else {
            return nil
        }
        
        self.videoURL = URL(fileURLWithPath: path)
        self.desiredDuration = desiredDuration
        
        generatedMovieURL = URL(fileURLWithPath: destination)
        
        self.progressAction = progress
        self.completionAction = completion
        
        videoAsset = AVURLAsset(url: videoURL)
        
        guard let videoTrack = videoAsset?.tracks(withMediaType: .video).first else {
            return nil
        }
        
        self.movieSize = CGSize(width: videoTrack.naturalSize.width, height: videoTrack.naturalSize.height)
        
        ciOrientationTransform = videoAsset.ciOrientationTransform()
        
        let scale:Int32 = 600
        self.frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate)).convertScale(scale, method: CMTimeRoundingMethod.default)
        
        self.expedited = expedited
    }
    
    func start() {
        
        if FileManager.default.fileExists(atPath: generatedMovieURL.path) {
            try? FileManager.default.removeItem(at: generatedMovieURL)
        }
        
        self.createAssetWriter()
        
        self.prepareForReading { (success) in
            
            if success {
                self.prepareForWriting { (success) in
                    
                    if success {
                        self.startAssetWriter()
                        self.writeVideoAndAudio()
                    }
                    else {
                        self.failed()
                    }
                }
            }
            else {
                self.failed()
            }
        }
    }
    
        // MARK: Prepare Readers and Writers   
    func videoReaderSettings() -> [String : Any]? {
        return kVideoReaderSettings
    }
    
    func audioReaderSettings() -> [String : Any]? {
        return kAudioReaderSettings
    }
    
    func videoWriterSettings(width:CGFloat, height:CGFloat) -> [String : Any]? {
        return [AVVideoCodecKey : AVVideoCodecType.h264, AVVideoWidthKey : width, AVVideoHeightKey : height]
    }
    
    func createVideoWriterInput(width:CGFloat, height:CGFloat, transform:CGAffineTransform?) {
        
        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: self.videoWriterSettings(width: width, height: height))
        
        if let transform = transform {
            videoWriterInput.transform = transform
        }
        
        videoWriterInput.expectsMediaDataInRealTime = true
        assetWriter.add(videoWriterInput)
    }
    
    func createAudioWriterInput() {
        
        if let outputSettings = self.audioReaderSettings(),
           let sampleBuffer = self.videoAsset?.audioSampleBuffer(outputSettings:outputSettings),
           let sampleCount = self.videoAsset?.audioBufferAndSampleCounts(outputSettings).sampleCount,
           let sampleBufferSourceFormat = CMSampleBufferGetFormatDescription(sampleBuffer),
           let audioStreamBasicDescription = sampleBufferSourceFormat.audioStreamBasicDescription
        {
            outputBufferSize = sampleBuffer.numSamples
            channelCount = Int(audioStreamBasicDescription.mChannelsPerFrame)
            totalSampleCount = sampleCount
            sourceFormat = sampleBufferSourceFormat
            
            let audioOutputSettings = [AVFormatIDKey: kAudioFormatLinearPCM] as [String : Any]
            
            if assetWriter.canApply(outputSettings: audioOutputSettings, forMediaType: AVMediaType.audio) {
                let audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings:audioOutputSettings, sourceFormatHint: sourceFormat)
                
                audioWriterInput.expectsMediaDataInRealTime = false
                
                if assetWriter.canAdd(audioWriterInput) {
                    assetWriter.add(audioWriterInput)
                    
                    self.audioWriterInput = audioWriterInput
                }
            }
        }
    }
    
    func frameCountAndTimeScale(videoAsset:AVAsset, estimated:Bool = false) -> Bool {
        
        if estimated {
            self.frameCount = videoAsset.estimatedFrameCount()
            self.timeScaleFactor = self.desiredDuration / CMTimeGetSeconds(videoAsset.duration)
            return true
        }
       
        let group = DispatchGroup()
        
        group.enter()
        
        var lastPercent:CGFloat = 0
        
        var lastPresentationTime = CMTime.invalid
        
        var localFrameCount:Int = 0
        let estimatedFrameCount = videoAsset.estimatedFrameCount()
        
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.5) {
            
            if let videoTrack = videoAsset.tracks(withMediaType: .video).first {
                
                if let videoReader = try? AVAssetReader(asset: videoAsset)  {
                    
                    let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: kVideoReaderSettings)
                    videoReader.add(videoReaderOutput)
                    
                    videoReader.startReading()
                    
                    while true, self.isCancelled == false {
                        
                        let sampleBuffer = videoReaderOutput.copyNextSampleBuffer()
                        if sampleBuffer == nil {
                            break
                        }
                        else {
                            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer!)
                            
                            if presentationTime.isValid {
                                lastPresentationTime = presentationTime
                            }
                        }
                        localFrameCount += 1
                        
                        let percent:CGFloat = min(CGFloat(localFrameCount)/CGFloat(estimatedFrameCount), 1.0)
                        self.cumulativeProgress += ((percent - lastPercent) * self.progressFactor)
                        lastPercent = percent
                        self.progressAction(self.cumulativeProgress, nil)
                        
                        print(self.cumulativeProgress)
                    }
                    
                    videoReader.cancelReading()
                }
            }
            
            group.leave()
            
        }
        
        group.wait()
        
        if lastPresentationTime.isValid, localFrameCount > 0, self.isCancelled == false {
            self.frameCount = localFrameCount
            self.timeScaleFactor = self.desiredDuration / CMTimeGetSeconds(lastPresentationTime)
            return true
        }
        
        return false
    }
    
    func prepareForReading(completion: @escaping (Bool) -> ()) {
        
        var success = false
        
        guard let videoAsset = self.videoAsset, self.frameCountAndTimeScale(videoAsset: videoAsset, estimated: self.expedited) else {
            completion(false)
            return
        }
        
            // Video Reader
        let (_, videoReader, videoReaderOutput) = videoAsset.videoReader(outputSettings: kVideoReaderSettings)
        
        if let videoReader = videoReader, let videoReaderOutput = videoReaderOutput, videoReader.canAdd(videoReaderOutput) {
            
            videoReader.add(videoReaderOutput)
            
            self.videoReader = videoReader
            self.videoReaderOutput = videoReaderOutput
            
                // Audio Reader
            var audioTuple = videoAsset.audioReader(outputSettings: self.audioReaderSettings())
            if let audioAsset = self.audioAsset {
                audioTuple = audioAsset.audioReader(outputSettings: self.audioReaderSettings())
            }
            
            if let audioReader = audioTuple.audioReader, let audioReaderOutput = audioTuple.audioReaderOutput, audioReader.canAdd(audioReaderOutput) {
                
                guard audioReader.canAdd(audioReaderOutput) else {
                    completion(false)
                    return
                }
                
                audioReader.add(audioReaderOutput)
                
                self.audioReader = audioReader
                self.audioReaderOutput = audioReaderOutput
            }
            
            success = true
        }
        
        completion(success)
    }
    
    func prepareForWriting(completion: @escaping (Bool) -> ()) {
        
        let transform = videoAsset?.assetTrackTransform()
        
        self.createVideoWriterInput(width: self.movieSize.width, height: self.movieSize.height, transform: transform)
        
        self.createAudioWriterInput()
        
        completion(true)
        
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
    
        // MARK: Video Writing
    func copyNextSampleBufferForResampling(lastPercent:CGFloat) -> CGFloat {
        
        self.sampleBuffer = nil
        
        guard let sampleBuffer = self.videoReaderOutput?.copyNextSampleBuffer() else {
            return 0
        }
        
        self.sampleBuffer = sampleBuffer
        
        if self.videoReaderOutput.outputSettings != nil {
            var presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            
            presentationTimeStamp = CMTimeMultiplyByFloat64(presentationTimeStamp, multiplier: self.timeScaleFactor)
            
            if let adjustedSampleBuffer = sampleBuffer.setTimeStamp(time: presentationTimeStamp) {
                self.sampleBufferPresentationTime = presentationTimeStamp
                self.sampleBuffer = adjustedSampleBuffer
            }
            else {
                self.sampleBuffer = nil
            }
        }
        
        self.currentIndex += 1
        
        let percent:CGFloat = min(CGFloat(self.currentIndex)/CGFloat(self.frameCount), 1.0)
        self.cumulativeProgress += ((percent - lastPercent) * self.progressFactor)
        self.progressAction(self.cumulativeProgress, self.sampleBuffer?.ciimage()?.transformed(by:ciOrientationTransform))
        
        print(self.cumulativeProgress)
        
        return percent
    }
    
    func appendNextSampleBufferForResampling() -> Bool {
        
        var appended = false
        
        if let sampleBuffer = self.sampleBuffer {
            
            if let sampleBufferPresentationTime = self.sampleBufferPresentationTime, self.currentTime != sampleBufferPresentationTime {
                if let adjustedSampleBuffer = sampleBuffer.setTimeStamp(time: self.currentTime) {
                    appended = self.videoWriterInput.append(adjustedSampleBuffer)
                }
            }
            else {
                appended = self.videoWriterInput.append(sampleBuffer)
            }
        }
        
        return appended
    }
    
    func writeVideoOnQueue(_ serialQueue: DispatchQueue) {
        
        guard self.videoReader.startReading() else {
            self.finishVideoWriting()
            return
        }
        
        var lastPercent:CGFloat = 0
        
        videoWriterInput.requestMediaDataWhenReady(on: serialQueue) {
            
            while self.videoWriterInput.isReadyForMoreMediaData, self.writingVideoFinished == false {
                
                if self.currentIndex == 0 {
                    lastPercent = self.copyNextSampleBufferForResampling(lastPercent: lastPercent)
                }
                
                guard self.isCancelled == false else {
                    self.videoReader?.cancelReading()
                    self.finishVideoWriting()
                    return
                }
                
                guard self.sampleBuffer != nil else {
                    self.finishVideoWriting()
                    return
                }
                
                autoreleasepool { () -> Void in
                    
                        // check resampling
                    if let sampleBufferPresentationTime = self.sampleBufferPresentationTime {
                        if self.currentTime <= sampleBufferPresentationTime {
                            
                            if self.appendNextSampleBufferForResampling() {
                                self.currentTime = CMTimeAdd(self.currentTime, self.frameDuration)
                            }
                            else {
                                self.sampleBuffer = nil
                            }
                        }
                        else {
                            lastPercent = self.copyNextSampleBufferForResampling(lastPercent: lastPercent)
                        }
                    }
                    else {
                        
                        if let sampleBufferPresentationTime = self.sampleBufferPresentationTime {
                            self.currentTime = sampleBufferPresentationTime
                        }
                        
                        if self.appendNextSampleBufferForResampling() {
                            lastPercent = self.copyNextSampleBufferForResampling(lastPercent: lastPercent)
                        }
                        else {
                            self.sampleBuffer = nil
                        }
                    }
                }
            }
        }
    }

        // MARK: Audio Writing    
    func extractSamples(_ sampleBuffer:CMSampleBuffer) -> [Int16]? {
        
        if let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
            
            let sizeofInt16 = MemoryLayout<Int16>.size
            
            let bufferLength = CMBlockBufferGetDataLength(dataBuffer)
            
            var data = [Int16](repeating: 0, count: bufferLength / sizeofInt16)
            
            CMBlockBufferCopyDataBytes(dataBuffer, atOffset: 0, dataLength: bufferLength, destination: &data)
            
            return data
        }
        
        return nil
    }
    
    func interleave_arrays(_ arrays:[[Int16]]) -> [Int16]? {
        
        guard arrays.count > 0 else { return nil }
        
        if arrays.count == 1 {
            return arrays[0]
        }
        
        var size = Int.max
        for m in 0...arrays.count-1 {
            size = min(size, arrays[m].count)
        }
        
        guard size > 0 else { return nil }
        
        let interleaved_length = size * arrays.count
        var interleaved:[Int16] = [Int16](repeating: 0, count: interleaved_length)
        
        var count:Int = 0
        for j in 0...size-1 {
            for i in 0...arrays.count-1 {
                interleaved[count] = arrays[i][j]
                count += 1
            }
        }
        
        return interleaved 
    }
    
    func sampleBufferForSamples(audioSamples:[Int16], channelCount:Int, formatDescription:CMAudioFormatDescription) -> CMSampleBuffer? {
        
        var sampleBuffer:CMSampleBuffer?
        
        let bytesInt16 = MemoryLayout<Int16>.stride
        let dataSize = audioSamples.count * bytesInt16
        
        var samplesBlock:CMBlockBuffer? 
        
        let memoryBlock:UnsafeMutableRawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: dataSize,
            alignment: MemoryLayout<Int16>.alignment)
        
        let _ = audioSamples.withUnsafeBufferPointer { buffer in
            memoryBlock.initializeMemory(as: Int16.self, from: buffer.baseAddress!, count: buffer.count)
        }
        
        if CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, 
            memoryBlock: memoryBlock, 
            blockLength: dataSize, 
            blockAllocator: nil, 
            customBlockSource: nil, 
            offsetToData: 0, 
            dataLength: dataSize, 
            flags: 0, 
            blockBufferOut:&samplesBlock
        ) == kCMBlockBufferNoErr, let samplesBlock = samplesBlock {
            
            let sampleCount = audioSamples.count / channelCount
            
            if CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: samplesBlock, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: formatDescription, sampleCount: sampleCount, sampleTimingEntryCount: 0, sampleTimingArray: nil, sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sampleBuffer) == noErr, let sampleBuffer = sampleBuffer {
                
                guard sampleBuffer.isValid, sampleBuffer.numSamples == sampleCount else {
                    return nil
                }
            }
        }
        
        return sampleBuffer
    }
    
    func writeAudioOnQueue(_ serialQueue:DispatchQueue) {
        
        guard let audioReader = self.audioReader, let audioWriterInput = self.audioWriterInput, let audioReaderOutput = self.audioReaderOutput, audioReader.startReading() else {
            self.finishAudioWriting()
            return
        }
        
        let length = Int(Double(totalSampleCount) * self.timeScaleFactor)
        
        guard length > 0 else {
            audioReader.cancelReading()
            self.finishAudioWriting()
            return
        }
        
        let control = Array.control(length: length, count: totalSampleCount, smoothly: true)
        
        var controlBlocks = control.blocks(size: outputBufferSize)
        var controlBlocksOffset = controlBlocks.map {
            vDSP.add(-trunc($0[0]), $0)
        }
        
        var arrays_to_scale = [[Int16]](repeating: [], count: channelCount)
        var scaled_array:[Int16] = []
        
        var nbrItemsRemoved:Int = 0
        var nbrItemsToRemove:Int = 0
        
        controlBlocks.removeFirst()
        
        func update_arrays_to_scale() {
            if nbrItemsToRemove > arrays_to_scale[0].count {
                
                nbrItemsRemoved += arrays_to_scale[0].count
                nbrItemsToRemove = nbrItemsToRemove - arrays_to_scale[0].count
                
                for i in 0...arrays_to_scale.count-1 {
                    arrays_to_scale[i].removeAll()
                }
            }
            else if nbrItemsToRemove > 0 {
                for i in 0...arrays_to_scale.count-1 {
                    arrays_to_scale[i].removeSubrange(0...nbrItemsToRemove-1)
                }
                nbrItemsRemoved += nbrItemsToRemove
                nbrItemsToRemove = 0
            }
        }
        
        func lastIndexAdjusted(_ array:[Double]) -> Int? {
            
            guard array.count > 0, let last = array.last else {
                return nil
            }
            
            var lastIndex = Int(trunc(last))
            if last - trunc(last) > 0 {
                lastIndex += 1
            }
            return lastIndex
        }
        
        var lastPercent:CGFloat = 0
        var bufferSamplesCount:Int = 0
        
        audioWriterInput.requestMediaDataWhenReady(on: serialQueue) {
            while audioWriterInput.isReadyForMoreMediaData, self.writingAudioFinished == false {
                
                if self.isCancelled {
                    audioReader.cancelReading()
                }
                
                if let sampleBuffer = audioReaderOutput.copyNextSampleBuffer() {
                    
                    bufferSamplesCount += sampleBuffer.numSamples
                    
                    if let bufferSamples = self.extractSamples(sampleBuffer) {
                        
                        let channels = bufferSamples.extract_array_channels(channelCount: self.channelCount)
                        
                        for i in 0...arrays_to_scale.count-1 {
                            arrays_to_scale[i].append(contentsOf: channels[i])
                        }
                        
                        update_arrays_to_scale()
                        
                        while true {
                            if let controlBlockOffset = controlBlocksOffset.first,  let indexAdjusted = lastIndexAdjusted(controlBlockOffset), indexAdjusted < arrays_to_scale[0].count {
                                
                                var scaled_channels:[[Int16]] = [] 
                                for array_to_scale in arrays_to_scale {
                                    scaled_channels.append(array_to_scale.scaleToD(control: controlBlockOffset, smoothly: true))
                                }
                                
                                if let scaled_channels_interleaved = self.interleave_arrays(scaled_channels) {
                                    scaled_array.append(contentsOf: scaled_channels_interleaved)
                                }
                                
                                controlBlocksOffset.removeFirst()
                                
                                if let controlBlock = controlBlocks.first {
                                    
                                    let controlBlockIndex = Int(trunc(controlBlock[0]))
                                    
                                    nbrItemsToRemove = nbrItemsToRemove + (controlBlockIndex - nbrItemsRemoved)
                                    
                                    update_arrays_to_scale()
                                    
                                    controlBlocks.removeFirst()
                                }
                            }
                            else {
                                break
                            }
                        }
                        
                        if scaled_array.count > 0 {
                            if let sourceFormat = self.sourceFormat, let scaledBuffer = self.sampleBufferForSamples(audioSamples: scaled_array, channelCount: self.channelCount, formatDescription: sourceFormat), audioWriterInput.append(scaledBuffer) == true {
                                scaled_array.removeAll()
                            }
                            else {
                                audioReader.cancelReading()
                            }
                        }
                    }
                    
                    let percent = Double(bufferSamplesCount)/Double(self.totalSampleCount)
                    self.cumulativeProgress += ((percent - lastPercent) * self.progressFactor)
                    lastPercent = percent
                    self.progressAction(self.cumulativeProgress, nil)
                    
                    print(self.cumulativeProgress)
                }
                else {
                    self.finishAudioWriting()
                }
            }
        }
    }
}

