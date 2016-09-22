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
    
    case registrationSuccess, authenticationSuccess, userAuthNotSet, userAuthFailed, userAuthCanceled, internetError, unknownKey, unknownServer, serverError, deviceAlreadyRegistered, registrationDeclined, authenticationDeclined, authenticationTimeout, unspecified /* Should not ever appear in final application, because error handling will eventually cover every scenario. */
    
    func description() -> String {
        
        switch self {
            case .registrationSuccess:
                return "Registration successful!"
            case .authenticationSuccess:
                return "Authentication successful!"
            case .userAuthNotSet:
                return "You must have a password set on your device to generate and use 2Q2R keys. TouchID is even better."
            case .userAuthFailed:
                return "You failed to verify yourself. Please scan the QR and try again."
            case .userAuthCanceled:
                return "You declined the operation."
            case .internetError:
                return "Could not reach the server. Please check your internet connection and try again."
            case .unknownKey:
                return "Sorry, could not find key information to authenticate. You may have deleted it."
            case .unknownServer:
                return "You are not registered with this server. You may have deleted all your keys for this server on this device, causing it to be forgotten."
            case .serverError:
                return "The server sent badly formatter information. Please contact an admin."
            case .deviceAlreadyRegistered:
                return "This device is already registered to your account."
            case .registrationDeclined:
                return "Registration declined."
            case .authenticationDeclined:
                return "Authentication declined."
            case .authenticationTimeout:
                return "The authentication request timed out. Please re-login in your browser and try again."
            case .unspecified:
                return "Sorry, an unspecified error has occurred."
        }
        
    }

}

protocol U2FAction {
    
    func execute()
    
}

func process2Q2RRequest(_ req: String) -> U2FAction? {
    
    print(req)
    
    if req.characters.count == 0 {
        return nil
    }
    
    let qrArgs = req.components(separatedBy: " ")
    
    switch qrArgs[0] {
    case "R":
        if qrArgs.count != 4 {
            print("Incorrect number of arguments.")
            break
        } else if decodeFromWebsafeBase64ToBase64Data(qrArgs[1]).count != 32 {
            print("Challenge of incorrect length: \(decodeFromWebsafeBase64ToBase64Data(qrArgs[1]).count) bytes.")
            break
        } else if qrArgs[2] =~ "[a-zA-Z0-9:/.]+" {
            return U2FActionRegister(challenge: qrArgs[1], infoURL: qrArgs[2], userID: qrArgs[3])
        }
    case "A":
        if qrArgs.count != 5 {
            break
        } else if decodeFromWebsafeBase64ToBase64Data(qrArgs[1]).count != 32 {
            break
        } else if decodeFromWebsafeBase64ToBase64Data(qrArgs[2]).count != 32 {
            break
        } else if let counterInt = Int(qrArgs[4]) {
            return U2FActionAuthenticate(appID: qrArgs[1], challenge: qrArgs[2], keyID: qrArgs[3], counter: counterInt)
        }
    default: break
    }
    
    return nil
    
}

class U2FActionRegister: U2FAction {
    
    fileprivate static let keyHandleLength: UInt8 = 16
    
    fileprivate let challenge: String
    fileprivate let infoURL: String
    fileprivate let userID: String
    
    fileprivate var appName: String! = "Uknown Server"
    fileprivate var appID: String!
    fileprivate var appURL: String!
    
    init(challenge: String, infoURL: String, userID: String) {
        
        self.challenge = challenge
        self.infoURL = infoURL
        self.userID = userID
        
    }
    
    func execute() {
        
        DispatchQueue.global().async {
            
            self.fetchServerInfo()
            
        }
        
    }
    
    fileprivate func fetchServerInfo() {
        
        sendJSONToURL(infoURL, json: nil, method: "GET") { (data: Data?, response: URLResponse?, error: Error?) in
            
            do {
                
                if let res = data {
                    
                    let json = try JSONSerialization.jsonObject(with: res, options: JSONSerialization.ReadingOptions()) as! [String:AnyObject]
                    
                    self.appName = json["appName"] as! String
                    self.appID = json["appID"] as! String
                    self.appURL = json["appURL"] as! String
                    
                    if userIsAlreadyRegistered(self.userID, forServer: self.appID) {
                        
                        displayError(.deviceAlreadyRegistered, withTitle: self.appName)
                        return
                        
                    } else {
                    
                        confirmResponseFromBackgroundThread(.register, challenge: self.challenge, appName: self.appName, userID: self.userID) { (approved) in
                            
                            if approved {
                                
                                self.sendRegistrationResponse()
                                
                            }
                            
                        }
                        
                    }
                    
                } else {
                    
                    displayError(.internetError, withTitle: "Connection Error")
                    
                }
                
            } catch {
            
                displayError(.serverError, withTitle: "Bad Info")
            
            }
            
        }
        
    }
    
    fileprivate func genKeyPair() -> (privateAlias: String, pubKey: Data)? {
        
        // Generate a keyhandle, which will be returned as an alias for the private key
        let numBytes = Int(U2FActionRegister.keyHandleLength)
        var randomBytes = [UInt8](repeating: 0, count: numBytes)
		var err: OSStatus = SecRandomCopyBytes(kSecRandomDefault, numBytes, &randomBytes)
        
        guard err == errSecSuccess else {
            
            displayError(.unspecified, withTitle: "Failed to Generate Key Handle")
            return nil
            
        }
        
        let data = Data(bytes: randomBytes)
        var alias = data.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
		alias = alias.makeWebsafe()
		
		err = KeyGenerator.generatePairInSecureEnclave(withHandle: alias)
		
//        let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .touchIDCurrentSet, nil)!
//        
//        // Key pair parameters
//        let keyParams: [String:AnyObject] = [
//            kSecAttrKeyType as String: kSecAttrKeyTypeEC,
//            kSecAttrKeySizeInBits as String: 256 as AnyObject,
//            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
//            kSecPrivateKeyAttrs as String: [
//                kSecAttrIsPermanent as String: true,
//                kSecAttrLabel as String: "private",
//                kSecAttrApplicationTag as String: alias,
//                kSecAttrAccessControl as String: access
//            ] as AnyObject,
//            kSecPublicKeyAttrs as String: [
//                kSecAttrIsPermanent as String: true,
//                kSecAttrLabel as String: "public",
//                kSecAttrApplicationTag as String: alias
//                ] as AnyObject
//        ]
//        
//        var pubKeyRef, privKeyRef: SecKey?
//        err = SecKeyGeneratePair(keyParams as CFDictionary, &pubKeyRef, &privKeyRef)
//        
//        guard let _ = pubKeyRef , err == errSecSuccess else {
//            
//            print(err)
//            displayError(err == errSecAuthFailed ? .userAuthNotSet : .unspecified, withTitle: "Key Generation Failed")
//            return nil
//            
//        }
		
        // Export the public key for application use
        let query: [String:AnyObject] = [
            kSecClass as String: kSecClassKey,
            kSecAttrLabel as String: "public" as AnyObject,
            kSecAttrApplicationTag as String: alias as AnyObject,
            kSecAttrKeyType as String: kSecAttrKeyTypeEC,
            kSecReturnData as String: true as AnyObject
        ]
        var pubKeyOpt: AnyObject?
        err = SecItemCopyMatching(query as CFDictionary, &pubKeyOpt)
        
        if let pubKey = pubKeyOpt as? Data , err == errSecSuccess {
            
            return (alias, pubKey)
            
        } else {
            
            displayError(.unspecified, withTitle: "Failed to Export Public Key")
            return nil
            
        }
        
    }
    
    fileprivate func generateX509(forPublicKey pubKey: Data) -> Data {
        
        let certificate = NSMutableData()
        
        let certBeginning: [UInt8] = [0x30, 0x81, 0xc5, 0x30, 0x81, 0xb1, 0xa0, 0x03, 0x02, 0x01, 0x02, 0x02, 0x01, 0x01, 0x30, 0x0a, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x04, 0x03, 0x02, 0x30, 0x0f, 0x31, 0x0d, 0x30, 0x0b, 0x06, 0x03, 0x55, 0x04, 0x03, 0x13, 0x04, 0x66, 0x61, 0x6b, 0x65, 0x30, 0x1e, 0x17, 0x0d, 0x37, 0x30, 0x30, 0x31, 0x30, 0x31, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x5a, 0x17, 0x0d, 0x34, 0x38, 0x30, 0x31, 0x30, 0x31, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x5a, 0x30, 0x0f, 0x31, 0x0d, 0x30, 0x0b, 0x06, 0x03, 0x55, 0x04, 0x03, 0x13, 0x04, 0x66, 0x61, 0x6b, 0x65, 0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00]
        
        let certEnd: [UInt8] = [0x30, 0x0a, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x04, 0x03, 0x02, 0x03, 0x03, 0x00, 0x30, 0x00]
        
        certificate.append(certBeginning, length: certBeginning.count)
        certificate.append(pubKey)
        certificate.append(certEnd, length: certEnd.count)
        
        return certificate as Data
        
    }
    
    fileprivate func sign(bytes data: Data, usingKeyWithAlias alias: String) -> Data? {
        
        let query = [
            kSecClass as String: kSecClassKey,
            kSecAttrLabel as String: "private",
            kSecAttrApplicationTag as String: alias,
            kSecAttrKeyType as String: kSecAttrKeyTypeEC,
            kSecReturnRef as String: true
        ] as [String : Any]
        
        var privateKey: AnyObject?
        var error = SecItemCopyMatching(query as CFDictionary, &privateKey)
        
        guard error == errSecSuccess else {
            
            if error == errSecItemNotFound {
                
                displayError(.unspecified, withTitle: "Private Key Not Found")
                
            } else {
                
                displayError(error == errSecUserCanceled ? .userAuthCanceled : .userAuthFailed, withTitle: "Private Key Access Denied")
                
            }
            
            return nil
            
        }
        
        var hashedData = genEmptyBuffer(withLength: Int(CC_SHA256_DIGEST_LENGTH))
        let hashedDataPointer = hashedData.withUnsafeMutableBytes { mutableBytes in
            CC_SHA256((data as NSData).bytes, CC_LONG(data.count), mutableBytes)
        }
        
        var signedHashLength = 256 // Allocate way more bytes than needed! Once SecKeyRawSign is done, it will rewrite this value to the number of bytes it actually used in the buffer. No clue why.
        var signedHash = genEmptyBuffer(withLength: signedHashLength)
        
        signedHash.withUnsafeMutableBytes { mutableBytes in
            error = SecKeyRawSign(privateKey as! SecKey, .PKCS1, hashedDataPointer!, hashedData.count, mutableBytes, &signedHashLength)
        }
        
        guard error == errSecSuccess else {
            
            print("Failed to sign data, error: \(error).")
            
            switch error {
            case errSecAuthFailed:
                displayError(.userAuthFailed, withTitle: "Could not Sign Registration Response")
            case errSecUserCanceled:
                displayError(.userAuthCanceled, withTitle: self.appName)
            default:
                displayError(.unspecified, withTitle: "Could not Sign Registration Response")
            }
            
            return nil
            
        }
        
        return signedHash.subdata(in: 0..<signedHashLength)
        
    }
    
    fileprivate func sendRegistrationResponse() {
        
        if let keyRefs = genKeyPair() {
        
            let registrationData = NSMutableData()
            let bytesToSign = NSMutableData()
            
            let clientData = "{\"type\":\"navigator.id.finishEnrollment\",\"challenge\":\"\(self.challenge)\",\"origin\":\"\(self.appURL!)\"}"
            
            var futureUse: UInt8 = 0x00
            var reserved: UInt8 = 0x05
            let keyHandle = decodeFromWebsafeBase64ToBase64Data(keyRefs.privateAlias)
            var keyHandleLength = UInt8(keyHandle.count)
            
            bytesToSign.append(&futureUse, length: 1)
            bytesToSign.append(self.appURL.sha256() as Data)
            bytesToSign.append(clientData.sha256() as Data)
            bytesToSign.append(keyHandle)
            bytesToSign.append(keyRefs.pubKey)
            
            if let signature = sign(bytes: bytesToSign as Data, usingKeyWithAlias: keyRefs.privateAlias) {
                
                registrationData.append(&reserved, length: MemoryLayout.size(ofValue: reserved))
                registrationData.append(keyRefs.pubKey)
                registrationData.append(&keyHandleLength, length: 1)
                registrationData.append(keyHandle)
                registrationData.append(generateX509(forPublicKey: keyRefs.pubKey))
                registrationData.append(signature)
                
                let registration: [String:AnyObject] = [
                    "successful": true as AnyObject,
                    "data": [
                        "type": "2q2r",
                        "deviceName": UIDevice.current.name,
                        "fcmToken": FIRInstanceID.instanceID().token()!,
                        "clientData": clientData.asBase64(websafe: true),
                        "registrationData": registrationData.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0)).makeWebsafe()
                        ] as AnyObject
                ]
                
                print("FCM Token: \"\(FIRInstanceID.instanceID().token()!)\"")
                
                let regURL = self.appURL + (self.appURL.substring(from: self.appURL.endIndex) == "/" ? "" : "/") + "v1/register"
                
                sendJSONToURL(regURL, json: registration, method: "POST") { (data: Data?, response: URLResponse?, error: Error?) in
                    
                    let status = (response as! HTTPURLResponse).statusCode
                    
                    if status == 200 {
                        
                        if getInfo(forServer: self.appID) == nil {
                            
                            insertNewServer(self.appID, appName: self.appName, appURL: self.appURL)
                            
                        }
                        
                        insertNewKey(keyRefs.privateAlias, appID: self.appID, userID: self.userID)
                        
                        recentKeys = getRecentKeys()
                        allKeys = getAllKeys()
                        
                        displayError(.registrationSuccess, withTitle: self.appName)
                        
                    } else {
                        
                        displayError(.registrationDeclined, withTitle: self.appName)
                        
                    }
                    
                }
                
            }
            
        }
    
    }

}

class U2FActionAuthenticate: U2FAction {
    
    fileprivate let appID: String
    fileprivate let challenge: String
    fileprivate let keyID: String
    fileprivate let counter: Int
    
    fileprivate var appName: String!
    fileprivate var appURL: String!
    
    init(appID: String, challenge: String, keyID: String, counter: Int) {
        
        self.appID = appID
        self.challenge = challenge
        self.keyID = keyID
        self.counter = counter
        
        print("Counter: \(self.counter)")
        
    }
    
    func execute() {
        
        DispatchQueue.main.async {
            
            if let serverInfo = getInfo(forServer: self.appID) {
                
                self.appName = serverInfo.appName
                self.appURL = serverInfo.appURL
                
                if let userID = getUserID(forKey: self.keyID) {
                    
                    confirmResponseFromBackgroundThread(.authenticate, challenge: self.challenge, appName: self.appName, userID: userID) { (approved) in
                        
                        if approved {
                            
                            self.sendAuthenticationResponse()
                            
                        }
                        
                    }
                    
                }
                
            } else {
                
                displayError(.unknownServer, withTitle: "Server Information Not Found")
                
            }
            
        }
        
    }
    
    fileprivate func sign(bytes data: Data, usingKeyWithAlias alias: String) -> Data? {
        
        let query = [
            kSecClass as String: kSecClassKey,
            kSecAttrLabel as String: "private",
            kSecAttrApplicationTag as String: alias,
            kSecAttrKeyType as String: kSecAttrKeyTypeEC,
            kSecReturnRef as String: true
            ] as [String : Any]
        
        var privateKey: AnyObject?
        var error = SecItemCopyMatching(query as CFDictionary, &privateKey)
        
        guard error == errSecSuccess else {
            
            if error == errSecItemNotFound {
                
                displayError(.unspecified, withTitle: "Private Key Not Found")
                
            } else {
                
                displayError(error == errSecUserCanceled ? .userAuthCanceled : .userAuthFailed, withTitle: "Private Key Access Denied")
                
            }
            
            return nil
            
        }
        
        var hashedData = genEmptyBuffer(withLength: Int(CC_SHA256_DIGEST_LENGTH))
        let hashedDataPointer = hashedData.withUnsafeMutableBytes { mutableBytes in
            CC_SHA256((data as NSData).bytes, CC_LONG(data.count), mutableBytes)
        }
        
        var signedHashLength = 256 // Allocate way more bytes than needed! Once SecKeyRawSign is done, it will rewrite this value to the number of bytes it actually used in the buffer. No clue why.
        var signedHash = genEmptyBuffer(withLength: signedHashLength)
        
        signedHash.withUnsafeMutableBytes { mutableBytes in
            error = SecKeyRawSign(privateKey as! SecKey, .PKCS1, hashedDataPointer!, hashedData.count, mutableBytes, &signedHashLength)
        }
        
        guard error == errSecSuccess else {
            
            print("Failed to sign data, error: \(error).")
            
            switch error {
            case errSecAuthFailed:
                displayError(.userAuthFailed, withTitle: "Could not Sign Registration Response")
            case errSecUserCanceled:
                displayError(.userAuthCanceled, withTitle: self.appName)
            default:
                displayError(.unspecified, withTitle: "Could not Sign Registration Response")
            }
            
            return nil
            
        }
        
        return signedHash.subdata(in: 0..<signedHashLength)
        
    }
    
    fileprivate func sendAuthenticationResponse() {
        
        let clientData = "{\"typ\":\"navigator.id.getAssertion\",\"challenge\":\"\(self.challenge)\",\"origin\":\"\(self.appURL!)\"}"
        
        let dataToBeSigned = NSMutableData()
        
        let applicationParameter: Data = self.appURL.sha256() as Data
        var userPresence: UInt8 = 0x1
        var counterBytes: UInt32 = UInt32(self.counter).byteSwapped // iOS uses little-endian, server expects big-endian
        let challengeParameter: Data = clientData.sha256() as Data
        
        dataToBeSigned.append(applicationParameter)
        dataToBeSigned.append(&userPresence, length: MemoryLayout<UInt8>.size)
        dataToBeSigned.append(&counterBytes, length: MemoryLayout<UInt32>.size)
        dataToBeSigned.append(challengeParameter)
        
        if let signedData = sign(bytes: dataToBeSigned as Data, usingKeyWithAlias: self.keyID) {
            
            let authenticationData = NSMutableData()
            
            authenticationData.append(&userPresence, length: MemoryLayout<UInt8>.size)
            authenticationData.append(&counterBytes, length: MemoryLayout<UInt32>.size)
            authenticationData.append(signedData)
            
            let authenticationResponse: [String:AnyObject] = [
                "successful": true as AnyObject,
                "data": [
                    "clientData": clientData.asBase64(websafe: true),
                    "signatureData": authenticationData.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0)).makeWebsafe()
                ] as AnyObject
            ]
            
            let authenticationURL = appURL + (appURL.substring(from: appURL.endIndex) == "/" ? "" : "/") + "v1/auth"
            
            sendJSONToURL(authenticationURL, json: authenticationResponse, method: "POST") { (data: Data?, response: URLResponse?, error: Error?) in
                
                if let res = response as? HTTPURLResponse {
                    
                    let status = res.statusCode
                    
                    switch status {
                        case 200:
                            setCounter(forKey: self.keyID, to: self.counter)
                            displayError(.authenticationSuccess, withTitle: self.appName)
                            recentKeys = getRecentKeys()
                            allKeys = getAllKeys()
                        case 401:
                            displayError(.authenticationDeclined, withTitle: self.appName)
                        case 408:
                            displayError(.authenticationTimeout, withTitle: self.appName)
                        default: break
                    }
                    
                } else {
                    
                    displayError(.internetError, withTitle: "Server Did Not Respond")
                    
                }
                
            }
            
        }
        
    }
    
}




















