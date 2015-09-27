//
//  NSObject+sha3.m
//  safeslingerexchange
//
//  Created by Yue-Hsun Lin on 9/27/15.
//  Copyright © 2015 CyLab. All rights reserved.
//

#import "sha3.h"
#import "Keccak-readable-and-compact.h"
#define SHA3_HSAH_SIZE 32

@implementation NSObject (sha3)

+(NSData*)Keccak256Digest: (NSData*)input
{
    unsigned char digest[SHA3_HSAH_SIZE];
    if([input length]>0)
    {
        FIPS202_SHA3_256([input bytes], (unsigned int)[input length], digest);
        return [NSData dataWithBytes:digest length:SHA3_HSAH_SIZE];
    }else
        return nil;
}

+(NSData*)Keccak256HMAC: (NSData*)input withKey:(NSData*)key
{
    unsigned char digest[SHA3_HSAH_SIZE];
    NSMutableData *data = [NSMutableData dataWithBytes:[key bytes] length:[key length]];
    [data appendData:[input bytes]];
    if([data length]>0)
    {
        FIPS202_SHA3_256([data bytes], (unsigned int)[data length], digest);
        return [NSData dataWithBytes:digest length:SHA3_HSAH_SIZE];
    }else
        return nil;
}

@end
