/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Management of the UI steps for scanning an object in the main view controller.
*/

import Foundation
import ARKit
import SceneKit

extension ScanViewController {
    
    enum State {
        case startARSession
        case notReady
        case scanning
        case testing
    }
    
    
    /// - Tag: ARObjectScanningConfiguration
    // The current state the application is in
    var state: State {
        get {
            return self.internalState
        }
        set {
            // 1. Check that preconditions for the state change are met.
            var newState = newValue
            switch newValue {
            case .startARSession:
                break
            case .notReady:
                // Immediately switch to .ready if tracking state is normal.
                if let camera = self.sceneView.session.currentFrame?.camera {
                    switch camera.trackingState {
                    case .normal:
                        newState = .scanning
                    default:
                        break
                    }
                } else {
                    newState = .startARSession
                }
            case .scanning:
                // Immediately switch to .notReady if tracking state is not normal.
                if let camera = self.sceneView.session.currentFrame?.camera {
                    switch camera.trackingState {
                    case .normal:
                        break
                    default:
                        newState = .notReady
                    }
                } else {
                    newState = .startARSession
                }
            case .testing:
                guard scan?.boundingBoxExists == true || referenceObjectToTest != nil else {
                    print("Error: Scan is not ready to be tested.")
                    return
                }
            }
            
            // 2. Apply changes as needed per state.
            internalState = newState
            
            switch newState {
            case .startARSession:
                print("State: Starting ARSession")
                scan = nil
                testRun = nil
                modelURL = nil
                self.setNavigationBarTitle("")
                instructionsVisible = false
                showBackButton(false)
                nextButton.isEnabled = false
                loadModelButton.isHidden = true
                flashlightButton.isHidden = true
                
                // Make sure the SCNScene is cleared of any SCNNodes from previous scans.
                sceneView.scene = SCNScene()
                
                self.enableSliders(isEnabled: false)
                
                let configuration = ARWorldTrackingConfiguration()
                configuration.planeDetection = .horizontal
                if #available(iOS 14.0, *) {
                    let selectedFormat = UserDefaults.standard.integer(forKey: "video_format")
                    configuration.frameSemantics.insert(.sceneDepth)
                    configuration.videoFormat = ARWorldTrackingConfiguration.supportedVideoFormats[selectedFormat]
                    configuration.isAutoFocusEnabled = UserDefaults.standard.bool(forKey: "auto_focus")
                    
                } else {
                    // Fallback on earlier versions
                }
                sceneView.session.run(configuration, options: .resetTracking)
                cancelMaxScanTimeTimer()
                cancelMessageExpirationTimer()
                stopReferenceDataCapture()
            case .notReady:
                print("State: Not ready to scan")
                scan = nil
                testRun = nil
                self.setNavigationBarTitle("")
                loadModelButton.isHidden = true
                flashlightButton.isHidden = true
                showBackButton(false)
                nextButton.isEnabled = false
                nextButton.setTitle("Next", for: [])
                displayInstruction(Message("Please wait for stable tracking"))
                cancelMaxScanTimeTimer()
            case .scanning:
                print("State: Scanning")
                if scan == nil {
                    self.scan = Scan(sceneView)
                    self.scan?.state = .ready
                }
                testRun = nil
                
                //startMaxScanTimeTimer()
            case .testing:
                print("State: Testing")
                self.setNavigationBarTitle("Test")
                loadModelButton.isHidden = true
                flashlightButton.isHidden = false
                showMergeScanButton()
                nextButton.isEnabled = true
                nextButton.setTitle("Share", for: [])
                
                testRun = TestRun(sceneView: sceneView)
                testObjectDetection()
                cancelMaxScanTimeTimer()
            }
            
            NotificationCenter.default.post(name: ScanViewController.appStateChangedNotification,
                                            object: self,
                                            userInfo: [ScanViewController.appStateUserInfoKey: self.state])
        }
    }
    
    @objc
    func scanningStateChanged(_ notification: Notification) {
        guard self.state == .scanning, let scan = notification.object as? Scan, scan === self.scan else { return }
        guard let scanState = notification.userInfo?[Scan.stateUserInfoKey] as? Scan.State else { return }
        
        DispatchQueue.main.async {
            switch scanState {
            case .ready:
                self.stopReferenceDataCapture()
                print("State: Ready to scan")
                self.setNavigationBarTitle("Ready to scan")
                self.showBackButton(false)
                self.nextButton.setTitle("Next", for: [])
                self.nextButton.isHidden = false
                self.loadModelButton.isHidden = true
                self.flashlightButton.isHidden = true
                if scan.ghostBoundingBoxExists {
                    self.displayInstruction(Message("Tap 'Next' to create an approximate bounding box around the object you want to scan."))
                    self.nextButton.isEnabled = true
                } else {
                    self.displayInstruction(Message("Point at a nearby object to scan."))
                    self.nextButton.isEnabled = false
                }
            case .defineBoundingBox:
                self.stopReferenceDataCapture()
                print("State: Define bounding box")
                /*
                self.displayInstruction(Message("Position and resize bounding box using gestures.\n" +
                    "Long press sides to push/pull them in or out. "))*/
                self.setNavigationBarTitle("Define bounding box")
                self.showBackButton(false)
                self.nextButton.isEnabled = scan.boundingBoxExists
                self.loadModelButton.isHidden = true
                self.flashlightButton.isHidden = true
                self.nextButton.isHidden = false
                self.nextButton.setTitle("Scan", for: [])
            case .scanning:
                self.enableSliders(isEnabled: false)
                self.startReferenceDataCapture()
                self.displayInstruction(Message("Scan the object from all sides that you are " +
                    "interested in. Do not move the object while scanning!"))
                if let boundingBox = scan.scannedObject.boundingBox {
                    self.setNavigationBarTitle("Scan (\(boundingBox.progressPercentage)%)")
                } else {
                    self.setNavigationBarTitle("Scan 0%")
                }
                self.showBackButton(false)
                self.nextButton.isEnabled = true
                self.loadModelButton.isHidden = true
                self.flashlightButton.isHidden = true
                self.nextButton.setTitle("Finish", for: [])
                self.nextButton.isHidden = false
                // Disable plane detection (even if no plane has been found yet at this time) for performance reasons.
                self.sceneView.stopPlaneDetection()
                
            case .adjustingOrigin:
                self.stopReferenceDataCapture()
                print("State: Adjusting Origin")
                /*self.displayInstruction(Message("Adjust origin using gestures.\n" +
                    "You can load a *.usdz 3D model overlay."))*/
                self.instructionsVisible = false
                self.setNavigationBarTitle("Scan completed")
                self.showBackButton(false)
                self.nextButton.isEnabled = false
                self.nextButton.isHidden = true
                self.loadModelButton.isHidden = true
                self.flashlightButton.isHidden = true
                self.nextButton.setTitle("Test", for: [])
                let title = "Scan complete"
                let message = "Would you like to start another scan?"
                self.showAlert(title: title, message: message, buttonTitle: "Yes", showCancel: true) { _ in
                    self.restartButtonTapped(self)
                }
            }
        }
    }
    
    func switchToPreviousState() {
        switch state {
        case .startARSession:
            break
        case .notReady:
            state = .startARSession
        case .scanning:
            if let scan = scan {
                switch scan.state {
                case .ready:
                    restartButtonTapped(self)
                case .defineBoundingBox:
                    scan.state = .ready
                case .scanning:
                    scan.state = .defineBoundingBox
                case .adjustingOrigin:
                    scan.state = .scanning
                }
            }
        case .testing:
            state = .scanning
            scan?.state = .adjustingOrigin
        }
    }
    
    func switchToNextState() {
        switch state {
        case .startARSession:
            state = .notReady
        case .notReady:
            state = .scanning
        case .scanning:
            if let scan = scan {
                switch scan.state {
                case .ready:
                    scan.state = .defineBoundingBox
                case .defineBoundingBox:
                    scan.state = .scanning
                case .scanning:
                    scan.state = .adjustingOrigin
                case .adjustingOrigin:
                    state = .testing
                }
            }
        case .testing:
            print("Current state: Testing")
            // Testing is the last state, show the share sheet at the end.
            //createAndShareReferenceObject()
        }
    }
    
    @objc
    func ghostBoundingBoxWasCreated(_ notification: Notification) {
        if let scan = scan, scan.state == .ready {
            DispatchQueue.main.async {
                self.nextButton.isEnabled = true
                self.displayInstruction(Message("Tap 'Next' to create an approximate bounding box around the object you want to scan."))
            }
        }
    }
    
    @objc
    func ghostBoundingBoxWasRemoved(_ notification: Notification) {
        if let scan = scan, scan.state == .ready {
            DispatchQueue.main.async {
                self.nextButton.isEnabled = false
                self.displayInstruction(Message("Point at a nearby object to scan."))
            }
        }
    }
    
    @objc
    func boundingBoxWasCreated(_ notification: Notification) {
        if let scan = scan, scan.state == .defineBoundingBox {
            DispatchQueue.main.async {
                self.enableSliders(isEnabled: true)
                self.sliderTop.value = (scan.scannedObject.boundingBox?.extent.x ?? 0.25) * 2
                self.sliderMid.value = (scan.scannedObject.boundingBox?.extent.y ?? 0.25) * 2
                self.sliderBot.value = (scan.scannedObject.boundingBox?.extent.z ?? 0.25) * 2
                self.nextButton.isEnabled = true
            }
        }
    }
}
