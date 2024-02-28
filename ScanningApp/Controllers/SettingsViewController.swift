//
//  SettingsViewController.swift
//  ScanningApp
//
//  Created by Henrik Lauronen on 1.2.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import UIKit
import ARKit

@available(iOS 13.0, *)
class SettingsViewController: UIViewController {

    @IBOutlet weak var toggleAutoFocus: UISwitch!
    
    @IBOutlet weak var videoFormatButton: UIButton! {
        didSet {
            print(videoFormatButton.title)
        }
    }
    
    @IBOutlet weak var toggleWorldOrigin: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        
        populateVideoFormatButton()
        
        toggleAutoFocus.setOn(UserDefaults.standard.bool(forKey: "auto_focus"), animated: false)
        toggleWorldOrigin.setOn(UserDefaults.standard.bool(forKey: "world_origin"), animated: false)

        // Do any additional setup after loading the view.
    }
    
    func populateVideoFormatButton() {
        
        let videoFormatList: [ARConfiguration.VideoFormat] = ARWorldTrackingConfiguration.supportedVideoFormats
        
        var menuItems: [UIMenuElement] = []
        let selectionHandler = {
            (action: UIAction) in if #available(iOS 14.0, *) {
                
                let index: Int = (self.videoFormatButton.menu?.children.firstIndex(where: {$0 == action}))!
                UserDefaults.standard.setValue(index, forKey: "video_format")
            }
        }
        
        let defaultExists = UserDefaults.standard.object(forKey: "video_format") != nil
        var selectedFormat = ARWorldTrackingConfiguration.supportedVideoFormats[1]
        if defaultExists {
            selectedFormat = ARWorldTrackingConfiguration.supportedVideoFormats[UserDefaults.standard.integer(forKey: "video_format")]
        }
        
        for format in videoFormatList {
            let title = "\(format.framesPerSecond)Hz, \(format.imageResolution.width)x\(format.imageResolution.height)"
            var state = UIMenuElement.State.off
            
            if format == selectedFormat {
                state = UIMenuElement.State.on
            }
            
            let item = UIAction(title: title, state: state, handler: selectionHandler)
            menuItems.append(item)
        }
                
        if #available(iOS 15.0, *) {
            videoFormatButton.menu = UIMenu(children: menuItems)

            videoFormatButton.showsMenuAsPrimaryAction = true
            videoFormatButton.changesSelectionAsPrimaryAction = true
        }
        
        
    }
    
    @IBAction func isToggledWorldOrigin(_ sender: UISwitch) {
        UserDefaults.standard.setValue(sender.isOn, forKey: "world_origin")
    }
    
    @IBAction func isToggledAutoFocus(_ sender: UISwitch) {
        UserDefaults.standard.setValue(sender.isOn, forKey: "auto_focus")
    }
}
