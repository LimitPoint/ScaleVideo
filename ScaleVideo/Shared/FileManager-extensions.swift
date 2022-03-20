//
//  FileManager-extensions.swift
//  ScaleVideo
//
//  Created by Joseph Pagliaro on 3/11/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation

extension FileManager {
    
    class func documentsURL() -> URL? {
        var documentsURL: URL?
        
        do {
            documentsURL = try FileManager.default.url(for:.documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        }
        catch {
            return nil
        }
        
        return documentsURL
    }

    
    class func documentsURL(_ filename:String?) -> URL? {
        
        let fm = FileManager.default
        
        guard let documentsDirectoryURL = FileManager.documentsURL() else {
            return nil
        }
        
        if FileManager.default.fileExists(atPath: documentsDirectoryURL.path) == false {
            do {
                try fm.createDirectory(at: documentsDirectoryURL, withIntermediateDirectories: true, attributes:nil)
            }
            catch {
                return nil
            }
        }
        
        var destinationURL = documentsDirectoryURL
        
        if let filename = filename {
            destinationURL = documentsDirectoryURL.appendingPathComponent(filename)
        }
        
        return destinationURL
    }
    
    class func clearDocuments() {
        FileManager.clear(directoryURL: FileManager.documentsURL())
    }
    
    class func clear(directoryURL:URL?) {
        
        guard let directoryURL = directoryURL else {
            return
        }
        
        let fileManager = FileManager.default
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory( at: directoryURL, includingPropertiesForKeys: nil, options: [])
            for file in directoryContents {
                do {
                    try fileManager.removeItem(at: file)
                }
                catch let error as NSError {
                    debugPrint("Ooops! Something went wrong: \(error)")
                }
            }
        } catch let error as NSError {
            print(error.localizedDescription)
        }
    }
}
