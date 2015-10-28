/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2010-2015 Carnegie Mellon University
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "RegistrationHandler.h"
#import "ErrorLogger.h"
#import "Utility.h"
#import "SSEngine.h"

@implementation RegistrationHandler

- (void)registerToken: (NSString*)hex_keyid DeviceHex: (NSString*)hex_token ClientVer: (int)int_clientver PassphraseCache:(NSString*)passcache
{
    /* 
     * Build packet for registration
     * client_ver 4 bytes
     * lenkeyid 4 bytes
     * keyId
     * lensubtok 4 bytes (always 0 now)
     * lenregid 4 bytes
     * registrationId
     * devtype 4 bytes
     * lennonce 4 bytes
     * nonce
     * lenpubkey 4 bytes
     * pubkey
     * lensig 4 bytes
     * sig
     */
    
    NSMutableData *msgchunk = [[NSMutableData alloc] init];
    
    // client_ver
    int version = htonl(int_clientver);
    [msgchunk appendBytes: &version length: 4];
    
    // lenkeyid, keyid
    int lenkeyid = htonl([hex_keyid lengthOfBytesUsingEncoding: NSASCIIStringEncoding]);
    [msgchunk appendBytes: &lenkeyid length: 4];
    [msgchunk appendData:[hex_keyid dataUsingEncoding: NSASCIIStringEncoding]];
    
    // lensubtok, submissionToken, deprecated now, always 0
    int lensubtok = 0;
    [msgchunk appendBytes: &lensubtok length: 4];
    
    // lensubtok, registerionID
    int lenregid = htonl([hex_token lengthOfBytesUsingEncoding: NSASCIIStringEncoding]);
    [msgchunk appendBytes: &lenregid length: 4];
    [msgchunk appendData:[hex_token dataUsingEncoding: NSASCIIStringEncoding]];
    
    // devtype
    int dev_type = htonl(iOS);
    [msgchunk appendBytes: &dev_type length: 4];
    
    // append nonce
    NSData *nonce = [SSEngine GenRandomBytes:32];
    NSInteger lennonce = htonl([nonce length]);
    [msgchunk appendBytes: &lennonce length: 4];
    [msgchunk appendData: nonce];
    
    // append pubkey
    NSData *pubkey = [SSEngine getPubKey:SIGN_PUB];
    NSInteger lenpubkey = htonl([pubkey length]);
    [msgchunk appendBytes: &lenpubkey length: 4];
    [msgchunk appendData: pubkey];
    
    // sign and append signature
    NSData* SignKey = [SSEngine UnlockPrivateKey:passcache Size:[SSEngine getSelfPrivateKeySize:SIGN_PRI] Type:SIGN_PRI];
    if(!SignKey)
    {
        [ErrorLogger ERRORDEBUG: @"Unlock Private Key failed."];
        return;
    }
    NSData *sig = [SSEngine Sign:msgchunk withPrikey:SignKey];
    if(!sig)
    {
        // do error handling
        [ErrorLogger ERRORDEBUG: @"Signing failed."];
        return;
    }
    NSInteger sig_len = htonl([sig length]);
    [msgchunk appendBytes: &sig_len length: 4];
    [msgchunk appendData: sig];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, POSTREGISTRATION]];;
    
    // Default timeout
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MESSAGE_TIMEOUT];
    [request setURL: url];
    [request setHTTPMethod: @"POST"];
    [request setHTTPBody: msgchunk];
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    // set minimum version as TLS v1.0
    defaultConfigObject.TLSMinimumSupportedProtocol = kTLSProtocol1;
    NSURLSession *HttpsSession = [NSURLSession sessionWithConfiguration:defaultConfigObject delegate:nil delegateQueue:[NSOperationQueue mainQueue]];
    
    [[HttpsSession dataTaskWithRequest: request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        if(error)
        {
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]];
        }else{
            if([data length] > 0) {
                // start parsing data
                const char *msgchar = [data bytes];
                DEBUGMSG(@"Succeeded! Received %lu bytes of data",(unsigned long)[data length]);
                DEBUGMSG(@"Return SerV: %02X", ntohl(*(int *)msgchar));
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                if(ntohl(*(int *)msgchar) == 0) {
                    // Error Message
                    [ErrorLogger ERRORDEBUG:[NSString TranlsateErrorMessage:[NSString stringWithUTF8String: msgchar+4]]];
                }
            }
        }
    }] resume];
}


@end
