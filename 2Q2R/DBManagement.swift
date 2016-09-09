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
    
    let formatter = NSDateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    
    let dt = formatter.stringFromDate(NSDate())
    
    database.execute("INSERT INTO keys VALUES ('\(keyID)', '\(appID)', '0', '\(userID)', '\(dt)');")
    
}

func insertNewServer(appID: String, appName: String, baseURL: String) {
    
    database.execute("INSERT INTO servers VALUES ('\(appID)', '\(appName)', '\(baseURL)');")
    
}

func userIsAlreadyRegistered(userID: String, forServer appID: String) -> Bool {
    
    let cursor = database.query("SELECT userID, appID FROM keys WHERE userID = '\(userID)' AND appID = '\(appID)';")
    return cursor.count > 0
    
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
    
    // Prep the U2F database
    database.execute("CREATE TABLE IF NOT EXISTS keys(keyID TEXT PRIMARY KEY NOT NULL, appID TEXT NOT NULL, counter TEXT NOT NULL, userID TEXT NOT NULL, used TEXT NOT NULL);")
    database.execute("CREATE TABLE IF NOT EXISTS servers(appID TEXT PRIMARY KEY NOT NULL, appName TEXT NOT NULL, baseURL TEXT NOT NULL);")
    database.execute("DELETE FROM keys;")
    database.execute("DELETE FROM servers;")
    database.execute("INSERT INTO servers VALUES ('-T_wxhSkkkJDJJlnyeo', '2Q2R Server Demo', 'https://fake.domain.com/');")
    let dateTime = NSDate()
    
    database.execute("INSERT INTO keys VALUES ('awonfawofoa-_2233nj-', '-T_wxhSkkkJDJJlnyeo', '0', 'alin@tera.com', '\(dateTime)');")
    database.execute("INSERT INTO keys VALUES ('afniaifninia', '-T_wxhSkkkJDJJlnyeo', '4', 'sam@terainsights.com', '\(dateTime)');")
    database.execute("INSERT INTO keys VALUES ('eawf982fm2msk', '-T_wxhSkkkJDJJlnyeo', '1', 'jess@terainsights.com', '\(dateTime)');")
    database.execute("INSERT INTO keys VALUES ('wd89fj289fiss', '-T_wxhSkkkJDJJlnyeo', '37', 'tiffany@terainsights.com', '\(dateTime)');")
    database.execute("INSERT INTO keys VALUES ('e1udniun_1jnn', '-T_wxhSkkkJDJJlnyeo', '15', 'jon@terainsights.com', '\(dateTime)');")
    database.execute("INSERT INTO keys VALUES ('wf8w2f--wufnwfeun_', '-T_wxhSkkkJDJJlnyeo', '22', 'chris@terainsights.com', '\(dateTime)');")
    
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
    
    database.execute("UPDATE keys SET counter = '\(counter)', used = '\(NSDate())' WHERE keyID = '\(keyID)';")
    
}








































