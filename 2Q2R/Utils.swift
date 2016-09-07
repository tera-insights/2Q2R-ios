//
//  Utils.swift
//  2Q2R
//
//  Created by Sam Claus on 8/24/16.
//  Copyright © 2016 Tera Insights, LLC. All rights reserved.
//

import Foundation

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
    
    func sha256() -> NSData {
        
        let data = self.dataUsingEncoding(NSUTF8StringEncoding)!
        var hash = [UInt8](count: Int(CC_SHA256_DIGEST_LENGTH), repeatedValue: 0)
        
        CC_SHA256(data.bytes, CC_LONG(data.length), &hash)
        
        return NSData(bytes: hash, length: Int(CC_SHA256_DIGEST_LENGTH))
        
    }
    
}

func decodeFromWebsafeBase64(websafeString: String) -> NSData {
    
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

infix operator =~ {}
func =~ (input: String, pattern: String) -> Bool {
    return input.rangeOfString(pattern, options: .RegularExpressionSearch) != nil
}
