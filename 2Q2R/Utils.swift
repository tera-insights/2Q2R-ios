//
//  Utils.swift
//  2Q2R
//
//  Created by Sam Claus on 8/24/16.
//  Copyright © 2016 Tera Insights, LLC. All rights reserved.
//

import Foundation
import UIKit

enum Type {
    case AUTH, REG, INVALID
}

extension String {
    
    func asBase64(websafe websafe: Bool) -> String {
        
        let data = self.dataUsingEncoding(NSUTF8StringEncoding)
        let encodedString = data!.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
        
        if websafe {
            
            return encodedString.stringByReplacingOccurrencesOfString("+", withString: "-").stringByReplacingOccurrencesOfString("/", withString: "_").stringByReplacingOccurrencesOfString("=", withString: "")
            
        } else {
            
            return encodedString
            
        }
        
    }
    
    mutating func makeWebsafe() {
        
        self = self.stringByReplacingOccurrencesOfString("+", withString: "-").stringByReplacingOccurrencesOfString("/", withString: "_").stringByReplacingOccurrencesOfString("=", withString: "")
        
    }
    
    func sha256() -> NSData {
        
        let data = self.dataUsingEncoding(NSUTF8StringEncoding)!
        var hash = [UInt8](count: Int(CC_SHA256_DIGEST_LENGTH), repeatedValue: 0)
        
        CC_SHA256(data.bytes, CC_LONG(data.length), &hash)
        
        return NSData(bytes: hash, length: Int(CC_SHA256_DIGEST_LENGTH))
        
    }
    
}

func decodeFromWebsafeBase64ToBase64Data(websafeString: String) -> NSData {
    
    var base64String = websafeString.stringByReplacingOccurrencesOfString("-", withString: "+").stringByReplacingOccurrencesOfString("_", withString: "/")
    
    switch base64String.characters.count % 3 {
        case 1:
            base64String.appendContentsOf("==")
        case 2:
            base64String.appendContentsOf("=")
        default:
            break
    }
    
    return NSData(base64EncodedString: base64String, options: NSDataBase64DecodingOptions(rawValue: 0))!
    
}

func decodeFromWebsafeBase64ToBase64String(websafeString: String) -> String {
    
    var base64String = websafeString.stringByReplacingOccurrencesOfString("-", withString: "+").stringByReplacingOccurrencesOfString("_", withString: "/")
    
    switch base64String.characters.count % 3 {
    case 1:
        base64String.appendContentsOf("==")
    case 2:
        base64String.appendContentsOf("=")
    default:
        break
    }
    
    return base64String
    
}

infix operator =~ {}
func =~ (input: String, pattern: String) -> Bool {
    return input.rangeOfString(pattern, options: .RegularExpressionSearch) != nil
}

func sendJSONToURL(urlString: String, json: [String:AnyObject]?, method: String, responseHandler: (NSData?, NSURLResponse?, NSError?) -> Void) {
    
    do {
        
        if let url = NSURL(string: urlString) {
            
            let req = NSMutableURLRequest(URL: url)
            req.HTTPMethod = method
            
            if method == "POST" && json != nil {
                
                req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                req.HTTPBody = try NSJSONSerialization.dataWithJSONObject(json!, options: NSJSONWritingOptions(rawValue: 0))
                
            }
            
            let registrationTask = NSURLSession.sharedSession().dataTaskWithRequest(req, completionHandler: responseHandler)
            registrationTask.resume()
            
        } else {
            
            print("Incorrectly formatted URL.")
            
        }
        
    } catch {
        
        print("Incorrectly formatted JSON.")
        
    }
    
}

func getCurrentDateTime() -> NSDate {
    
    let now = NSDate()
    let components = NSDateComponents()
    let calendar = NSCalendar.currentCalendar()
    
    components.day = calendar.component(.Day, fromDate: now)
    components.month = calendar.component(.Month, fromDate: now)
    components.year = calendar.component(.Year, fromDate: now)
    components.hour = calendar.component(.Hour, fromDate: now)
    components.minute = calendar.component(.Minute, fromDate: now)
    
    return calendar.dateFromComponents(components)!
    
}

func displayError(error: SecError, withTitle title: String) {
    
    dispatch_async(dispatch_get_main_queue()) {
        
        let alert = UIAlertController(title: title, message: error.description(), preferredStyle: .Alert)
        
        let okayAction = UIAlertAction(title: "Okay", style: .Cancel, handler: nil)
        alert.addAction(okayAction)
        
        UIApplication.sharedApplication().windows[0].rootViewController?.presentViewController(alert, animated: true, completion: nil)
        
        
    }
    
}














