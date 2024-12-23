//
//  LoginViewController.swift
//  linphone
//
//  Created by Ankit Khanna on 19/12/24.
//

import UIKit

extension UIColor {
    convenience init(hexWithString: String) {
        var hexSanitized = hexWithString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexSanitized.hasPrefix("#") {
            hexSanitized.remove(at: hexSanitized.startIndex)
        }
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

class LoginViewController: UIViewController {

    
    @IBOutlet weak var loginViaQr: UIButton!
    @IBOutlet weak var loginViaSip: UIButton!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        // Do any additional setup after loading the view.
    }
    
    func setupUI() {
        self.loginViaQr.layer.borderWidth = 1.0
        self.loginViaQr.layer.borderColor = UIColor(hexWithString: "303030").cgColor
        self.loginViaSip.layer.borderWidth = 1.0
        self.loginViaSip.layer.borderColor = UIColor(hexWithString: "303030").cgColor
    }
    
    
    @IBAction func loginViaSipBtnTapped(_ sender: UIButton) {
        
        
    }
    
    @IBAction func skipBtnTapped(_ sender: UIButton) {
        self.dismiss(animated: true)
    }
    
    @IBAction func loginViaQrBtnTapped(_ sender: UIButton) {
        
    }
    
 

}
