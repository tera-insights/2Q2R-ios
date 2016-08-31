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
    
    mutating func makeWebsafeBase64() {
        
        let data = self.dataUsingEncoding(NSUTF8StringEncoding)
        self = data!.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0)).stringByReplacingOccurrencesOfString("+", withString: "-").stringByReplacingOccurrencesOfString("/", withString: "_").stringByReplacingOccurrencesOfString("=", withString: "")
        
    }
    
}

func fromBase64(string: String) -> NSData {
    
    let data = NSData(base64EncodedString: string, options: NSDataBase64DecodingOptions(rawValue: 0))
    return data!
    
}

infix operator =~ {}
func =~ (input: String, pattern: String) -> Bool {
    return input.rangeOfString(pattern, options: .RegularExpressionSearch) != nil
}
