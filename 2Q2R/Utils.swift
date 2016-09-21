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
    case auth, reg, invalid
}

extension String {
    
    func asBase64(websafe: Bool) -> String {
        
        let data = self.data(using: String.Encoding.utf8)
        let encodedString = data!.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        
        if websafe {
            
            return encodedString.replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
            
        } else {
            
            return encodedString
            
        }
        
    }
    
    mutating func makeWebsafe() {
        
        self = self.replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        
    }
    
    func sha256() -> Data {
        
        let data = self.data(using: String.Encoding.utf8)!
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        CC_SHA256((data as NSData).bytes, CC_LONG(data.count), &hash)
        
        return Data(bytes: UnsafePointer<UInt8>(hash), count: Int(CC_SHA256_DIGEST_LENGTH))
        
    }
    
    func substring(_ from: Int, length: Int) -> String {
        
        var startIndex = self.startIndex
        var finalIndex: String.Index
        
        for _ in 0..<from { startIndex = self.index(after: startIndex) }
        finalIndex = startIndex
        for _ in 0..<length { finalIndex = self.index(after: finalIndex) }
        
        return self.substring(with: startIndex..<finalIndex)
        
    }
    
}

func decodeFromWebsafeBase64ToBase64Data(_ websafeString: String) -> Data {
    
    var base64String = websafeString.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    
    switch base64String.characters.count % 3 {
        case 1:
            base64String.append("==")
        case 2:
            base64String.append("=")
        default:
            break
    }
    
    return Data(base64Encoded: base64String, options: NSData.Base64DecodingOptions(rawValue: 0))!
    
}

func decodeFromWebsafeBase64ToBase64String(_ websafeString: String) -> String {
    
    var base64String = websafeString.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    
    switch base64String.characters.count % 3 {
    case 1:
        base64String.append("==")
    case 2:
        base64String.append("=")
    default:
        break
    }
    
    return base64String
    
}

infix operator =~
func =~ (input: String, pattern: String) -> Bool {
    return input.range(of: pattern, options: .regularExpression) != nil
}

func sendJSONToURL(_ urlString: String, json: [String:AnyObject]?, method: String, responseHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
    
    do {
        
        if let url = URL(string: urlString) {
            
            var req = URLRequest(url: url)
            req.httpMethod = method
            
            if method == "POST" && json != nil {
                
                req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: json!, options: JSONSerialization.WritingOptions(rawValue: 0))
                
            }
            
            let registrationTask = URLSession.shared.dataTask(with: req, completionHandler: responseHandler)
            registrationTask.resume()
            
        } else {
            
            print("Incorrectly formatted URL.")
            
        }
        
    } catch {
        
        print("Incorrectly formatted JSON.")
        
    }
    
}

func getCurrentDateTime() -> Date {
    
    let now = Date()
    var components = DateComponents()
    let calendar = Calendar.current
    
    components.day = (calendar as NSCalendar).component(.day, from: now)
    components.month = (calendar as NSCalendar).component(.month, from: now)
    components.year = (calendar as NSCalendar).component(.year, from: now)
    components.hour = (calendar as NSCalendar).component(.hour, from: now)
    components.minute = (calendar as NSCalendar).component(.minute, from: now)
    
    return calendar.date(from: components)!
    
}

func displayError(_ error: SecError, withTitle title: String) {
    
    DispatchQueue.main.async {
        
        let alert = UIAlertController(title: title, message: error.description(), preferredStyle: .alert)
        
        let okayAction = UIAlertAction(title: "Okay", style: .cancel, handler: nil)
        alert.addAction(okayAction)
        
        UIApplication.shared.windows[0].rootViewController?.present(alert, animated: true, completion: nil)
        
        
    }
    
}

func confirmResponseFromBackgroundThread(_ type: ReqType, challenge: String, appName: String, userID: String, onResult: @escaping (_ approved: Bool) -> Void) {
    
    DispatchQueue.main.async {
    
        let custom = UIApplication.shared.windows[0].rootViewController?.storyboard?.instantiateViewController(withIdentifier: "reqDialog") as! U2FRequestDialog
        
        custom.type = type
        custom.challenge = challenge
        custom.appName = appName
        custom.userID = userID
        custom.resultHandler = { (approved: Bool) in DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.high).async { onResult(approved) } }
        
        custom.modalPresentationStyle = .popover
        custom.modalTransitionStyle = .coverVertical
        
        UIApplication.shared.windows[0].rootViewController?.present(custom, animated: true, completion: nil)
        
    }
    
}

func genEmptyBuffer(withLength length: Int) -> Data {
    
    let bytes: [UInt8] = [UInt8](repeating: 0, count: length)
    
    return Data(bytes: bytes)
    
}














