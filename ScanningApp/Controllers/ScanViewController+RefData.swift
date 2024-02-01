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

extension ScanViewController
{
    enum CaptureState {
        case ready
        case capturing
    }
    
    func startReferenceDataCapture() {
        frameCount = 0
        if createRefDataDirectory() {
            writeBoundingBoxData()
            captureStateValue = .capturing
            
            let settings = getRGBSettings()
            let transform = CGAffineTransformMakeRotation(CGFloat(Double.pi / 2))
            //let transform = CGAffineTransformMakeRotation(0)
           
            self.videoRecorder = VideoRecorder(settings: settings, transform: transform)
            
            self.videoRecorder?.startRecording()
        }
    }
    
    func stopReferenceDataCapture() {
        videoRecorder?.stopRecording{
            videoURL in self.saveReferenceVideo(tempURL: videoURL)
        }
        captureStateValue = .ready
    }
    
    func createRefDataDirectory() -> Bool {
        let folderStr = "scan_" + getCurrentDateAsString()
        guard let rootURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {return false}
        
        self.folderURL = rootURL.appendingPathComponent(folderStr)

        print("Creating directory for reference data: \(String(describing: folderURL!.absoluteString))")
    
        do {
            try FileManager.default.createDirectory(atPath: folderURL!.path, withIntermediateDirectories: true)
            
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
        let rgbExtHeader = "frame," +
        "m_11,m_21,m_31,m_41," +
        "m_12,m_22,m_32,m_42," +
        "m_13,m_23,m_33,m_43," +
        "m_14,m_24,m_34,m_44,\n"
        
        do {
            try rgbExtHeader.write(to: rgbExtFilename, atomically: true, encoding: .utf8)
        } catch {}
        
        // Initialize bounding box file
        guard let bbFilename = self.folderURL?.appendingPathComponent("bounding_box.txt") else { return false }
        let bbHeader = "extent_x,extent_y,extent_z," +
        "m_11,m_21,m_31,m_41," +
        "m_12,m_22,m_32,m_42," +
        "m_13,m_23,m_33,m_43," +
        "m_14,m_24,m_34,m_44,\n"
        
        do {
            try bbHeader.write(to: bbFilename, atomically: true, encoding: .utf8)
        } catch {}
        
        
        return true
    }
    
    
    func getRGBSettings() -> [String: Any] {
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: self.imgRes?.width ?? 1920,
            AVVideoHeightKey: self.imgRes?.height ?? 1440,
            //AVVideoCompressionPropertiesKey: [
            //    AVVideoPixelAspectRatioKey: [
            //        AVVideoPixelAspectRatioHorizontalSpacingKey: 1,
            //        AVVideoPixelAspectRatioVerticalSpacingKey: 1
            //    ],
            //    AVVideoMaxKeyFrameIntervalKey: 1,
            //    AVVideoAverageBitRateKey: 16000000
            //]
        ]
        
        return settings
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
    
    func processFrame(_ frame: ARFrame, time: TimeInterval) {
        if captureStateValue == .ready {
            return
        }
        
        
        defer {
            self.frameCount += 1
        }
        //let sampleRate: UInt = 2
        
        if #available(iOS 14.0, *) {
            //let transform = CGAffineTransformMakeRotation(CGFloat(3 * Double.pi / 2))
            
            let scale = CMTimeScale(NSEC_PER_SEC)
            let pts = CMTime(value: CMTimeValue(time * Double(scale)),
                             timescale: scale)
            let pixelBuffer = frame.capturedImage
            
            if let rgbImage = self.getCMSampleBuffer(pixelBuffer: pixelBuffer, scale: scale, pts: pts) {
                self.videoRecorder?.recordVideo(rgbImage)
            }
            
            let depthImage = frame.sceneDepth!.depthMap
            let confidenceImage = frame.sceneDepth!.confidenceMap!
            
            let index = self.frameCount
            
            let depthURL  = self.folderURL?.appendingPathComponent("depth").appendingPathComponent("depth_\(index).bin")
            
            let confidenceURL  = self.folderURL?.appendingPathComponent("confidence").appendingPathComponent("confidence_\(index).bin")
            
            let depthArray = depthMapToArray(pixelBuffer: depthImage)
            let confidenceArray = confidenceMapToArray(pixelBuffer: confidenceImage)
            
            DispatchQueue.global().async {
                self.writeFloat32ArrayToFolder(array: depthArray,
                                                   url: depthURL!)
                    
                self.writeUInt8ArrayToFolder(array: confidenceArray,
                                                   url: confidenceURL!)
            }
            
            self.writeRGBCameraIntrinsics(intrinsics: frame.camera.intrinsics, frame: index)
            self.writeRGBCameraExtrinsics(extrinsics: frame.camera.transform, frame: index)
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
        
        //frame,m_11,m_12,m_13,m_14,m_21,m_22,m_23,m_24,m_31,m_32,m_33,m_34,m_41,m_42,m_43,m_44
        let data = "\(frame)," +
            "\(extrinsics.columns.0.x),\(extrinsics.columns.1.x),\(extrinsics.columns.2.x),\(extrinsics.columns.3.x)," +
            "\(extrinsics.columns.0.y),\(extrinsics.columns.1.y),\(extrinsics.columns.2.y),\(extrinsics.columns.3.y)," +
            "\(extrinsics.columns.0.z),\(extrinsics.columns.1.z),\(extrinsics.columns.2.z),\(extrinsics.columns.3.z)," +
        "\(extrinsics.columns.0.x),\(extrinsics.columns.1.y),\(extrinsics.columns.2.w),\(extrinsics.columns.3.w)\n"
        
        do {
            try data.appendToURL(fileURL: filename)
        } catch {}
    }
    
    func writeBoundingBoxData() {
        guard let filename = self.folderURL?.appendingPathComponent("bounding_box.txt") else { return }
        
        //extent_x,extent_y,extent_z,m_11,m_21,m_31,m_41,m_12,m_22,m_32,m_42,m_13,m_23,m_33,m_43,m_14,m_24,m_34,m_44
        let data = "\(boundingBoxExtent.x),\(boundingBoxExtent.y),\(boundingBoxExtent.z)," +
        "\(boundingBoxTransform.m11),\(boundingBoxTransform.m21),\(boundingBoxTransform.m31),\(boundingBoxTransform.m41)," +
        "\(boundingBoxTransform.m12),\(boundingBoxTransform.m22),\(boundingBoxTransform.m32),\(boundingBoxTransform.m42)," +
        "\(boundingBoxTransform.m13),\(boundingBoxTransform.m23),\(boundingBoxTransform.m33),\(boundingBoxTransform.m43)," +
        "\(boundingBoxTransform.m14),\(boundingBoxTransform.m24),\(boundingBoxTransform.m34),\(boundingBoxTransform.m44)\n"
        
        do {
            try data.appendToURL(fileURL: filename)
        } catch {}
    }
    
    func writeFloat32ArrayToFolder(array: [[Float32]], url: URL) {
        
        let rows = array.count
        let cols = array[0].count
        var flattened = array.flatMap{$0}
        
        let data = Data(bytes: &flattened, count: MemoryLayout<Float32>.size * rows * cols)
        do {
            try data.write(to: url)
        } catch {}
    }
    
    
    func writeUInt8ArrayToFolder(array: [[UInt8]], url: URL) {
        
        let rows = array.count
        let cols = array[0].count
        var flattened = array.flatMap{$0}
        
        let data = Data(bytes: &flattened, count: MemoryLayout<UInt8>.size * rows * cols)
        do {
            try data.write(to: url)
        } catch {}
    }
    
    func depthMapToArray(pixelBuffer: CVPixelBuffer) -> [[Float32]] {
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        }
        
        //let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var array: [[Float32]] = Array(repeating: Array(repeating: 0, count: width), count: height)
        
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        //let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        let floatBuffer = unsafeBitCast(baseAddress, to: UnsafeMutablePointer<Float32>.self)
        
        for row in 0 ..< height {
            for col in 0 ..< width {
                let index = row * width + col
                array[row][col] = floatBuffer[index]
            }
        }
        
        return array
    }
    
    func confidenceMapToArray(pixelBuffer: CVPixelBuffer) -> [[UInt8]] {
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        }
        
        //let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var array: [[UInt8]] = Array(repeating: Array(repeating: 0, count: width), count: height)
        
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        //let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        let floatBuffer = unsafeBitCast(baseAddress, to: UnsafeMutablePointer<UInt8>.self)
        
        for row in 0 ..< height-1 {
            for col in 0 ..< width-1 {
                let index = row * width + col
                array[row][col] = floatBuffer[index]
            }
        }
        
        return array
    }
}

