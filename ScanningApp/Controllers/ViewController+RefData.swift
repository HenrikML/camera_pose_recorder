//
//  ViewController+RefData.swift
//  ScanningApp
//
//  Created by Henrik Lauronen on 6.1.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation

extension ViewController
{
    func startReferenceDataCapture() {
        createRefDataDirectory()
    }
    
    func createRefDataDirectory() {
        let folderStr = "ref_" + getCurrentDateAsString()
        guard let rootURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {return}
        
        self.folderURL = rootURL.appendingPathComponent(folderStr)

        print("Creating directory for reference data: \(String(describing: folderURL!.absoluteString))")
    
        do {
            try FileManager.default.createDirectory(atPath: folderURL!.path, withIntermediateDirectories: true)
        } catch
        {
            fatalError("Could not create directory: \(String(describing: folderURL!.absoluteString))")
        }
    }
    
    func getCurrentDateAsString() -> String
    {
        let date = Date()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        return dateFormatter.string(from: date)
    }
    
}

