//
//  ViewController+RefData.swift
//  ScanningApp
//
//  Created by Henrik Lauronen on 6.1.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import AVFoundation
import ARKit

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
            let isRecording = self.videoRecorder?.isRecording ?? false
            if !isRecording {
                let settings = createSettings()
                let transform = CGAffineTransformMakeRotation(CGFloat(Double.pi / 2))
                self.videoRecorder = VideoRecorder(settings: settings, transform: transform)
                
                self.videoRecorder?.startRecording()
            }
        }
    }
    
    func createSettings() -> [String: Any] {
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: self.imgRes?.width ?? 1920,
            AVVideoHeightKey: self.imgRes?.height ?? 1440,
            AVVideoCompressionPropertiesKey: [
                AVVideoPixelAspectRatioKey: [
                    AVVideoPixelAspectRatioHorizontalSpacingKey: 1,
                    AVVideoPixelAspectRatioVerticalSpacingKey: 1
                ],
                AVVideoMaxKeyFrameIntervalKey: 1,
                AVVideoAverageBitRateKey: 16000000
            ]
        ]
        
        return settings
    }
    
    func stopReferenceDataCapture() {
        guard let videoRecorder = videoRecorder else {
            return
        }
        
        if videoRecorder.isRecording {
            videoRecorder.stopRecording { videoURL in self.saveReferenceVideo(tempURL: videoURL) }
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
    
    func saveReferenceVideo(tempURL: URL) {
        debugPrint("Called function: saveReferenceVideo(url=\(tempURL.absoluteString)")
        
        var videoURL: URL?
        if let folderURL = self.folderURL {
            videoURL = folderURL.appendingPathComponent("video.mov")
        }
        
        if FileManager.default.fileExists(atPath: tempURL.path) && FileManager.default.fileExists(atPath: tempURL.path) {
            
            do {
                guard let videoURL = videoURL else {
                    return
                }
                try FileManager.default.copyItem(atPath: tempURL.path, toPath: videoURL.path)
                try FileManager.default.removeItem(atPath: tempURL.path)
            } catch {}
        }
        
    }
    
    func getCMSampleBuffer(pixelBuffer: CVPixelBuffer, scale: CMTimeScale, pts: CMTime) -> CMSampleBuffer? {
        var sampleBuffer: CMSampleBuffer?
        var formatDescription: CMFormatDescription? = nil
        var timingInfo = CMSampleTimingInfo(duration: .invalid, 
                                            presentationTimeStamp: pts,
                                            decodeTimeStamp: .invalid)
        
        
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, 
                                                     imageBuffer: pixelBuffer,
                                                     formatDescriptionOut: &formatDescription)
        
        CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                           imageBuffer: pixelBuffer,
                                           dataReady: true,
                                           makeDataReadyCallback: nil,
                                           refcon: nil,
                                           formatDescription: formatDescription!,
                                           sampleTiming: &timingInfo,
                                           sampleBufferOut: &sampleBuffer)
        
        return sampleBuffer
    }
    
    func processFrame(_ frame: ARFrame) {
        let scale = CMTimeScale(NSEC_PER_SEC)
        let pts = CMTime(value: CMTimeValue(frame.timestamp * Double(scale)),
                         timescale: scale)
        let sampleBuffer: CMSampleBuffer? = getCMSampleBuffer(pixelBuffer: frame.capturedImage, scale: scale, pts: pts)
        guard let sampleBuffer = sampleBuffer else {
            return
        }
        
        self.videoRecorder?.recordVideo(sampleBuffer)
    }
}

