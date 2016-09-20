//
//  ViewController.swift
//  2Q2R
//
//  Created by Sam Claus on 8/23/16.
//  Copyright © 2016 Tera Insights, LLC. All rights reserved.
//

import UIKit

var keyTable: UITableView?
var recentKeys: [[String:AnyObject]] = getRecentKeys()
var allKeys: [[String:AnyObject]] = getAllKeys() {
    
    didSet {
        
        DispatchQueue.main.async {
        
            keyTable?.reloadData()
            keyTable?.setNeedsDisplay()
        
        }

        print("Keys updated!")
        
    }
    
}

class Main: UITableViewController {
    
    @IBAction func onAboutAction(_ sender: AnyObject) {
        
        let infoDialog = storyboard?.instantiateViewController(withIdentifier: "about")
        
        infoDialog?.modalPresentationStyle = .formSheet
        infoDialog?.modalTransitionStyle = .crossDissolve
        
        present(infoDialog!, animated: true, completion: nil)
        
    }
    
    @IBAction func onScanAction(_ sender: AnyObject) {
        
        let view = self.storyboard?.instantiateViewController(withIdentifier: "scan")
        navigationController?.pushViewController(view!, animated: true)
        
    }

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        keyTable = self.tableView
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        if allKeys.count == 0 {
            tableView.backgroundView = self.storyboard?.instantiateViewController(withIdentifier: "emptyKeyView").view
            return 0
        } else {
            tableView.backgroundView = nil
        }
        
        return allKeys.count > 5 ? 2 : 1
        
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return section == 0 ? min(5, recentKeys.count) : allKeys.count
        
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        return section == 0 ? (allKeys.count > 5 ? "Recent" : "Keys") : "All"
        
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "KeyCell") as! KeyCell
        
        let userID = (indexPath as NSIndexPath).section == 0 ? recentKeys[(indexPath as NSIndexPath).row]["userID"] : allKeys[(indexPath as NSIndexPath).row]["userID"]
        let appName = (indexPath as NSIndexPath).section == 0 ? recentKeys[(indexPath as NSIndexPath).row]["appName"] : allKeys[(indexPath as NSIndexPath).row]["appName"]
        
        cell.userID.text = userID as? String
        cell.appName.text = appName as? String
        
        return cell;
        
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let keyDesc = ((indexPath as NSIndexPath).section == 0 ? recentKeys[(indexPath as NSIndexPath).row] : allKeys[(indexPath as NSIndexPath).row])
        let keyDetailsView = storyboard?.instantiateViewController(withIdentifier: "keyDetails") as! KeyDetails
        
        let dateTimeUsed = keyDesc["used"] as! Date
        
        let formatter = DateFormatter()
        
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        let dateUsed = formatter.string(from: dateTimeUsed)
        
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let timeUsed = formatter.string(from: dateTimeUsed)
        
        keyDetailsView.appName = keyDesc["appName"] as! String
        keyDetailsView.baseURL = keyDesc["baseURL"] as! String
        keyDetailsView.userID = keyDesc["userID"] as! String
        keyDetailsView.counter = "\(keyDesc["counter"]!)"
        keyDetailsView.dateUsed = dateUsed
        keyDetailsView.timeUsed = timeUsed
        
        navigationController?.pushViewController(keyDetailsView, animated: true)
        
        tableView.deselectRow(at: indexPath, animated: true)
        
    }

}

