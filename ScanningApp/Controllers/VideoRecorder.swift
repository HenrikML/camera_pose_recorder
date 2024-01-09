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
        guard let assetWriter = assetWriter else {
            return
        }
        
        self.isRecording = false
        self.assetWriter = nil
        
        assetWriter.finishWriting {
            completion(assetWriter.outputURL)
        }
    }
    
    func recordVideo(sampleBuffer: CMSampleBuffer) {
        guard isRecording,
              let assetWriter = assetWriter else {
            return
        }
        
        if assetWriter.status == .unknown {
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        } else if assetWriter.status == .writing {
            if let input = assetWriterInput,
               input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        }
    }
}
