//
//  KeyGenerator.h
//  2Q2R
//
//  Created by Sam Claus on 9/22/16.
//  Copyright © 2016 Tera Insights, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KeyGenerator : NSObject

+ (OSStatus) generatePairInSecureEnclaveWithHandle:(NSString*)handle;

@end
