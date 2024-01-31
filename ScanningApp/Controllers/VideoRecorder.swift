/*
See LICENSE folder for this sample's licensing information.
*/

import Foundation
import AVFoundation

class VideoRecorder {
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var transform: CGAffineTransform
    private var settings: [String: Any]
    private(set) var isRecording = false
    
    
    
    init(settings: [String: Any], transform: CGAffineTransform) {
        self.settings = settings
        self.transform = transform
    }
    
    func startRecording() {
        let outputFileName = NSUUID().uuidString
        let outputFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(outputFileName).appendingPathExtension("MOV")
        
        guard let assetWriter = try? AVAssetWriter(url: outputFileURL, fileType: .mov) else {
            return
        }
        
        let assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        assetWriterInput.expectsMediaDataInRealTime = true
        assetWriterInput.transform = transform
        assetWriter.add(assetWriterInput)
        
        self.assetWriter = assetWriter
        self.assetWriterInput = assetWriterInput
        
        isRecording = true
    }
    
    func stopRecording(completion: @escaping (URL) -> Void) {
        guard let assetWriter = self.assetWriter else {
            return
        }
        
        self.isRecording = false
        self.assetWriter = nil
        
        assetWriter.finishWriting {
            completion(assetWriter.outputURL)
        }
    }
    
    func recordVideo(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording, let assetWriter = assetWriter else {
            print("ERROR: recordVideo failed")
            return
        }
        
        switch assetWriter.status {
        case .unknown:
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            
            if let input = assetWriterInput,
               input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        case .writing:
            if let input = assetWriterInput,
               input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        case .completed:
            print("Asset writer completed")
        case .failed:
            if let error = assetWriter.error {
                print(error)
                fatalError(error.localizedDescription)
            }
        case .cancelled:
            print("Asset writer failed")
        default:
            print("Default case")
        }
    }
    
    func warmup() {
        
        let outputFileName = NSUUID().uuidString
        let outputFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(outputFileName).appendingPathExtension("MOV")
        
        guard let assetWriter = try? AVAssetWriter(url: outputFileURL, fileType: .mov) else {
            return
        }
        
        let assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        assetWriterInput.expectsMediaDataInRealTime = true
        assetWriterInput.transform = transform
        assetWriter.add(assetWriterInput)
        
        self.assetWriter = assetWriter
        self.assetWriterInput = assetWriterInput
        
        self.isRecording = true
        
        assetWriter.startWriting()
        assetWriter.finishWriting{}
        
        self.isRecording = false
        self.assetWriter = nil
    }
}
