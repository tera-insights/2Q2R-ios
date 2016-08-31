//
//  U2F.swift
//  2Q2R
//
//  Created by Sam Claus on 8/24/16.
//  Copyright © 2016 Tera Insights, LLC. All rights reserved.
//

import Foundation
import UIKit

var cache: [String:String] = [:]

private var keyParams: [String:AnyObject] = [
    kSecAttrKeyType as String: kSecAttrKeyTypeEC,
    kSecAttrKeySizeInBits as String: 256
]

func processU2F(message content: String) {
    
    switch checkValid(qr: content) {
    case .REG:
        
        let args = content.componentsSeparatedByString(" ")
        cache["challenge"] = args[1]
        cache["infoURL"] = args[2]
        cache["userID"] = args[3]
        
        let req = NSMutableURLRequest(URL: NSURL(string: cache["infoURL"]!)!)
        req.HTTPMethod = "GET"
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
            
            let infoTask = NSURLSession.sharedSession().dataTaskWithRequest(req, completionHandler: infoResponseHandler)
            infoTask.resume()
            
        }
        
    case .AUTH:
        
        let args = content.componentsSeparatedByString(" ")
        let serverInfo = getInfo(forServer: args[1])
        cache["serverCounter"] = args[4]
        cache["appName"] = serverInfo?.appName
        
        if let info = serverInfo {
            
            authenticate(appID: args[1], challenge: args[2], keyID: args[3], baseURL: info.baseURL)
            
        } else {
            
            UIAlertView(title: "Unknown Server", message: "Sorry, but you are not registered with this server.", delegate: nil, cancelButtonTitle: "Okay").show()
            
        }
        
        
    default:
        
        UIAlertView(title: "Invalid QR", message: "Sorry, but the QR you scanned does not entail a valid 2Q2R request.", delegate: nil, cancelButtonTitle: "Okay").show()
        
    }
    
}

private func checkValid(qr qr: String) -> Type {
    
    if qr.characters.count == 0 {
        return .INVALID
    }
    
    let qrArgs = qr.componentsSeparatedByString(" ")
    
    switch qrArgs[0] {
        case "R":
            if qrArgs.count != 4 {
                break
            } else if fromBase64(qrArgs[1]).length != 32 {
                break
            } else if qrArgs[2] =~ "[a-zA-Z0-9:/.]+" {
                return .REG
            }
        case "A":
            if qrArgs.count != 5 {
                break
            } else if fromBase64(qrArgs[1]).length != 32 {
                break
            } else if fromBase64(qrArgs[2]).length != 32 {
                break
            } else if Int(qrArgs[4]) != nil {
                return .AUTH
            }
        default: break
    }
    
    return .INVALID
    
}

func register(challenge challenge: String, serverInfo: [String:AnyObject], userID: String) {
    
    if let keyRefs = genKeyPair() {
        
        

        
        if userIsAlreadyRegistered(userID, forServer: serverInfo["appID"] as! String) {
            
            displayText(withTitle: serverInfo["appName"] as? String, withMessage: "This device is alrady registered to your account.")
            return
            
        }
        
    }
    
}

private func authenticate(appID appID: String, challenge: String, keyID: String, baseURL: String) {
    // TODO: FINISH AUTHENTICATION
}

private func genKeyPair() -> (privateAlias: String, cert: SecKey)? {
    
    // Generate a keyhandle, which will be returned as an alias for the private key
    let numBytes = 16
    var randomBytes = [UInt8](count: numBytes, repeatedValue: 0)
    SecRandomCopyBytes(kSecRandomDefault, numBytes, &randomBytes)
    let data = NSData(bytes: &randomBytes, length: numBytes)
    let alias = data.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
    
    // If running iOS 9 or newer, use the Secure Enclave
    if #available(iOS 9.0, *) {
        keyParams[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
    }
    
    var privateKeyAccessFlags: SecAccessControlCreateFlags
    
    if #available(iOS 9.0, *) {
        privateKeyAccessFlags = [.TouchIDAny, .PrivateKeyUsage]
    } else {
        privateKeyAccessFlags = .UserPresence
    }
    
    let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, privateKeyAccessFlags, nil)!
    
    // private key parameters
    keyParams[kSecPrivateKeyAttrs as String] = [
        kSecAttrLabel as String: alias,
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: "com.terainsights.a2Q2R",
        kSecAttrAccessControl as String: access
    ]
    
    // public key parameters
    keyParams[kSecPublicKeyAttrs as String] = [
        kSecAttrLabel as String: alias + "-pub",
        kSecAttrIsPermanent as String: false,
        kSecAttrApplicationTag as String: "com.terainsights.a2Q2R"
    ]
    
    var pubKey, privKey: SecKey?
    let err = SecKeyGeneratePair(keyParams, &pubKey, &privKey)
    
    if let cert = pubKey where err == errSecSuccess {
        
        return (alias, cert)
        
    } else {
        
        print("Failed to generate keys, error: \(err)")
        return nil
        
    }
    
}

private func sign(bytes data: NSData, usingKeyWithAlias alias: String) -> NSData? {
    
    let params = [
        kSecClass as String: kSecClassKey,
        kSecAttrKeyType as String: kSecAttrKeyTypeEC,
        kSecAttrApplicationTag as String: "com.terainsights.a2Q2R",
        kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
        kSecAttrLabel as String: alias,
        kSecReturnRef as String: kCFBooleanTrue
    ]
    
    var privateKey: AnyObject?
    let status = SecItemCopyMatching(params, &privateKey)
    
    if status != errSecSuccess {
        print(status)
        return nil
    }
    
    let hashedData = NSMutableData(length: Int(CC_SHA256_DIGEST_LENGTH))!
    CC_SHA256(data.bytes, CC_LONG(data.length), UnsafeMutablePointer(hashedData.mutableBytes))
    
    let signedHash = NSMutableData(length: SecKeyGetBlockSize(privateKey as! SecKey))!
    var signHashLength = signedHash.length
    
    let error = SecKeyRawSign(privateKey as! SecKey, .PKCS1SHA256, UnsafePointer<UInt8>(data.bytes), data.length, UnsafeMutablePointer<UInt8>(signedHash.mutableBytes), &signHashLength)
    
    if error == errSecSuccess {
        
        return signedHash
        
    } else {
        
        print(error.description)
        return nil
        
    }
    
}

// What to do after a server sends info about itself
private func infoResponseHandler(data: NSData?, response: NSURLResponse?, error: NSError?) {
    
    do {
        
        let json = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions()) as! [String:AnyObject]
        register(challenge: cache["challenge"]!, serverInfo: json, userID: cache["userID"]!)

    } catch {}
    
}

// What to do after a server responds to a registration attempt
private func registrationResponseHandler(data: NSData?, response: NSURLResponse?, error: NSError?) {
    
    let status = (response as! NSHTTPURLResponse).statusCode
    
    if status == 200 {
        
        if getInfo(forServer: cache["appID"]!) == nil {
            
            insertNewServer(cache["appID"]!, appName: cache["appName"]!, baseURL: cache["baseURL"]!)
            
        }
        
        insertNewKey(cache["keyID"]!, appID: cache["appID"]!, userID: cache["userID"]!)
        
        displayText(withTitle: cache["appName"], withMessage: "Registration approved!")
        
    } else {
    
        displayText(withTitle: cache["appName"], withMessage: "Registration declined.")
        
    }
    
}

// What to do after a server responds to an authentication attempt
private func authenticationResponseHandler(data: NSData?, response: NSURLResponse?, error: NSError?) {
    
    let status = (response as! NSHTTPURLResponse).statusCode
    
    if status == 200 {
        
        setCounter(forKey: cache["keyID"]!, to: Int(cache["serverCounter"]!)!)
        
        displayText(withTitle: cache["appName"], withMessage: "Authentication approved!")
        
    } else if status == 401 {
        
        displayText(withTitle: cache["appName"], withMessage: "Authentication failed.")
        
    } else if status == 408 {
        
        displayText(withTitle: cache["appName"], withMessage: "The authentication request timed out. Please re-login in your browser and try again.")
        
    }
    
}

private func displayText(withTitle title: String?, withMessage message: String?) {
    
    dispatch_async(dispatch_get_main_queue()) {
        
        UIAlertView(title: title, message: message, delegate: nil, cancelButtonTitle: "Okay").show()
        
    }
    
}



























