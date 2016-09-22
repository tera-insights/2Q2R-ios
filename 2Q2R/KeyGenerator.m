//
//  KeyGenerator.m
//  2Q2R
//
//  Created by Sam Claus on 9/22/16.
//  Copyright © 2016 Tera Insights, LLC. All rights reserved.
//
//

#import "KeyGenerator.h"

#define newCFDict CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks)

@implementation KeyGenerator

+ (OSStatus)generatePairInSecureEnclaveWithHandle:(NSString*)handle
{
  CFErrorRef error = NULL;
  // Should be the secret invalidated when passcode is removed? If not then use `kSecAttrAccessibleWhenUnlocked`.
  SecAccessControlRef sacObject = SecAccessControlCreateWithFlags(
    kCFAllocatorDefault,
    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
    kSecAccessControlTouchIDAny | kSecAccessControlPrivateKeyUsage,
    &error
  );
  
  if (error != errSecSuccess) {
    NSLog(@"Key generation error: %@", error);
  }
  
  // private key parameters
  CFMutableDictionaryRef privateKeyParameters = newCFDict;
  CFDictionaryAddValue(privateKeyParameters, kSecAttrAccessControl, sacObject);
  CFDictionaryAddValue(privateKeyParameters, kSecAttrIsPermanent, kCFBooleanTrue);
  CFDictionaryAddValue(privateKeyParameters, kSecAttrApplicationTag, (__bridge const void *)(handle));
  CFDictionaryAddValue(privateKeyParameters, kSecAttrLabel, "private");
    
  // public key parameters
  CFMutableDictionaryRef publicKeyParameters = newCFDict;
  CFDictionaryAddValue(publicKeyParameters, kSecAttrIsPermanent, kCFBooleanTrue);
  CFDictionaryAddValue(publicKeyParameters, kSecAttrApplicationTag, (__bridge const void *)(handle));
  CFDictionaryAddValue(publicKeyParameters, kSecAttrLabel, "public");
  
  // create dict which actually saves key into keychain
  CFMutableDictionaryRef keyPairParameters = newCFDict;
  CFDictionaryAddValue(keyPairParameters, kSecAttrTokenID, kSecAttrTokenIDSecureEnclave);
  CFDictionaryAddValue(keyPairParameters, kSecAttrKeyType, kSecAttrKeyTypeEC);
  CFDictionaryAddValue(keyPairParameters, kSecAttrKeySizeInBits, (__bridge const void *)([NSNumber numberWithInt:256]));
  CFDictionaryAddValue(keyPairParameters, kSecPrivateKeyAttrs, privateKeyParameters);
  CFDictionaryAddValue(keyPairParameters, kSecPublicKeyAttrs, publicKeyParameters);
  
  SecKeyRef privateKeyRef, publicKeyRef;
  
  return SecKeyGeneratePair(keyPairParameters, &publicKeyRef, &privateKeyRef);
  
}

@end
