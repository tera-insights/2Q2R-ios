//
//  U2F.swift
//  2Q2R
//
//  Created by Sam Claus on 8/24/16.
//  Copyright © 2016 Tera Insights, LLC. All rights reserved.
//  TODO: Finish registration and authentication methods
//

import UIKit
import Security
import Firebase

private var cache: [String:String] = [:]
private let keyHandleLength: UInt8 = 16

let applicationTag = "com.terainsights.2Q2R"

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
            
            displayText(withTitle: "Unknown Server", withMessage: "Sorry, but you are not registered with this server.")
            
        }
        
        
    default:
        
        displayText(withTitle: "Invalid QR", withMessage: "Sorry, but the QR you scanned does not entail a valid 2Q2R request.")
        
    }
    
}

private func checkValid(qr qr: String) -> Type {
    
    print(qr)
    
    if qr.characters.count == 0 {
        return .INVALID
    }
    
    let qrArgs = qr.componentsSeparatedByString(" ")
    
    switch qrArgs[0] {
        case "R":
            print("Registration QR...")
            if qrArgs.count != 4 {
                print("Incorrect number of arguments.")
                break
            } else if decodeFromWebsafeBase64(qrArgs[1]).length != 32 {
                print("Challenge of incorrect length: \(decodeFromWebsafeBase64(qrArgs[1]).length) bytes.")
                break
            } else if qrArgs[2] =~ "[a-zA-Z0-9:/.]+" {
                return .REG
            }
        case "A":
            if qrArgs.count != 5 {
                break
            } else if decodeFromWebsafeBase64(qrArgs[1]).length != 32 {
                break
            } else if decodeFromWebsafeBase64(qrArgs[2]).length != 32 {
                break
            } else if Int(qrArgs[4]) != nil {
                return .AUTH
            }
        default: break
    }
    
    return .INVALID
    
}

private func register(challenge challenge: String, serverInfo info: [String:AnyObject], userID: String) {
    
    if let keyRefs = genKeyPair() {
        
        if userIsAlreadyRegistered(userID, forServer: info["appID"] as! String) {
            
            displayText(withTitle: info["appName"] as? String, withMessage: "This device is alrady registered to your account.")
            return
            
        }
        
        print("\nPublic: \(keyRefs.publicKey)")
        print("Length: \(keyRefs.publicKey.length)")
        
        let registrationData = NSMutableData()
        let bytesToSign = NSMutableData()
        
        let p256Header: [UInt8] = [0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01, 0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00]
        let x509DER = NSMutableData(bytes: p256Header, length: p256Header.count)
        x509DER.appendData(keyRefs.publicKey)
        
        let clientData = "\"type\":\"navigator.id.finishEnrollment\",\"challenge\":\"\(challenge)\",\"origin\":\"\(info["baseURL"] as! String)\"".asBase64(websafe: false)
        
        var futureUse: UInt8 = 0x00
        var reserved: UInt8 = 0x05
        let keyHandle = decodeFromWebsafeBase64(keyRefs.privateAlias)
        var keyHandleLength: UInt8 = UInt8(keyHandle.length)
        
        bytesToSign.appendBytes(&futureUse, length: 1)
        bytesToSign.appendData((info["appID"] as! String).sha256())
        bytesToSign.appendData(clientData.sha256())
        bytesToSign.appendData(keyHandle)
        bytesToSign.appendData(keyRefs.publicKey)
        
        if let signature = sign(bytes: bytesToSign, usingKeyWithAlias: keyRefs.privateAlias) {
            
            registrationData.appendBytes(&reserved, length: sizeofValue(reserved))
            registrationData.appendData(keyRefs.publicKey)
            registrationData.appendBytes(&keyHandleLength, length: sizeofValue(keyHandleLength))
            registrationData.appendData(keyHandle)
            registrationData.appendData(x509DER)
            registrationData.appendData(signature)
            
            let registration: [String:String] = [
                "type": "2q2r",
                "deviceName": UIDevice.currentDevice().name,
                "fcmToken": FIRInstanceID.instanceID().token()!,
                "clientData": clientData,
                "registrationData": registrationData.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
            ]
            
            do {
                
                let json = try NSJSONSerialization.dataWithJSONObject(registration, options: .PrettyPrinted)
            
                if let url = NSURL(string: info["baseURL"] as! String) {
                    
                    let req = NSMutableURLRequest(URL: url)
                    req.HTTPMethod = "POST"
                    req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                    req.HTTPBody = json
                    
                    let registrationTask = NSURLSession.sharedSession().dataTaskWithRequest(req, completionHandler: registrationResponseHandler)
                    registrationTask.resume()
                    
                } else {
                    
                    print("Incorrectly formatted base URL from server.")
                    
                }
                
            } catch {
                
                print("Failed to produce registration response JSON!")
                
            }
            
        } else {
            
            print("Failed to sign the registration response!")
            
        }
        
    }
    
}

private func authenticate(appID appID: String, challenge: String, keyID: String, baseURL: String) {
    
    
    
}

private func genKeyPair() -> (privateAlias: String, publicKey: NSData)? {
    
    // Generate a keyhandle, which will be returned as an alias for the private key
    let numBytes = Int(keyHandleLength)
    var randomBytes = [UInt8](count: numBytes, repeatedValue: 0)
    SecRandomCopyBytes(kSecRandomDefault, numBytes, &randomBytes)
    let data = NSData(bytes: &randomBytes, length: numBytes)
    let alias = data.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
    
    let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .TouchIDCurrentSet, nil)!
    
    // Key pair parameters
    var keyParams: [String:AnyObject] = [
        kSecAttrKeyType as String: kSecAttrKeyTypeEC,
        kSecAttrKeySizeInBits as String: 256
    ]
    
    // Private key parameters
    keyParams[kSecPrivateKeyAttrs as String] = [
        kSecAttrIsPermanent as String: true,
        kSecAttrLabel as String: alias,
        kSecAttrApplicationTag as String: applicationTag,
        kSecAttrAccessControl as String: access
    ]
    
    // Public key parameters
    keyParams[kSecPublicKeyAttrs as String] = [
        kSecAttrIsPermanent as String: true,
        kSecAttrLabel as String: alias + "-pub",
        kSecAttrApplicationTag as String: applicationTag
    ]
    
    var pubKeyRef, privKeyRef: SecKey?
    var err = SecKeyGeneratePair(keyParams, &pubKeyRef, &privKeyRef)
    
    guard let _ = pubKeyRef where err == errSecSuccess else {
        
        print("Error while generating key pair: \(err).")
        return nil
        
    }
    
    // Export the public key for application use
    let query = [
        kSecClass as String: kSecClassKey,
        kSecAttrLabel as String: alias + "-pub",
        kSecAttrKeyType as String: kSecAttrKeyTypeEC,
        kSecReturnData as String: true
    ]
    var pubKeyOpt: AnyObject?
    err = SecItemCopyMatching(query, &pubKeyOpt)
    
    if let pubKey = pubKeyOpt as? NSData where err == errSecSuccess {
        
        print("Successfully retrieved public key!")
        return (alias, pubKey)
        
    } else {
        
        print("Error retrieving public key: \(err).")
        return nil
        
    }
    
}

private func sign(bytes data: NSData, usingKeyWithAlias alias: String) -> NSData? {
    
    let query = [
        kSecClass as String: kSecClassKey,
        kSecAttrLabel as String: alias,
        kSecAttrApplicationTag as String: applicationTag,
        kSecAttrKeyType as String: kSecAttrKeyTypeEC,
        kSecReturnRef as String: true
    ]
    
    var privateKey: AnyObject?
    var error = SecItemCopyMatching(query, &privateKey)
    
    guard error == errSecSuccess else {
        
        print("Could not obtain reference to private key with alias \"\(alias)\", error: \(error).")
        return nil
        
    }
    
    print("\nData: \(data)")
    print("Length: \(data.length)")
    
    let hashedData = NSMutableData(length: Int(CC_SHA256_DIGEST_LENGTH))!
    CC_SHA256(data.bytes, CC_LONG(data.length), UnsafeMutablePointer(hashedData.mutableBytes))
    
    print("\nHashed data: \(hashedData)")
    print("Length: \(hashedData.length)")
    
    var signedHashLength = SecKeyGetBlockSize(privateKey as! SecKeyRef)
    let signedHash = NSMutableData(length: signedHashLength)!
    
    error = SecKeyRawSign(privateKey as! SecKeyRef, .PKCS1SHA256, UnsafePointer<UInt8>(hashedData.mutableBytes), hashedData.length, UnsafeMutablePointer<UInt8>(signedHash.mutableBytes), &signedHashLength)
    
    print("\nSigned hash: \(signedHash)")
    print("Length: \(signedHashLength)\n")
    
    guard error == errSecSuccess else {
        
        print("Failed to sign data, error: \(error).")
        return nil
        
    }
    
    return signedHash
    
}

private func infoResponseHandler(data: NSData?, response: NSURLResponse?, error: NSError?) {
    
    do {
        
        if let res = data {
            
            let json = try NSJSONSerialization.JSONObjectWithData(res, options: NSJSONReadingOptions()) as! [String:AnyObject]
            register(challenge: cache["challenge"]!, serverInfo: json, userID: cache["userID"]!)
            
        } else {
            
            displayText(withTitle: "Could not retrieve server information.", withMessage: "Please check your internet connection and try again.")
            
        }

    } catch {}
    
}

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
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        
        let okayAction = UIAlertAction(title: "Okay", style: .Cancel, handler: nil)
        alert.addAction(okayAction)
        
        applicationWindow!.rootViewController?.presentViewController(alert, animated: true, completion: nil)
        
    }
    
}



























