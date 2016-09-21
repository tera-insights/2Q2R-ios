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
    case register, authenticate
}

class U2FRequestDialog: UIViewController {
    
    var type: ReqType!
    var challenge: String!
    var appName: String!
    var userID: String!
    
    var resultHandler: ((_ approved: Bool) -> Void)!
    
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var challengeFirst8: UILabel!
    @IBOutlet weak var challengeNext20: UILabel!
    @IBOutlet weak var appNameLabel: UILabel!
    @IBOutlet weak var userIDLabel: UILabel!
    
    @IBAction func approveAction() {
        
        dismiss(animated: true) {
            
            self.resultHandler(true)
            
        }
        
    }
    
    @IBAction func declineAction() {
        
        dismiss(animated: true) {
            
            self.resultHandler(false)
            
        }
        
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        challengeFirst8.textColor = UIColor(red: 40/255, green: 100/255, blue: 1, alpha: 1)
        
        typeLabel.text = type == .register ? "Register?" : "Authenticate?"
        challengeFirst8.text = "\(challenge.substring(0, length: 4)) \(challenge.substring(4, length: 4))"
        challengeNext20.text = "\(challenge.substring(8, length: 4)) \(challenge.substring(12, length: 4)) \(challenge.substring(16, length: 4)) \(challenge.substring(20, length: 4)) \(challenge.substring(24, length: 4))"
        appNameLabel.text = appName
        userIDLabel.text = userID
        
    }
    
}
