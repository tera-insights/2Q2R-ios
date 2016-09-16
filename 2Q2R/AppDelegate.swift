//
//  AppDelegate.swift
//  2Q2R
//
//  Created by Sam Claus on 8/23/16.
//  Copyright © 2016 Tera Insights, LLC. All rights reserved.
//

import UIKit
import Firebase
import FirebaseMessaging

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        // Configure firebase
        if #available(iOS 10.0, *) {
            
            
            
        } else {
            
            let settings: UIUserNotificationSettings = UIUserNotificationSettings(forTypes: [.Alert, .Badge, .Sound], categories: nil)
            application.registerUserNotificationSettings(settings)
            application.registerForRemoteNotifications()
            
        }
        
        FIRApp.configure()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.tokenRefreshHandler(_:)), name: kFIRInstanceIDTokenRefreshNotification, object: nil)
        
        // Prep the U2F database
        database.execute("CREATE TABLE IF NOT EXISTS keys(keyID TEXT PRIMARY KEY NOT NULL, appID TEXT NOT NULL, counter TEXT NOT NULL, userID TEXT NOT NULL, used DATETIME NOT NULL);")
        database.execute("CREATE TABLE IF NOT EXISTS servers(appID TEXT PRIMARY KEY NOT NULL, appName TEXT NOT NULL, baseURL TEXT NOT NULL);")
        
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        
        FIRMessaging.messaging().disconnect()
        print("Disconnected from FCM.")
        
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        
        connectToFCM()
        
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func connectToFCM() {
        
        FIRMessaging.messaging().connectWithCompletion() { (error) in
            
            print(error == nil ? "Connected to FCM." : "Unable to connect to FCM, error: \(error)")
            
        }
        
    }
    
    func tokenRefreshHandler(notification: NSNotification) {
        
        //if let token = FIRInstanceID.instanceID().token() {
            
            // Send new token to all registered servers.
            
        //}
        
        connectToFCM()
        
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
    
        print(userInfo)
        process2Q2RRequest(userInfo	["authData"] as! String)?.execute()
        
    }

}

extension AppDelegate: FIRMessagingDelegate {
    
    func applicationReceivedRemoteMessage(message: FIRMessagingRemoteMessage) {
        
        print(message.appData)
        process2Q2RRequest(message.appData["authData"] as! String)?.execute()
        
    }
    
}


