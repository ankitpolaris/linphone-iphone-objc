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

protocol QRCodeScannerDelegate: AnyObject {
    func didScanQRCode(_ code: String)
}

class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    weak var delegate: QRCodeScannerDelegate? // Delegate property

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("Your device does not support scanning a QR code.")
            return
        }

        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("Unable to create video input: \(error)")
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            print("Failed to add video input.")
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            print("Failed to add metadata output.")
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        captureSession.startRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()

        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            found(code: stringValue)
        }

        dismiss(animated: true)
    }

    func found(code: String) {
        print("QR Code Found: \(code)")
        delegate?.didScanQRCode(code)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}


class LoginViewController: UIViewController, QRCodeScannerDelegate {

    var username: String?
    var password: String?
    @IBOutlet weak var loginViaQr: UIButton!
    @IBOutlet weak var loginViaSip: UIButton!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
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
        
        let scannerVC = QRCodeScannerViewController()
        scannerVC.delegate = self
        present(scannerVC, animated: true)
        
    }
    
    func didScanQRCode(_ code: String) {
        print("Scanned QR Code: \(code)")
        
        if code != "" && code.contains(":") {
            let parts = code.components(separatedBy: ":")
            username = parts[0].trimmingCharacters(in: .whitespaces)
            password = parts[1].trimmingCharacters(in: .whitespaces)
            
            self.performSegue(withIdentifier: "LoginFormViewController", sender: nil)
        }
        else {
            let alert = UIAlertController(title: "Invalid QR Code",
                                          message: "The scanned QR code is not valid. Please try again.",
                                          preferredStyle: .alert)
            
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(okAction)
            
            self.present(alert, animated: true)
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "LoginFormViewController" {
            if let destinationVC = segue.destination as? LoginFormViewController {
                destinationVC.username = username
                destinationVC.password = password
            }
        }
    }
 

}
