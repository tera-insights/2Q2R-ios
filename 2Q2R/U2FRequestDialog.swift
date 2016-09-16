//
//  U2FRequestDialog.swift
//  2Q2R
//
//  Created by Alin on 9/16/16.
//  Copyright © 2016 Tera Insights, LLC. All rights reserved.
//

import Foundation
import UIKit

enum ReqType {
    case Register, Authenticate
}

class U2FRequestDialog: UIViewController {
    
    var type: ReqType!
    var challenge: String!
    var appName: String!
    var userID: String!
    
    var resultHandler: ((approved: Bool) -> Void)!
    
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var challengeFirst8: UILabel!
    @IBOutlet weak var challengeNext20: UILabel!
    @IBOutlet weak var appNameLabel: UILabel!
    @IBOutlet weak var userIDLabel: UILabel!
    
    @IBAction func approveAction() {
        
        dismissViewControllerAnimated(true) {
            
            self.resultHandler(approved: true)
            
        }
        
    }
    
    @IBAction func declineAction() {
        
        dismissViewControllerAnimated(true) {
            
            self.resultHandler(approved: false)
            
        }
        
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        typeLabel.text = type == .Register ? "Register?" : "Authenticate?"
        challengeFirst8.text = "\(challenge.subString(0, length: 4)) \(challenge.subString(4, length: 4))"
        challengeNext20.text = "\(challenge.subString(8, length: 4)) \(challenge.subString(12, length: 4)) \(challenge.subString(16, length: 4)) \(challenge.subString(20, length: 4)) \(challenge.subString(24, length: 4))"
        appNameLabel.text = appName
        userIDLabel.text = userID
        
    }
    
}