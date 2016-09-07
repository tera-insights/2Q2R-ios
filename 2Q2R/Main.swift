//
//  ViewController.swift
//  2Q2R
//
//  Created by Sam Claus on 8/23/16.
//  Copyright © 2016 Tera Insights, LLC. All rights reserved.
//

import UIKit

class Main: UITableViewController {
    
    var recentKeys: [[String:AnyObject]] = getRecentKeys()
    var allKeys: [[String:AnyObject]] = getAllKeys()
    
    @IBAction func onAboutAction(sender: AnyObject) {
        
        let alert = UIAlertController(title: "2Q2R Version 1.0", message: "©2016 Tera Insights, LLC.\nLicensed under Apache 2.0.", preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Okay", style: .Cancel, handler: nil))
        presentViewController(alert, animated: true, completion: nil)
        
    }
    
    @IBAction func onScanAction(sender: AnyObject) {
        
        let view = self.storyboard?.instantiateViewControllerWithIdentifier("scan")
        navigationController?.pushViewController(view!, animated: true)
        
    }

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        
        if allKeys.count == 0 {
            tableView.backgroundView = self.storyboard?.instantiateViewControllerWithIdentifier("emptyKeyView").view
            return 0
        }
        
        return allKeys.count > 5 ? 2 : 1
        
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return section == 0 ? min(5, recentKeys.count) : allKeys.count
        
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        return section == 0 ? (allKeys.count > 5 ? "Recent" : "Keys") : "All"
        
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCellWithIdentifier("KeyCell") as! KeyCell
        
        let userID = indexPath.section == 0 ? recentKeys[indexPath.row]["userID"] : allKeys[indexPath.row]["userID"]
        let appName = indexPath.section == 0 ? recentKeys[indexPath.row]["appName"] : allKeys[indexPath.row]["appName"]
        
        cell.userID.text = userID as? String
        cell.appName.text = appName as? String
        
        return cell;
        
    }


}

