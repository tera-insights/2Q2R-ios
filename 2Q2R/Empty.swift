//
//  Empty.swift
//  2Q2R
//
//  Created by Sam Claus on 8/31/16.
//  Copyright © 2016 Tera Insights, LLC. All rights reserved.
//

import Foundation
import UIKit

class EmptyViewController: UIViewController {
    
    @IBAction func onRegisterAction(sender: AnyObject) {
        
        let view = self.storyboard?.instantiateViewControllerWithIdentifier("scan")
        navigationController?.pushViewController(view!, animated: true)
        
    }
    
}