//
//  LoginVC.swift
//  WM
//
//  Created by Admin on 10/10/18.
//  Copyright © 2018 Admin. All rights reserved.
//

import UIKit
import MBProgressHUD

class LoginVC: WMBaseVC, UITextFieldDelegate {

    @IBOutlet weak var txtEmail: SkyFloatingLabelTextField!
    @IBOutlet weak var txtPassword: SkyFloatingLabelTextField!
    @IBOutlet weak var btnCheck: UIButton!
    @IBOutlet weak var navBarHeight: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        WMGlobal.adjustNavBarHeight(constraint: navBarHeight)
    }
    
    @IBAction func onBackPressed(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func onCheckPressed(_ sender: Any) {
        btnCheck.isSelected = !btnCheck.isSelected
    }
    
    @IBAction func onLoginPressed(_ sender: Any) {
        if !(self.txtEmail.text?.isEmail ?? false) {
            self.txtEmail.errorMessage = "Email is required"
            return
        } else if self.txtPassword.text?.trimmed.isEmpty ?? true {
            self.txtPassword.errorMessage = "Password is required"
            return
        }
        
        //oldLogin(email: self.txtEmail.text ?? "", password: self.txtPassword.text ?? "") // REMOVE
        login(email: self.txtEmail.text ?? "", password: self.txtPassword.text ?? "")
    }

    // REMOVE: NO LONGER USING
    func oldLogin(email: String, password: String) {
        MBProgressHUD.showAdded(to: self.view, animated: true)
        WMAPIManager.sharedManager.login(email: email, password: password, completion: {(data1) in
            guard let data1 = data1 else {
                MBProgressHUD.hide(for: self.view, animated: true)
                WMGlobal.showAlert(title: "", message: "Server error", target: self)
                return
            }
            if (DEBUG_LOG) { NSLog("*** oldLogin() data1: \(data1)") } // TEST TO REMOVE

                if (data1["success"] as? Bool) ?? false {
                    WMAPIManager.sharedManager.getAccountInfo(email: email, completion: { (data2) in
                        
                        WMAPIManager.sharedManager.getCookieData(email: email, password: password, completion: { (cookieData) in
                            
                            guard let loggedInSig = cookieData["logged-in-sig"] as? HTTPCookie,
                                let loggedInUser = cookieData["logged-in-user"] as? HTTPCookie else {
                                    MBProgressHUD.hide(for: self.view, animated: true)
                                    WMGlobal.showAlert(title: "", message: "Server error", target: self)
                                    return
                            }
                            
                            WMAPIManager.sharedManager.getIAS3Keys(params: ["logged-in-sig": loggedInSig.value, "logged-in-user": loggedInUser.value], completion: { (key) in
                                
                                if let key = key, let data2 = data2,
                                   let values = data2["values"] as? [String: Any],
                                   let screenname = values["screenname"] as? String
                                {
                                    WMGlobal.saveUserData(userData: [
                                        "email"             : email,
                                        "password"          : password,
                                        "screenname"        : screenname,
                                        "logged-in"         : true,
                                        "logged-in-user"    : loggedInUser.properties,
                                        "logged-in-sig"     : loggedInSig.properties,
                                        "s3accesskey"       : key["s3accesskey"],
                                        "s3secretkey"       : key["s3secretkey"],
                                        "add-to-my-web-archive" : self.btnCheck.isSelected
                                    ])
                                    
                                  if let tabbarVC = self.storyboard?.instantiateViewController(withIdentifier: "TabbarVC") as? UITabBarController {
                                    tabbarVC.modalPresentationStyle = .fullScreen
                                    self.present(tabbarVC, animated: true, completion: {
                                      self.navigationController?.popToRootViewController(animated: false)
                                    })
                                  }
                                }
                                MBProgressHUD.hide(for: self.view, animated: true)
                            })
                        })
                    })
                } else {
                    MBProgressHUD.hide(for: self.view, animated: true)
                    if let values = data1["values"] as? [String: Any],
                       let reason = values["reason"] as? String
                    {
                        if reason == WMConstants.errors[301] {
                            WMGlobal.showAlert(title: "", message: "Incorrect password!", target: self)
                        } else if reason == WMConstants.errors[302] {
                            WMGlobal.showAlert(title: "", message: "Account not found", target: self)
                        } else if reason == WMConstants.errors[303] {
                            WMGlobal.showAlert(title: "", message: "Account is not verified", target: self)
                        }
                    } else {
                        WMGlobal.showAlert(title: "", message: "Unknown error", target: self)
                    }
                }

        })
    }

    func login(email: String, password: String) {

        // just return if empty, since error alert already done elsewhere
        if email.isEmpty || password.isEmpty { return }

        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud.label.text = "Logging in..."

        //WMSAPIManager.shared.login(email: email, password: password) { (userData) in // this gets the cookies
        WMSAPIManager.shared.authLogin(email: email, password: password) { (userData) in // doesn't get cookies

            if (DEBUG_LOG) { NSLog("*** LoginVC login() userData: \(String(describing: userData))") } // TEST TO REMOVE

            if var userData = userData {
                // success
                userData["add-to-my-web-archive"] = self.btnCheck.isSelected

                WMSAPIManager.shared.getScreenName(email: email,
                    //loggedInUser: userData["logged-in-user"] as? String, // REMOVE
                    //loggedInSig: userData["logged-in-sig"] as? String, // REMOVE
                    accessKey: userData["s3accesskey"] as? String,
                    secretKey: userData["s3secretkey"] as? String)
                {
                    (screenname) in
                    MBProgressHUD.hide(for: self.view, animated: true)
                    if let screenname = screenname {
                        userData["screenname"] = screenname
                    }
                    WMGlobal.saveUserData(userData: userData)

                    // display tabbar VC
                    if let tabbarVC = self.storyboard?.instantiateViewController(withIdentifier: "TabbarVC") as? UITabBarController {
                      tabbarVC.modalPresentationStyle = .fullScreen
                      self.present(tabbarVC, animated: true, completion: {
                        self.navigationController?.popToRootViewController(animated: false)
                      })
                    }
                }
            } else {
                // failure
                MBProgressHUD.hide(for: self.view, animated: true)
                WMGlobal.showAlert(title: "Login Failed", message: "Try entering your email and password again, or create a new account.", target: self)

                // TODO: REDO?
                // from old iOS code, need values from json data,
                // which means I need better error response from WMSAPIManager.login()
                /*
                if let values = data1["values"] as? [String: Any],
                   let reason = values["reason"] as? String
                {
                    if reason == WMConstants.errors[301] {
                        WMGlobal.showAlert(title: "", message: "Incorrect password!", target: self)
                    } else if reason == WMConstants.errors[302] {
                        WMGlobal.showAlert(title: "", message: "Account not found", target: self)
                    } else if reason == WMConstants.errors[303] {
                        WMGlobal.showAlert(title: "", message: "Account is not verified", target: self)
                    }
                } else {
                    WMGlobal.showAlert(title: "", message: "Unknown error", target: self)
                }
                */
            }
        }
    }

    // MARK: - Delegates
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        if let txtField = textField as? SkyFloatingLabelTextField {
            txtField.errorMessage = nil
        }
        
        return true
    }
    
}
