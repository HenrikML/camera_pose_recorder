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
    
    enum CaptureState {
        case ready
        case capturing
    }
    
    
    func startReferenceDataCapture() {
        frameCount = 0
        if createRefDataDirectory() {
            captureStateValue = .capturing
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
        captureStateValue = .ready
    }
    
    func createRefDataDirectory() -> Bool {
        let folderStr = "scan_" + getCurrentDateAsString()
        guard let rootURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {return false}
        
        self.folderURL = rootURL.appendingPathComponent(folderStr)

        print("Creating directory for reference data: \(String(describing: folderURL!.absoluteString))")
    
        do {
            try FileManager.default.createDirectory(atPath: folderURL!.path, withIntermediateDirectories: true)
            
            try FileManager.default.createDirectory(atPath: folderURL!.appendingPathComponent("video").path, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(atPath: folderURL!.appendingPathComponent("depth").path, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(atPath: folderURL!.appendingPathComponent("confidence").path, withIntermediateDirectories: true)
        } catch
        {
            fatalError("Could not create directory: \(String(describing: folderURL!.absoluteString))")
        }
        
        // Initialize RGB intrinsics file
        guard let rgbIntFilename = self.folderURL?.appendingPathComponent("rgb_intrinsics.txt") else { return false }
        let rgbIntHeader = "frame,f_x,f_y,sigma_x,sigma_y\n"
       
        do {
            try rgbIntHeader.write(to: rgbIntFilename, atomically: true, encoding: .utf8)
        } catch {}
        
        // Initialize RGB extrinsics file
        guard let rgbExtFilename = self.folderURL?.appendingPathComponent("rgb_extrinsics.txt") else { return false }
        let rgbExtHeader = "frame,r_11,r_12,r_13,r_21,r_22,r_23,r_31,r_32,r_33,t_x,t_y,t_z\n"
        
        do {
            try rgbExtHeader.write(to: rgbExtFilename, atomically: true, encoding: .utf8)
        } catch {}
         
        return true
    }
    
    func getCurrentDateAsString() -> String
    {
        let date = Date()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        dateFormatter.timeZone = TimeZone.current
        
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
        if captureStateValue == .ready {
            return
        }
        
        defer {
            self.frameCount += 1
        }
        let sampleRate: UInt = 4
        
        if #available(iOS 14.0, *), self.frameCount.isMultiple(of: sampleRate) {
            let transform = CGAffineTransformMakeRotation(CGFloat(3 * Double.pi / 2))
            
            let rgbImage = CIImage(cvPixelBuffer: frame.capturedImage)
            let depthImage = CIImage(cvPixelBuffer: frame.sceneDepth!.depthMap)
            let confidenceImage = CIImage(cvPixelBuffer: frame.sceneDepth!.confidenceMap!)
            
            let context = CIContext()
            let index = self.frameCount/sampleRate
            
            let videoURL  = self.folderURL?.appendingPathComponent("video").appendingPathComponent("rgb_\(index).png")
            
            let depthURL  = self.folderURL?.appendingPathComponent("depth").appendingPathComponent("depth_\(index).png")
            
            let confidenceURL  = self.folderURL?.appendingPathComponent("confidence").appendingPathComponent("confidence_\(index).png")
            let intrinsics = frame.camera.intrinsics
            let extrinsics = frame.camera.transform
            DispatchQueue.global().async {
                do {
                    
                    try  context.writePNGRepresentation(of: rgbImage.transformed(by: transform),
                                                        to: videoURL!,
                                                        format: .RGBA8,
                                                        colorSpace: rgbImage.colorSpace!)
                    try  context.writePNGRepresentation(of: depthImage.transformed(by: transform),
                                                        to: depthURL!,
                                                        format: .Lf,
                                                        colorSpace: depthImage.colorSpace!)
                    try  context.writePNGRepresentation(of: confidenceImage.transformed(by: transform),
                                                        to: confidenceURL!,
                                                        format: .Lf,
                                                        colorSpace: confidenceImage.colorSpace!)
                  
                } catch {}
                // TODO: Capture bounding box data
                
            }
            
            self.writeRGBCameraIntrinsics(intrinsics: intrinsics, frame: index)
            self.writeRGBCameraExtrinsics(extrinsics: extrinsics, frame: index)
        } else {
            // Fallback on earlier versions
        }
        
    }
    
    func writeRGBCameraIntrinsics(intrinsics: simd_float3x3, frame: UInt) {
        guard let filename = self.folderURL?.appendingPathComponent("rgb_intrinsics.txt") else { return }
        //frame,f_x,f_y,sigma_x,sigma_y
        let data = "\(frame)," +
            "\(intrinsics.columns.0.x)," +
            "\(intrinsics.columns.1.y)," +
            "\(intrinsics.columns.2.x)," +
            "\(intrinsics.columns.2.y)\n"
        
        do {
            try data.appendToURL(fileURL: filename)
        } catch {}
    }
    
    func writeRGBCameraExtrinsics(extrinsics: simd_float4x4, frame: UInt) {
        guard let filename = self.folderURL?.appendingPathComponent("rgb_extrinsics.txt") else { return }
        
        //frame,r_11,r_12,r_13,r_21,r_22,r_23,r_31,r_32,r_33,t_x,t_y,t_z
        let data = "\(frame)," +
            "\(extrinsics.columns.0.x),\(extrinsics.columns.1.x),\(extrinsics.columns.2.x)," +
            "\(extrinsics.columns.0.y),\(extrinsics.columns.1.y),\(extrinsics.columns.2.y)," +
            "\(extrinsics.columns.0.z),\(extrinsics.columns.1.z),\(extrinsics.columns.2.z)," +
            "\(extrinsics.columns.3.x),\(extrinsics.columns.3.y),\(extrinsics.columns.3.z)\n"
        
        do {
            try data.appendToURL(fileURL: filename)
        } catch {}
    }
}

