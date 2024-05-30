/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main application delegate.
*/

import UIKit
import ARKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        guard ARObjectScanningConfiguration.isSupported, ARWorldTrackingConfiguration.isSupported else {
            fatalError("""
                ARKit is not available on this device. For apps that require ARKit
                for core functionality, use the `arkit` key in the key in the
                `UIRequiredDeviceCapabilities` section of the Info.plist to prevent
                the app from installing. (If the app can't be installed, this error
                can't be triggered in a production scenario.)
                In apps where AR is an additive feature, use `isSupported` to
                determine whether to show UI for launching AR experiences.
            """) // For details, see https://developer.apple.com/documentation/arkit
        }
        
        if #unavailable(iOS 15.0) {
            fatalError("Incorrect iOS version. iOS 15.0 or greater is required.")
        }
        
        self.window = UIWindow(frame: UIScreen.main.bounds)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        let rootController = storyboard.instantiateViewController(withIdentifier: "nav_controller")
        self.window?.rootViewController = rootController
        self.window?.makeKeyAndVisible()
        
        
        if UserDefaults.standard.object(forKey: "video_format") == nil {
            UserDefaults.standard.setValue(1, forKey: "video_format")
        }
        
        if UserDefaults.standard.object(forKey: "auto_focus") == nil {
            UserDefaults.standard.setValue(true, forKey: "auto_focus")
        }
        
        if UserDefaults.standard.object(forKey: "world_origin") == nil {
            UserDefaults.standard.setValue(false, forKey: "world_origin")
        }
        
        if UserDefaults.standard.object(forKey: "world_origin_to_bb_origin") == nil {
            UserDefaults.standard.setValue(false, forKey: "world_origin_to_bb_origin")
        }
        
        return true
    }
    
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if let viewController = self.window?.rootViewController as? ScanViewController {
            viewController.readFile(url)
            return true
        } else {
            return false
        }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        if let viewController = self.window?.rootViewController as? ScanViewController {
            viewController.backFromBackground()
        }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        if let viewController = self.window?.rootViewController as? ScanViewController {
            viewController.blurView?.isHidden = false
        }
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        if let viewController = self.window?.rootViewController as? ScanViewController {
            viewController.blurView?.isHidden = true
        }
    }
}
