//
//  CIImage-extensions.swift
//  ScaleVideo
//
//  Created by Joseph Pagliaro on 3/15/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import CoreImage

extension CIImage {
    
    func cgimage() -> CGImage? {
        
        var cgImage:CGImage
        
        if let cgi = self.cgImage {
            cgImage = cgi
        }
        else {
            let context = CIContext(options: nil)
            guard let cgi = context.createCGImage(self, from: self.extent) else { return nil }
            cgImage = cgi
        }
        
        return cgImage
    }
}
