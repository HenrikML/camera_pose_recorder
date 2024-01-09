//
//  ViewController+RefData.swift
//  ScanningApp
//
//  Created by Henrik Lauronen on 6.1.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import AVFoundation

extension ViewController
{
    struct CameraMetadata {
        var url:URL?
        var cameraFPS:Double = 0
        var cameraResolutionW:Int32 = 0
        var cameraResolutionH:Int32 = 0
    }
    
    func startReferenceDataCapture() {
        if createRefDataDirectory() {
            guard let videoRecorder = videoRecorder else {
                return
            }
            
            if !videoRecorder.isRecording {
                videoRecorder.startRecording()
            }
        }
    }
    
    func stopReferenceDataCapture() {
        guard let videoRecorder = videoRecorder else {
            return
        }
        guard let folderURL = folderURL else {
            return
        }
        if videoRecorder.isRecording {
            videoRecorder.stopRecording(completion: folderURL)
        }
    }
    
    func createRefDataDirectory() -> Bool {
        let folderStr = "ref_" + getCurrentDateAsString()
        guard let rootURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {return false}
        
        self.folderURL = rootURL.appendingPathComponent(folderStr)

        print("Creating directory for reference data: \(String(describing: folderURL!.absoluteString))")
    
        do {
            try FileManager.default.createDirectory(atPath: folderURL!.path, withIntermediateDirectories: true)
        } catch
        {
            fatalError("Could not create directory: \(String(describing: folderURL!.absoluteString))")
        }
        return true
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

