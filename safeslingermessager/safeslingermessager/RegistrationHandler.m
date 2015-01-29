//
//  RegistrationHandler.m
//  safeslingermessager
//
//  Created by Yueh-Hsun Lin on 1/25/15.
//  Copyright (c) 2015 CyLab. All rights reserved.
//

#import "RegistrationHandler.h"
#import "ErrorLogger.h"
#import "Utility.h"

@implementation RegistrationHandler

- (void)registerToken: (NSString*)hex_submissiontoken DeviceHex: (NSString*)hex_token KeyHex: (NSString*)hex_keyid ClientVer: (int)int_clientver
{
    /* 
     * Build packet for registration
     * client_ver [0:4]
     * lenkeyid [4:4+4]
     * keyId [4+4: 4+4+lenkeyid]
     * lensubtok [4+4+lenkeyid: 4+4+lenkeyid+4]
     * submissionToken [4+4+lenkeyid+4: 4+4+lenkeyid+4+lensubtok]
     * lenregid [4+4+lenkeyid+4+lensubtok: 4+4+lenkeyid+4+lensubtok+4]
     * registrationId [4+4+lenkeyid+4+lensubtok+4: 4+4+lenkeyid+4+lensubtok+4+lenregid]
     * devtype = [4+4+lenkeyid+4+lensubtok+4+lenregid: 4+4+lenkeyid+4+lensubtok+4+lenregid+4]
     */
    
    NSMutableData *msgchunk = [[NSMutableData alloc] init];
    
    // client_ver
    int version = htonl(int_clientver);
    [msgchunk appendBytes: &version length: 4];
    
    // lenkeyid, keyid
    int lenkeyid = htonl([hex_keyid lengthOfBytesUsingEncoding: NSASCIIStringEncoding]);
    [msgchunk appendBytes: &lenkeyid length: 4];
    [msgchunk appendData:[hex_keyid dataUsingEncoding: NSASCIIStringEncoding]];
    
    // lensubtok, submissionToken
    int lensubtok = htonl([hex_submissiontoken lengthOfBytesUsingEncoding: NSASCIIStringEncoding]);
    [msgchunk appendBytes: &lensubtok length: 4];
    [msgchunk appendData:[hex_submissiontoken dataUsingEncoding: NSASCIIStringEncoding]];
    
    // lensubtok, submissionToken
    int lenregid = htonl([hex_token lengthOfBytesUsingEncoding: NSASCIIStringEncoding]);
    [msgchunk appendBytes: &lenregid length: 4];
    [msgchunk appendData:[hex_token dataUsingEncoding: NSASCIIStringEncoding]];
    
    // devtype
    int dev_type = htonl(iOS);
    [msgchunk appendBytes: &dev_type length: 4];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, POSTREGISTRATION]];;
    
    // Default timeout
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MESSAGE_TIMEOUT];
    [request setURL: url];
    [request setHTTPMethod: @"POST"];
    [request setHTTPBody: msgchunk];
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    // run in background
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if(error) {
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
            [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"ERROR: Internet Connection failed. Error - %@ %@",
                                      [error localizedDescription],
                                      [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]]];
            
            if(error.code==NSURLErrorTimedOut) {
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [ErrorLogger ERRORDEBUG: NSLocalizedString(@"error_ServerNotResponding", @"No response from server.")];
                });
            } else {
                // general errors
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]];
                });
            }
        } else {
            if([data length] > 0) {
                // start parsing data
                const char *msgchar = [data bytes];
                DEBUGMSG(@"Succeeded! Received %lu bytes of data",(unsigned long)[data length]);
                DEBUGMSG(@"Return SerV: %02X", ntohl(*(int *)msgchar));
                if(ntohl(*(int *)msgchar) > 0) {
                    // Send Response
                    DEBUGMSG(@"Registration Code: %d", ntohl(*(int *)(msgchar+4)));
                    DEBUGMSG(@"Registration Response: %s", msgchar+8);
                    // Registraiton Succeed.
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                    });
                } else if(ntohl(*(int *)msgchar) == 0) {
                    // Error Message
                    NSString* error_msg = [NSString TranlsateErrorMessage:[NSString stringWithUTF8String: msgchar+4]];
                    [ErrorLogger ERRORDEBUG:error_msg];
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                        [ErrorLogger ERRORDEBUG:error_msg];
                    });
                }
            }
        }
    }];
}


@end
