//
//  CMSampleBuffer-extensions.swift
//  ScaleVideo
//
//  Created by Joseph Pagliaro on 3/14/22. 
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import CoreImage
import AVFoundation

extension CMSampleBuffer {
    
    func ciimage() -> CIImage? {
        
        var ciImage:CIImage?
        
        if let imageBuffer = CMSampleBufferGetImageBuffer(self) {
            ciImage = CIImage(cvImageBuffer: imageBuffer)
        }
        
        return ciImage
    }
    
    func setTimeStamp(time: CMTime) -> CMSampleBuffer? {
        var count: CMItemCount = 0
        
        guard CMSampleBufferGetSampleTimingInfoArray(self, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count) == noErr else {
            return nil
        }
        
        var info = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(duration: CMTimeMake(value: 0, timescale: 0), presentationTimeStamp: CMTimeMake(value: 0, timescale: 0), decodeTimeStamp: CMTimeMake(value: 0, timescale: 0)), count: count)
        
        guard CMSampleBufferGetSampleTimingInfoArray(self, entryCount: count, arrayToFill: &info, entriesNeededOut: &count) == noErr else {
            return nil
        }
        
        for i in 0..<count {
            
            if CMTIME_IS_VALID(info[i].decodeTimeStamp) {
                info[i].decodeTimeStamp = time
            }
            
            if CMTIME_IS_VALID(info[i].presentationTimeStamp) {
                info[i].presentationTimeStamp = time
            }
            
        }
        
        var out: CMSampleBuffer?
        guard CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: self, sampleTimingEntryCount: count, sampleTimingArray: &info, sampleBufferOut: &out) == noErr else {
            return nil
        }
        return out
    }
}
