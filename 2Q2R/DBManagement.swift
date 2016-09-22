//
//  DBManagement.swift
//  2Q2R
//
//  Created by Sam Claus on 8/24/16.
//  Copyright © 2016 Tera Insights, LLC. All rights reserved.
//  TODO: setCounter should also update the datetime on the key
//

import Foundation

var database: FMDatabase! = nil

func initializeDatabase() {
    
    let dbFileURL = try! FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("keys.sqlite")
    
    guard let db = FMDatabase(path: dbFileURL.path) else {
        
        print("Failed to access database file!")
        return
        
    }
    
    guard db.open() else {
        
        print("Failed to open database!")
        return
        
    }
    
    do {
        
        try db.executeUpdate("CREATE TABLE IF NOT EXISTS keys(keyID TEXT PRIMARY KEY NOT NULL, appID TEXT NOT NULL, counter TEXT NOT NULL, userID TEXT NOT NULL, used DATETIME NOT NULL)", values: nil)
        try db.executeUpdate("CREATE TABLE IF NOT EXISTS servers(appID TEXT PRIMARY KEY NOT NULL, appName TEXT NOT NULL, appURL TEXT NOT NULL)", values: nil)
        
        database = db
        
    } catch let error {
        
        print("Could not create tables in database, error: \(error)")
        
    }
    
}

func insertNewKey(_ keyID: String, appID: String, userID: String) {
    
    do {
        
        try database.executeUpdate("INSERT INTO keys VALUES ('\(keyID)', '\(appID)', '0', '\(userID)', '\(Date())');", values: nil)
        
    } catch let error {
        
        print(error)
        
    }
    
}

func insertNewServer(_ appID: String, appName: String, appURL: String) {
    
    do {
        
        try database.executeUpdate("INSERT INTO servers VALUES ('\(appID)', '\(appName)', '\(appURL)')", values: nil)
        
    } catch let error {
        
        print(error)
        
    }
    
}

func userIsAlreadyRegistered(_ userID: String, forServer appID: String) -> Bool {
    
    do {
        
        let query = try database.executeQuery("SELECT userID, appID FROM keys WHERE userID = '\(userID)' AND appID = '\(appID)'", values: nil)
        return query.next()
        
    } catch let error {
        
        print(error)
        return false
        
    }
    
}

func getUserID(forKey keyID: String) -> String? {
    
    do {
        
        let query = try database.executeQuery("SELECT userID FROM keys WHERE keyID = '\(keyID)'", values: nil)
        
        guard query.next() else { return nil }
        
        return query.string(forColumn: "userID")
        
    } catch let error {
        
        print(error)
        return nil
        
    }
    
}

func getInfo(forServer appID: String) -> (appName: String, appURL: String)? {
    
    do {
        
        let query = try database.executeQuery("SELECT appName, appURL FROM servers WHERE appID = '\(appID)'", values: nil)
        
        if query.next() {
        
            return (query.string(forColumn: "appName"), query.string(forColumn: "appURL"))
            
        }
        
    } catch let error {
        
        print(error)
        
    }
    
    return nil
    
}

func getRecentKeys() -> [[String:AnyObject]] {
    
    var result: [[String:AnyObject]] = []
    
    do {
        
        let query = try database.executeQuery("SELECT userID, appName, appURL, used, counter FROM keys, servers WHERE keys.appID = servers.appID ORDER BY used DESC LIMIT 5", values: nil)
        
        while query.next() {
            
            result.append([
                "userID": query.string(forColumn: "userID") as AnyObject,
                "appName": query.string(forColumn: "appName") as AnyObject,
                "appURL": query.string(forColumn: "appURL") as AnyObject,
                "used": query.date(forColumn: "used") as AnyObject,
                "counter": Int(query.int(forColumn: "counter")) as AnyObject
            ])
            
        }
        
    } catch let error {
        
        print(error)
        
    }
    
    return result
    
}

func getAllKeys() -> [[String:AnyObject]] {
    
    var result: [[String:AnyObject]] = []
    
    do {
        
        let query = try database.executeQuery("SELECT userID, appName, appURL, used, counter FROM keys, servers WHERE keys.appID = servers.appID ORDER BY appName, userID DESC", values: nil)
        
        while query.next() {
            
            result.append([
                "userID": query.string(forColumn: "userID") as AnyObject,
                "appName": query.string(forColumn: "appName") as AnyObject,
                "appURL": query.string(forColumn: "appURL") as AnyObject,
                "used": query.date(forColumn: "used") as AnyObject,
                "counter": Int(query.int(forColumn: "counter")) as AnyObject
                ])
            
        }
        
    } catch let error {
        
        print(error)
        
    }
    
    return result
    
}

func getCounter(forKey keyID: String) -> Int? {
    
    do {
        
        let query = try database.executeQuery("SELECT counter FROM keys WHERE keyID = '\(keyID)'", values: nil)
        
        if query.next() {
            
            return Int(query.int(forColumn: "counter"))
            
        }
        
    } catch let error {
        
        print(error)
        
    }
    
    return nil
    
}

func setCounter(forKey keyID: String, to counter: Int) {
    
    do {
        
        try database.executeUpdate("UPDATE keys SET counter = '\(counter)', used = '\(Date())' WHERE keyID = '\(keyID)'", values: nil)
        
    } catch let error {
        
        print(error)
        
    }
    
}








































