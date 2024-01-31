//
//  MainMenuViewController.swift
//  ScanningApp
//
//  Created by Henrik Lauronen on 31.1.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import UIKit

class MainMenuViewController: UIViewController {

    @IBOutlet private weak var btnScan: UIButton!
    @IBOutlet private weak var btnSettings: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func didTapScanButton() {
        let vc = storyboard?.instantiateViewController(withIdentifier: "scan_vc") as! ScanViewController
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
