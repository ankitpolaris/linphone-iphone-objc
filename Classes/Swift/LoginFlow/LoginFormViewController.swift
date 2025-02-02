//
//  LoginFormViewController.swift
//  linphone
//
//  Created by Ankit Khanna on 14/01/25.
//

import UIKit
import linphonesw
import linphone

struct Configs {
    
    static var domainUrl = "194.163.170.113:5080"
    
}

class LoginFormViewController: UIViewController {

    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var domainTextField: UITextField!
    @IBOutlet weak var transportSegment: UISegmentedControl!
    @IBOutlet weak var displayNameTextField: UITextField!
    
    
    var username: String?
    var password: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
      
    }

    func setup() {
        if let userName = username {
            userNameTextField.text = userName
        }
        if let passWord = password {
            passwordTextField.text = passWord
        }
        self.domainTextField.text = Configs.domainUrl
    }
    
    @IBAction func skipBtnTapped(_ sender: UIButton) {
        self.dismiss(animated: true)
    }
    
    func login() {
        let domainName = Configs.domainUrl
        let username = userNameTextField.text ?? ""
        let password = passwordTextField.text ?? ""
        let displayName = displayNameTextField.text ?? ""
        
        let accountParams = linphone_core_create_account_params(LinphoneManager.getLc())
        guard let addr = linphone_address_new(nil),
              let tmpAddr = linphone_address_new("sip:\(domainName)") else {
            //                   self.displayAssistantConfigurationError()
            return
        }
        linphone_address_set_username(addr, username)
        linphone_address_set_port(addr, linphone_address_get_port(tmpAddr))
        linphone_address_set_domain(addr, linphone_address_get_domain(tmpAddr))
        if !displayName.isEmpty {
            linphone_address_set_display_name(addr, displayName)
        }
        linphone_account_params_set_identity_address(accountParams, addr)
        
            
        let selectedSegmentIndex = transportSegment.selectedSegmentIndex
        if selectedSegmentIndex != UISegmentedControl.noSegment {
              let type = transportSegment.titleForSegment(at: selectedSegmentIndex)?.lowercased() ?? ""
            let sipAddressString = String(format: "sip:%@;transport=%@", domainName, type)
              
              // Create LinphoneAddress in Swift
              if let transportAddr = linphone_address_new(sipAddressString.cString(using: .utf8)) {
                  // Create the list using transportAddr
                  let transportAddrRawPointer = UnsafeMutableRawPointer(transportAddr)
                  linphone_account_params_set_routes_addresses(accountParams, bctbx_list_new(transportAddrRawPointer))
                  
                  // Set the server address
                  let serverAddrString = String(format: "%@;transport=%@", domainName, type)
                  linphone_account_params_set_server_addr(accountParams, serverAddrString.cString(using: .utf8))
                  
                  // Unref the LinphoneAddress after use
                  linphone_address_unref(transportAddr)
              }
          }
        
        
        linphone_account_params_set_publish_enabled(accountParams, false ? 1 : 0)
        linphone_account_params_set_register_enabled(accountParams, true ? 1 : 0)
        
        let info = linphone_auth_info_new(
            linphone_address_get_username(addr),
            nil,
            password,
            nil,
            linphone_address_get_domain(addr),
            linphone_address_get_domain(addr)
        )
        linphone_core_add_auth_info(LinphoneManager.getLc(), info)
        linphone_address_unref(addr)
        linphone_address_unref(tmpAddr)
        
        if let account = linphone_core_create_account(LinphoneManager.getLc(), accountParams) {
            linphone_account_params_unref(accountParams)
            
            if linphone_core_add_account(LinphoneManager.getLc(), account) != -1 {
                linphone_core_set_default_account(LinphoneManager.getLc(), account)
                
                LinphoneManager.instance()?.fastAddressBook?.fetchContactsInBackGroundThread()
                PhoneMainView.instance()?.changeCurrentView(DialerView.compositeViewDescription())
            } else {
                //                self.displayAssistantConfigurationError()
            }
        } else {
            //            self.displayAssistantConfigurationError()
        }
    }
    
    
}
