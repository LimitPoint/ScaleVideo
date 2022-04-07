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
        
        guard CMSampleBufferGetSampleTimingInfoArray(self, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count) == noErr, count == 1 else {
            return nil
        }
        
        let timingInfoArray = [CMSampleTimingInfo(duration: CMTime.invalid, presentationTimeStamp: time, decodeTimeStamp: CMTime.invalid)]
        
        var sampleBuffer: CMSampleBuffer?
        guard CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: self, sampleTimingEntryCount: count, sampleTimingArray: timingInfoArray, sampleBufferOut: &sampleBuffer) == noErr else {
            return nil
        }
        return sampleBuffer
    }
}
