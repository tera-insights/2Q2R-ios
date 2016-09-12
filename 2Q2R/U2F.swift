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
import LocalAuthentication

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
            
            displayText(withTitle: info["appName"] as? String, withMessage: "This device is already registered to your account.")
            return
            
        }
        
        print("\nPublic: \(keyRefs.publicKey)")
        print("Length: \(keyRefs.publicKey.length)")
        
        let registrationData = NSMutableData()
        let bytesToSign = NSMutableData()
        
        let clientData = "{\"type\":\"navigator.id.finishEnrollment\",\"challenge\":\"\(challenge)\",\"origin\":\"\(info["baseURL"] as! String)\"}".asBase64(websafe: false)
        
        var futureUse: UInt8 = 0x00
        var reserved: UInt8 = 0x05
        let keyHandle = decodeFromWebsafeBase64(keyRefs.privateAlias)
        var keyHandleLength = UInt8(keyHandle.length)
        let x509Certificate = generateX509(forKey: keyRefs.publicKey)
        
        bytesToSign.appendBytes(&futureUse, length: 1)
        bytesToSign.appendData((info["appID"] as! String).sha256())
        bytesToSign.appendData(clientData.sha256())
        bytesToSign.appendData(keyHandle)
        bytesToSign.appendData(keyRefs.publicKey)
        
        if let signature = sign(bytes: bytesToSign, usingKeyWithAlias: keyRefs.privateAlias) {
            
            registrationData.appendBytes(&reserved, length: sizeofValue(reserved))
            registrationData.appendData(keyRefs.publicKey)
            print("\nKey handle length: \(keyHandleLength), key handle: \(keyHandle)")
            registrationData.appendBytes(&keyHandleLength, length: 1)
            registrationData.appendData(keyHandle)
            registrationData.appendData(x509Certificate)
            print("Certificate: \(x509Certificate)")
            registrationData.appendData(signature)
            
            print("\nRegistration data: \(registrationData)")
            
            let registration: [String:AnyObject] = [
                "successful": true,
                "data": [
                    "type": "2q2r",
                    "deviceName": UIDevice.currentDevice().name,
                    "fcmToken": "",
                    "clientData": clientData,
                    "registrationData": registrationData.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
                ]
            ]
            
            do {
                
                let json = try NSJSONSerialization.dataWithJSONObject(registration, options: NSJSONWritingOptions(rawValue: 0))
                
                let baseURL = info["baseURL"] as! String
                let regURL = baseURL + (baseURL.substringFromIndex(baseURL.endIndex) == "/" ? "" : "/") + "v1/register"
            
                if let url = NSURL(string: regURL) {
                    
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
            
        }
        
    }
    
}

private func authenticate(appID appID: String, challenge: String, keyID: String, baseURL: String) {
    
    let clientData = "{\"typ\":\"navigator.id.getAssertion\",\"challenge\":\"\(challenge)\",\"origin\":\"\(baseURL)\"}"
    
    let dataToBeSigned = NSMutableData()
    
    // TODO: sign U2F data
    
    if let signedData = sign(bytes: dataToBeSigned, usingKeyWithAlias: keyID) {
        
        let registrationData = NSMutableData()
        
        let userPresence: UInt8 = 0x1
        let counter: UInt32 = UInt32(getCounter(forKey: keyID)!)
        
        
        
    } else {
        
        print("Failed to sign authentication data.")
        
    }
    
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
        kSecAttrLabel as String: "private",
        kSecAttrApplicationTag as String: alias,
        kSecAttrAccessControl as String: access
    ]
    
    // Public key parameters
    keyParams[kSecPublicKeyAttrs as String] = [
        kSecAttrIsPermanent as String: true,
        kSecAttrLabel as String: "public",
        kSecAttrApplicationTag as String: alias
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
        kSecAttrLabel as String: "public",
        kSecAttrApplicationTag as String: alias,
        kSecAttrKeyType as String: kSecAttrKeyTypeEC,
        kSecReturnData as String: true
    ]
    var pubKeyOpt: AnyObject?
    err = SecItemCopyMatching(query, &pubKeyOpt)
    
    if let pubKey = pubKeyOpt as? NSData where err == errSecSuccess {
        
        return (alias, pubKey)
        
    } else {
        
        print("Error retrieving public key: \(err).")
        return nil
        
    }
    
}

private func sign(bytes data: NSData, usingKeyWithAlias alias: String) -> NSData? {
    
    let query = [
        kSecClass as String: kSecClassKey,
        kSecAttrLabel as String: "private",
        kSecAttrApplicationTag as String: alias,
        kSecAttrKeyType as String: kSecAttrKeyTypeEC,
        kSecReturnRef as String: true
    ]
    
    var privateKey: AnyObject?
    var error = SecItemCopyMatching(query, &privateKey)
    
    guard error == errSecSuccess else {
        
        print("Could not obtain reference to private key with alias \"\(alias)\", error: \(error).")
        return nil
        
    }
    
    let hashedData = NSMutableData(length: Int(CC_SHA256_DIGEST_LENGTH))!
    CC_SHA256(data.bytes, CC_LONG(data.length), UnsafeMutablePointer(hashedData.mutableBytes))
    
    var signedHashLength = 256 // Allocate way more bytes than needed! After SecKeyRawSign is done, it will rewrite this value to the number of bytes it actually used in the buffer. No clue why.
    let signedHash = NSMutableData(length: signedHashLength)!
    
    error = SecKeyRawSign(privateKey as! SecKeyRef, .PKCS1SHA256, UnsafePointer<UInt8>(hashedData.mutableBytes), hashedData.length, UnsafeMutablePointer<UInt8>(signedHash.mutableBytes), &signedHashLength)
    
    guard error == errSecSuccess else {
        
        print("Failed to sign data, error: \(error).")
        return nil
        
    }
    
    return signedHash.subdataWithRange(NSMakeRange(0, 71))
    
}


// Very hacky--we gutted everything but the public key bytes from
// a successful Android certificate and simply insert new public
// key bytes into that template.
private func generateX509(forKey key: NSData) -> NSData {
    
    let certificate = NSMutableData()
    
    let certBeginning: [UInt8] = [0x30, 0x81, 0xc5, 0x30, 0x81, 0xb1, 0xa0, 0x03, 0x02, 0x01, 0x02, 0x02, 0x01, 0x01, 0x30, 0x0a, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x04, 0x03, 0x02, 0x30, 0x0f, 0x31, 0x0d, 0x30, 0x0b, 0x06, 0x03, 0x55, 0x04, 0x03, 0x13, 0x04, 0x66, 0x61, 0x6b, 0x65, 0x30, 0x1e, 0x17, 0x0d, 0x37, 0x30, 0x30, 0x31, 0x30, 0x31, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x5a, 0x17, 0x0d, 0x34, 0x38, 0x30, 0x31, 0x30, 0x31, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x5a, 0x30, 0x0f, 0x31, 0x0d, 0x30, 0x0b, 0x06, 0x03, 0x55, 0x04, 0x03, 0x13, 0x04, 0x66, 0x61, 0x6b, 0x65, 0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00]
    
    let certEnd: [UInt8] = [0x30, 0x0a, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x04, 0x03, 0x02, 0x03, 0x03, 0x00, 0x30, 0x00]
    
    certificate.appendBytes(certBeginning, length: certBeginning.count)
    certificate.appendData(key)
    certificate.appendBytes(certEnd, length: certEnd.count)
    
    return certificate
    
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
    print("Server response: \(status)")
    
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
        
        displayText(withTitle: cache["appName"], withMessage: "Authentication declined.")
        
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



























