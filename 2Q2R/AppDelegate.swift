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
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        // Configure firebase
        if #available(iOS 10.0, *) {
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            let unCenter: UNUserNotificationCenter = UNUserNotificationCenter.current()
            
            unCenter.requestAuthorization(options: authOptions, completionHandler: { _,_ in })
            unCenter.delegate = self
            FIRMessaging.messaging().remoteMessageDelegate = self
            
        } else {
            
            let settings: UIUserNotificationSettings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
            application.registerForRemoteNotifications()
            
        }
        
        FIRApp.configure()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.tokenRefreshHandler(_:)), name: NSNotification.Name.firInstanceIDTokenRefresh, object: nil)
        
        // Prep the U2F database
        initializeDatabase()
        
        return true
        
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        
        FIRMessaging.messaging().disconnect()
        print("Disconnected from FCM.")
        
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        
        connectToFCM()
        
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func connectToFCM() {
        
        FIRMessaging.messaging().connect() { (error) in
            
            print(error == nil ? "Connected to FCM." : "Unable to connect to FCM, error: \(error)")
            
        }
        
    }
    
    func tokenRefreshHandler(_ notification: Notification) {
        
        //if let token = FIRInstanceID.instanceID().token() {
            
            // Send new token to all registered servers.
            
        //}
        
        connectToFCM()
        
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        print("Received iOS notification.")
    
        guard let _ = userInfo["authData"] else {
            
            print("Just received a non-2Q2R notification!")
            return
            
        }
        
        if let u2fAction = process2Q2RRequest(userInfo["authData"] as! String) {
            
            u2fAction.execute()
            
        } else {
            
            print("Incorrectly formatted 2Q2R request.")
            
        }
        
    }

}

@available(iOS 10, *)
extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // Not sure what this method does.
        
    }
    
}

extension AppDelegate: FIRMessagingDelegate {
    
    func applicationReceivedRemoteMessage(_ message: FIRMessagingRemoteMessage) {
        
        print("Received Firebase notification.")
        
        guard let _ = message.appData["authData"] else {
            
            print("Just received a non-2Q2R notification!")
            return
            
        }
        
        if let u2fAction = process2Q2RRequest(message.appData["authData"] as! String) {
            
            u2fAction.execute()
            
        } else {
            
            print("Incorrectly formatted 2Q2R request.")
            
        }

        process2Q2RRequest(message.appData["authData"] as! String)?.execute()
        
    }
    
}


