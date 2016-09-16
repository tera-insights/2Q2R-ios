//
//  U2FAction.swift
//  2Q2R
//
//  Created by Sam on 9/15/16.
//  Copyright © 2016 Tera Insights, LLC. All rights reserved.
//

import Security
import Firebase

enum SecError {
    
    case RegistrationSuccess, AuthenticationSuccess, UserAuthNotSet, UserAuthFailed, UserAuthCanceled, InternetError, UnknownKey, UnknownServer, ServerError, DeviceAlreadyRegistered, RegistrationDeclined, AuthenticationDeclined, AuthenticationTimeout, Unspecified /* Should not ever appear in final application, because error handling will eventually cover every scenario. */
    
    func description() -> String {
        
        switch self {
            case .RegistrationSuccess:
                return "Registration successful!"
            case .AuthenticationSuccess:
                return "Authentication successful!"
            case .UserAuthNotSet:
                return "You must have a password set on your device to generate and use 2Q2R keys. TouchID is even better."
            case .UserAuthFailed:
                return "You failed to verify yourself. Please scan the QR and try again."
            case .UserAuthCanceled:
                return "You declined the operation."
            case .InternetError:
                return "Could not reach the server. Please check your internet connection and try again."
            case .UnknownKey:
                return "Sorry, could not find key information to authenticate. You may have deleted it."
            case .UnknownServer:
                return "You are not registered with this server. You may have deleted all your keys for this server on this device, causing it to be forgotten."
            case .ServerError:
                return "The server sent badly formatter information. Please contact an admin."
            case .DeviceAlreadyRegistered:
                return "This device is already registered to your account."
            case .RegistrationDeclined:
                return "Registration declined."
            case .AuthenticationDeclined:
                return "Authentication declined."
            case .AuthenticationTimeout:
                return "The authentication request timed out. Please re-login in your browser and try again."
            case .Unspecified:
                return "Sorry, an unspecified error has occurred."
        }
        
    }

}

protocol U2FAction {
    
    func execute()
    
}

func process2Q2RRequest(req: String) -> U2FAction? {
    
    print(req)
    
    if req.characters.count == 0 {
        return nil
    }
    
    let qrArgs = req.componentsSeparatedByString(" ")
    
    switch qrArgs[0] {
    case "R":
        if qrArgs.count != 4 {
            print("Incorrect number of arguments.")
            break
        } else if decodeFromWebsafeBase64ToBase64Data(qrArgs[1]).length != 32 {
            print("Challenge of incorrect length: \(decodeFromWebsafeBase64ToBase64Data(qrArgs[1]).length) bytes.")
            break
        } else if qrArgs[2] =~ "[a-zA-Z0-9:/.]+" {
            return U2FActionRegister(challenge: qrArgs[1], infoURL: qrArgs[2], userID: qrArgs[3])
        }
    case "A":
        if qrArgs.count != 5 {
            break
        } else if decodeFromWebsafeBase64ToBase64Data(qrArgs[1]).length != 32 {
            break
        } else if decodeFromWebsafeBase64ToBase64Data(qrArgs[2]).length != 32 {
            break
        } else if let counterInt = Int(qrArgs[4]) {
            return U2FActionAuthenticate(appID: qrArgs[1], challenge: qrArgs[2], keyID: qrArgs[3], counter: counterInt)
        }
    default: break
    }
    
    return nil
    
}

class U2FActionRegister: U2FAction {
    
    private static let keyHandleLength: UInt8 = 16
    
    private let challenge: String
    private let infoURL: String
    private let userID: String
    
    private var appName: String! = "Uknown Server"
    private var appID: String!
    private var baseURL: String!
    
    init(challenge: String, infoURL: String, userID: String) {
        
        self.challenge = challenge
        self.infoURL = infoURL
        self.userID = userID
        
    }
    
    func execute() {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
            
            self.fetchServerInfo()
            
        }
        
    }
    
    private func fetchServerInfo() {
        
        sendJSONToURL(infoURL, json: nil, method: "GET") { (data: NSData?, response: NSURLResponse?, error: NSError?) in
            
            do {
                
                if let res = data {
                    
                    let json = try NSJSONSerialization.JSONObjectWithData(res, options: NSJSONReadingOptions()) as! [String:AnyObject]
                    
                    self.appName = json["appName"] as! String
                    self.appID = json["appID"] as! String
                    self.baseURL = json["baseURL"] as! String
                    
                    if userIsAlreadyRegistered(self.userID, forServer: self.appID) {
                        
                        displayError(.DeviceAlreadyRegistered, withTitle: self.appName)
                        return
                        
                    } else {
                    
                        confirmResponseFromBackgroundThread(.Register, challenge: self.challenge, appName: self.appName, userID: self.userID) { (approved) in
                            
                            if approved {
                                
                                self.sendRegistrationResponse()
                                
                            }
                            
                        }
                        
                    }
                    
                } else {
                    
                    displayError(.InternetError, withTitle: "Connection Error")
                    
                }
                
            } catch {
            
                displayError(.ServerError, withTitle: "Bad Info")
            
            }
            
        }
        
    }
    
    private func genKeyPair() -> (privateAlias: String, pubKey: NSData)? {
        
        // Generate a keyhandle, which will be returned as an alias for the private key
        let numBytes = Int(U2FActionRegister.keyHandleLength)
        var randomBytes = [UInt8](count: numBytes, repeatedValue: 0)
        SecRandomCopyBytes(kSecRandomDefault, numBytes, &randomBytes)
        let data = NSData(bytes: &randomBytes, length: numBytes)
        var alias = data.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
        alias.makeWebsafe()
        
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
            
            displayError(err == errSecAuthFailed ? .UserAuthNotSet : .Unspecified, withTitle: "Key Generation Failed")
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
            
            displayError(.Unspecified, withTitle: "Failed to Export Public Key")
            return nil
            
        }
        
    }
    
    private func generateX509(forPublicKey pubKey: NSData) -> NSData {
        
        let certificate = NSMutableData()
        
        let certBeginning: [UInt8] = [0x30, 0x81, 0xc5, 0x30, 0x81, 0xb1, 0xa0, 0x03, 0x02, 0x01, 0x02, 0x02, 0x01, 0x01, 0x30, 0x0a, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x04, 0x03, 0x02, 0x30, 0x0f, 0x31, 0x0d, 0x30, 0x0b, 0x06, 0x03, 0x55, 0x04, 0x03, 0x13, 0x04, 0x66, 0x61, 0x6b, 0x65, 0x30, 0x1e, 0x17, 0x0d, 0x37, 0x30, 0x30, 0x31, 0x30, 0x31, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x5a, 0x17, 0x0d, 0x34, 0x38, 0x30, 0x31, 0x30, 0x31, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x5a, 0x30, 0x0f, 0x31, 0x0d, 0x30, 0x0b, 0x06, 0x03, 0x55, 0x04, 0x03, 0x13, 0x04, 0x66, 0x61, 0x6b, 0x65, 0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00]
        
        let certEnd: [UInt8] = [0x30, 0x0a, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x04, 0x03, 0x02, 0x03, 0x03, 0x00, 0x30, 0x00]
        
        certificate.appendBytes(certBeginning, length: certBeginning.count)
        certificate.appendData(pubKey)
        certificate.appendBytes(certEnd, length: certEnd.count)
        
        return certificate
        
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
            
            if error == errSecItemNotFound {
                
                displayError(.Unspecified, withTitle: "Private Key Not Found")
                
            } else {
                
                displayError(error == errSecUserCanceled ? .UserAuthCanceled : .UserAuthFailed, withTitle: "Private Key Access Denied")
                
            }
            
            return nil
            
        }
        
        let hashedData = NSMutableData(length: Int(CC_SHA256_DIGEST_LENGTH))!
        CC_SHA256(data.bytes, CC_LONG(data.length), UnsafeMutablePointer(hashedData.mutableBytes))
        
        var signedHashLength = 256 // Allocate way more bytes than needed! After SecKeyRawSign is done, it will rewrite this value to the number of bytes it actually used in the buffer. No clue why.
        let signedHash = NSMutableData(length: signedHashLength)!
        
        error = SecKeyRawSign(privateKey as! SecKeyRef, .PKCS1, UnsafePointer<UInt8>(hashedData.mutableBytes), hashedData.length, UnsafeMutablePointer<UInt8>(signedHash.mutableBytes), &signedHashLength)
        
        guard error == errSecSuccess else {
            
            print("Failed to sign data, error: \(error).")
            
            switch error {
            case errSecAuthFailed:
                displayError(.UserAuthFailed, withTitle: "Could not Sign Registration Response")
            case errSecUserCanceled:
                displayError(.UserAuthCanceled, withTitle: self.appName)
            default:
                displayError(.Unspecified, withTitle: "Could not Sign Registration Response")
            }
            
            return nil
            
        }
        
        return signedHash.subdataWithRange(NSMakeRange(0, signedHashLength))
        
    }
    
    private func sendRegistrationResponse() {
        
        if let keyRefs = genKeyPair() {
        
            let registrationData = NSMutableData()
            let bytesToSign = NSMutableData()
            
            let clientData = "{\"type\":\"navigator.id.finishEnrollment\",\"challenge\":\"\(self.challenge)\",\"origin\":\"\(self.baseURL)\"}"
            
            var futureUse: UInt8 = 0x00
            var reserved: UInt8 = 0x05
            let keyHandle = decodeFromWebsafeBase64ToBase64Data(keyRefs.privateAlias)
            var keyHandleLength = UInt8(keyHandle.length)
            
            bytesToSign.appendBytes(&futureUse, length: 1)
            bytesToSign.appendData(self.appID.sha256())
            bytesToSign.appendData(clientData.sha256())
            bytesToSign.appendData(keyHandle)
            bytesToSign.appendData(keyRefs.pubKey)
            
            if let signature = sign(bytes: bytesToSign, usingKeyWithAlias: keyRefs.privateAlias) {
                
                registrationData.appendBytes(&reserved, length: sizeofValue(reserved))
                registrationData.appendData(keyRefs.pubKey)
                registrationData.appendBytes(&keyHandleLength, length: 1)
                registrationData.appendData(keyHandle)
                registrationData.appendData(generateX509(forPublicKey: keyRefs.pubKey))
                registrationData.appendData(signature)
                
                let registration: [String:AnyObject] = [
                    "successful": true,
                    "data": [
                        "type": "2q2r",
                        "deviceName": UIDevice.currentDevice().name,
                        "fcmToken": FIRInstanceID.instanceID().token()!,
                        "clientData": clientData.asBase64(websafe: false),
                        "registrationData": registrationData.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
                    ]
                ]
                
                print("FCM Token: \"\(FIRInstanceID.instanceID().token()!)\"")
                
                let regURL = self.baseURL + (self.baseURL.substringFromIndex(self.baseURL.endIndex) == "/" ? "" : "/") + "v1/register"
                
                sendJSONToURL(regURL, json: registration, method: "POST") { (data: NSData?, response: NSURLResponse?, error: NSError?) in
                    
                    let status = (response as! NSHTTPURLResponse).statusCode
                    
                    if status == 200 {
                        
                        if getInfo(forServer: self.appID) == nil {
                            
                            insertNewServer(self.appID, appName: self.appName, baseURL: self.baseURL)
                            
                        }
                        
                        insertNewKey(keyRefs.privateAlias, appID: self.appID, userID: self.userID)
                        
                        recentKeys = getRecentKeys()
                        allKeys = getAllKeys()
                        
                        displayError(.RegistrationSuccess, withTitle: self.appName)
                        
                    } else {
                        
                        displayError(.RegistrationDeclined, withTitle: self.appName)
                        
                    }
                    
                }
                
            }
            
        }
    
    }

}

class U2FActionAuthenticate: U2FAction {
    
    private let appID: String
    private let challenge: String
    private let keyID: String
    private let counter: Int
    
    private var appName: String!
    private var baseURL: String!
    
    init(appID: String, challenge: String, keyID: String, counter: Int) {
        
        self.appID = appID
        self.challenge = challenge
        self.keyID = keyID
        self.counter = counter
        
        print("Counter: \(self.counter)")
        
    }
    
    func execute() {
        
        dispatch_async(dispatch_get_main_queue()) {
            
            if let serverInfo = getInfo(forServer: self.appID) {
                
                self.appName = serverInfo.appName
                self.baseURL = serverInfo.baseURL
                
                if let userID = getUserID(forKey: self.keyID) {
                    
                    confirmResponseFromBackgroundThread(.Authenticate, challenge: self.challenge, appName: self.appName, userID: userID) { (approved) in
                        
                        if approved {
                            
                            self.sendAuthenticationResponse()
                            
                        }
                        
                    }
                    
                }
                
            } else {
                
                displayError(.UnknownServer, withTitle: "Server Information Not Found")
                
            }
            
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
            
            if error == errSecItemNotFound {
                
                displayError(.Unspecified, withTitle: "Private Key Not Found")
                
            } else {
                
                displayError(error == errSecUserCanceled ? .UserAuthCanceled : .UserAuthFailed, withTitle: "Private Key Access Denied")
                
            }
            
            return nil
            
        }
        
        let hashedData = NSMutableData(length: Int(CC_SHA256_DIGEST_LENGTH))!
        CC_SHA256(data.bytes, CC_LONG(data.length), UnsafeMutablePointer(hashedData.mutableBytes))
        
        var signedHashLength = 256 // Allocate way more bytes than needed! After SecKeyRawSign is done, it will rewrite this value to the number of bytes it actually used in the buffer. No clue why.
        let signedHash = NSMutableData(length: signedHashLength)!
        
        error = SecKeyRawSign(privateKey as! SecKeyRef, .PKCS1, UnsafePointer<UInt8>(hashedData.mutableBytes), hashedData.length, UnsafeMutablePointer<UInt8>(signedHash.mutableBytes), &signedHashLength)
        
        guard error == errSecSuccess else {
            
            print("Failed to sign data, error: \(error).")
            
            switch error {
            case errSecAuthFailed:
                displayError(.UserAuthFailed, withTitle: "Could not Sign Registration Response")
            case errSecUserCanceled:
                displayError(.UserAuthCanceled, withTitle: self.appName)
            default:
                displayError(.Unspecified, withTitle: "Could not Sign Registration Response")
            }
            
            return nil
            
        }
        
        return signedHash.subdataWithRange(NSMakeRange(0, signedHashLength))
        
    }
    
    private func sendAuthenticationResponse() {
        
        let clientData = "{\"typ\":\"navigator.id.getAssertion\",\"challenge\":\"\(self.challenge)\",\"origin\":\"\(self.baseURL)\"}"
        
        let dataToBeSigned = NSMutableData()
        
        let applicationParameter: NSData = self.appID.sha256()
        var userPresence: UInt8 = 0x1
        var counterBytes: UInt32 = UInt32(self.counter)
        print("Counter bytes: \(counterBytes)")
        let challengeParameter: NSData = clientData.sha256()
        
        dataToBeSigned.appendData(applicationParameter)
        dataToBeSigned.appendBytes(&userPresence, length: sizeof(UInt8))
        dataToBeSigned.appendBytes(&counterBytes, length: sizeof(UInt32))
        dataToBeSigned.appendData(challengeParameter)
        
        if let signedData = sign(bytes: dataToBeSigned, usingKeyWithAlias: self.keyID) {
            
            let authenticationData = NSMutableData()
            
            authenticationData.appendBytes(&userPresence, length: sizeof(UInt8))
            authenticationData.appendBytes(&counterBytes, length: sizeof(UInt32))
            authenticationData.appendData(signedData)
            
            let authenticationResponse: [String:AnyObject] = [
                "successful": true,
                "data": [
                    "clientData": clientData.asBase64(websafe: false),
                    "signatureData": authenticationData.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
                ]
            ]
            
            let authenticationURL = baseURL + (baseURL.substringFromIndex(baseURL.endIndex) == "/" ? "" : "/") + "v1/auth"
            
            sendJSONToURL(authenticationURL, json: authenticationResponse, method: "POST") { (data: NSData?, response: NSURLResponse?, error: NSError?) in
                
                if let res = response as? NSHTTPURLResponse {
                    
                    let status = res.statusCode
                    
                    switch status {
                        case 200:
                            setCounter(forKey: self.keyID, to: self.counter)
                            displayError(.AuthenticationSuccess, withTitle: self.appName)
                            recentKeys = getRecentKeys()
                            allKeys = getAllKeys()
                        case 401:
                            displayError(.AuthenticationDeclined, withTitle: self.appName)
                        case 408:
                            displayError(.AuthenticationTimeout, withTitle: self.appName)
                        default: break
                    }
                    
                } else {
                    
                    displayError(.InternetError, withTitle: "Server Did Not Respond")
                    
                }
                
            }
            
        }
        
    }
    
}




















