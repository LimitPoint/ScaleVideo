//
//  ScaleVideoApp.swift
//  Shared
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
