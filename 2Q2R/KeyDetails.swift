//
//  KeyDetails.swift
//  2Q2R
//
//  Created by Sam Claus on 9/9/16.
//  Copyright © 2016 Tera Insights, LLC. All rights reserved.
//

import Foundation
import UIKit

class KeyDetails: UITableViewController {
    
    var appName: String = "?"
    var baseURL: String = "?"
    var userID: String = "?"
    var counter: String = "?"
    var dateUsed: String = "?"
    var timeUsed: String = "?"
    
    @IBOutlet weak var appNameOutlet: UILabel!
    @IBOutlet weak var baseURLOutlet: UILabel!
    @IBOutlet weak var userIDOutlet: UILabel!
    @IBOutlet weak var counterOutlet: UILabel!
    @IBOutlet weak var dateOutlet: UILabel!
    @IBOutlet weak var timeOutlet: UILabel!
    
    override func viewDidLoad() {
        
        appNameOutlet.text = appName
        baseURLOutlet.text = baseURL
        userIDOutlet.text = userID
        counterOutlet.text = counter
        dateOutlet.text = dateUsed
        timeOutlet.text = timeUsed
        
    }
    
}