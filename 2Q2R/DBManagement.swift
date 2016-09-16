//
//  DBManagement.swift
//  2Q2R
//
//  Created by Sam Claus on 8/24/16.
//  Copyright © 2016 Tera Insights, LLC. All rights reserved.
//  TODO: setCounter should also update the datetime on the key
//

import Foundation

let database = SQLiteDB.sharedInstance

func insertNewKey(keyID: String, appID: String, userID: String) {
    
    database.execute("INSERT INTO keys VALUES ('\(keyID)', '\(appID)', '0', '\(userID)', '\(getCurrentDateTime())');")
    
}

func insertNewServer(appID: String, appName: String, baseURL: String) {
    
    database.execute("INSERT INTO servers VALUES ('\(appID)', '\(appName)', '\(baseURL)');")
    
}

func userIsAlreadyRegistered(userID: String, forServer appID: String) -> Bool {
    
    let cursor = database.query("SELECT userID, appID FROM keys WHERE userID = '\(userID)' AND appID = '\(appID)';")
    return cursor.count > 0
    
}

func getUserID(forKey keyID: String) -> String? {
    
    let query = database.query("SELECT userID FROM keys WHERE keyID = '\(keyID)';")
    
    if query.count == 1 {
        
        return query[0]["userID"] as? String
        
    } else {
        
        return nil
        
    }
    
}

func getInfo(forServer appID: String) -> (appName: String, baseURL: String)? {
    
    let info = database.query("SELECT appName, baseURL FROM servers WHERE appID = '\(appID)';")
    
    if info.count == 1 {
        return (info[0]["appName"] as! String, info[0]["baseURL"] as! String)
    } else {
        return nil
    }
    
}

func getRecentKeys() -> [[String:AnyObject]] {
    
    return database.query("SELECT userID, appName, baseURL, used, counter FROM keys, servers WHERE keys.appID = servers.appID ORDER BY used DESC LIMIT 5;")
    
}

func getAllKeys() -> [[String:AnyObject]] {
    
    return database.query("SELECT userID, appName, baseURL, used, counter FROM keys, servers WHERE keys.appID = servers.appID ORDER BY appName, userID DESC;")
    
}

func getCounter(forKey keyID: String) -> Int? {
    
    let counter = database.query("SELECT counter FROM keys WHERE keyID = '\(keyID)';")
    
    if counter.count == 1 {
        return counter[0]["counter"] as? Int
    } else {
        return nil
    }
    
}

func setCounter(forKey keyID: String, to counter: Int) {
    
    database.execute("UPDATE keys SET counter = '\(counter)', used = '\(getCurrentDateTime())' WHERE keyID = '\(keyID)';")
    
}








































