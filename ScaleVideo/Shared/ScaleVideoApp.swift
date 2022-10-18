//
//  ScaleVideoApp.swift
//  Shared
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/scale-video/#scale-video-app
//
//  Created by Joseph Pagliaro on 3/13/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

@main
struct ScaleVideoApp: App {
        
    init() {
        FileManager.clearDocuments()
    }
    
    var body: some Scene {
        WindowGroup {
            ScaleVideoAppView(scaleVideoObservable: ScaleVideoObservable())
        }
    }
}
