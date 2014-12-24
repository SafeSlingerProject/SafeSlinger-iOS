/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2010-2014 Carnegie Mellon University
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

#import "MessageReceiver.h"
#import "ErrorLogger.h"
#import "SafeSlingerDB.h"
#import "Utility.h"
#import "SSEngine.h"
#import "UniversalDB.h"
#import <AudioToolbox/AudioToolbox.h>
#import <UAPush.h>

@implementation MessageReceiver

@synthesize VersionNum, ThreadLock, DbInstance, UDbInstance, MsgCount, NumNewMsg;

- (id)init:(SafeSlingerDB *)GivenDB UniveralTable:(UniversalDB *)UniDB Version:(int)Version {
    if(self = [super init]) {
        ThreadLock = [[NSLock alloc]init];
        DbInstance = GivenDB;
        UDbInstance = UniDB;
        VersionNum = Version;
    }
    return self;
}

- (void)FetchSingleMessage:(NSString *)encodeNonce {
    if([ThreadLock tryLock]) {
        NumNewMsg = 0;
        MsgCount = 1;
        
        // Add single nonce
        _MsgNonces = [NSMutableDictionary dictionary];
        [_MsgNonces setObject:[NSNumber numberWithInt:0] forKey:encodeNonce];
        
		if(MsgFinish) {
			free(MsgFinish);
		}
        MsgFinish = malloc(sizeof(int) * 1);
        
        MsgFinish[0] = InitFetch;
        // Download messages
        [self DownloadMessages];
    }
}

- (void)FetchMessageNonces:(int)NumOfMostRecents {
    if([ThreadLock tryLock]) {
        
        NumNewMsg = 0;
        MsgCount = NumOfMostRecents;
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
        
        NSMutableData *pktdata = [[NSMutableData alloc] init];
        //E1: Version (4bytes)
        int version = htonl(VersionNum);
        [pktdata appendBytes: &version length: 4];
        NSString* token = [[UAPush shared]deviceToken];
        //E2: Token_len (4bytes)
        int len = htonl([token length]);
        [pktdata appendBytes: &len length: 4];
        //E3: Token
        [pktdata appendBytes:[token cStringUsingEncoding: NSUTF8StringEncoding] length: [token lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
        //E4: count of query
        len = htonl(NumOfMostRecents);
        [pktdata appendBytes: &len length: 4];
        
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, GETNONCESBYTOKEN]];
        // Default timeout
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MESSAGE_TIMEOUT];
        [request setURL: url];
        [request setHTTPMethod: @"POST"];
        [request setHTTPBody: pktdata];
        
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
             if(error) {
                 [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"ERROR: Internet Connection failed. Error - %@ %@",
                                           [error localizedDescription],
                                           [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]]];
                 
                 if(error.code==NSURLErrorTimedOut) {
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         [self PrintToastMessage: [NSString stringWithFormat:NSLocalizedString(@"error_ServerNotResponding", @"No response from server."), [error localizedDescription]]];
                         [ThreadLock unlock];
                     });
                 } else {
                     // general errors
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         [self PrintToastMessage: [NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]];
                         [ThreadLock unlock];
                     });
                 }
             } else {
                 
                 if([data length]==0) {
                     // should not happen, no related error message define now
                     [ThreadLock unlock];
                 } else {
                     // start parsing data
                     const char *msgchar = [data bytes];
                     if(ntohl(*(int *)msgchar) == 0) {
                         // Error Message
                         NSString* error_msg = [NSString TranlsateErrorMessage:[NSString stringWithUTF8String: msgchar+4]];
                         [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"error_msg = %@", error_msg]];
                         dispatch_async(dispatch_get_main_queue(), ^(void) {
                             [self PrintToastMessage: error_msg];
                             [ThreadLock unlock];
                         });
                     } else if(ntohl(*(int *)(msgchar+4))==1) {
                         // Received Nonce Count
                         int noncecnt = ntohl(*(int *)(msgchar+8));
                         
                         if(noncecnt>0) {
                             // length check
                             _MsgNonces = [NSMutableDictionary dictionary];
                             if(MsgFinish) free(MsgFinish);
                             MsgFinish = malloc(sizeof(int) * noncecnt);
                             
                             // shift
                             int noncelen = 0;
                             msgchar = msgchar+12;
                             MsgCount = noncecnt;
                             
                             for(int i=0;i<noncecnt;i++) {
                                 noncelen = ntohl(*(int *)msgchar);
                                 msgchar = msgchar+4;
                                 NSString* encodeNonce = [[NSString alloc]
                                                          initWithData:[NSData dataWithBytes:(const unichar *)msgchar length:noncelen]
                                                          encoding:NSUTF8StringEncoding];
                                 encodeNonce = [encodeNonce stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                                 msgchar = msgchar+noncelen;
                                 [_MsgNonces setObject:[NSNumber numberWithInt:i] forKey:encodeNonce];
                                 MsgFinish[i] = InitFetch;
                             }
                             
                             // Download messages in a for loop
                             [self DownloadMessages];
                         } else {
                             // noncecnt ==0
                             [ErrorLogger ERRORDEBUG: @"No available messages."];
                             dispatch_async(dispatch_get_main_queue(), ^(void) {
                                 //[delegate.activityView DisableProgress];
                                 [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                                 [ThreadLock unlock];
                                 [[UAPush shared] setBadgeNumber:0];
                             });
                         }
                     } else {
                         
                         // should not happen, in case while network has problem..
                         dispatch_async(dispatch_get_main_queue(), ^(void) {
                             //[delegate.activityView DisableProgress];
                             [ErrorLogger ERRORDEBUG: @"Network is unavailable."];
                             [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                             [ThreadLock unlock];
                         });
                     }
                 }
             }
         }];
    }
    
}

- (void)DownloadMessages {
    for(NSString* nonce in [_MsgNonces allKeys]) {
        NSData* decodenonce = [Base64 decode:[nonce cStringUsingEncoding:NSUTF8StringEncoding] length:[nonce lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
        if([decodenonce length]==NONCELEN) {
            if(![UDbInstance CheckMessage:decodenonce]) {
                // Get message
                [UDbInstance CreateNewEntry:decodenonce];
                [self RetrieveCipher: decodenonce EncodeNonce:nonce];
            } else {
                [ErrorLogger ERRORDEBUG: @"Message exist."];
                MsgFinish[[[_MsgNonces objectForKey:nonce]integerValue]] = AlreadyExist;   // already download
            }
        } else {
            [ErrorLogger ERRORDEBUG: @"Message nonce format is incorrect."];
            MsgFinish[[[_MsgNonces objectForKey:nonce]integerValue]] = NonceError;  // error case
        }
    }
    
    [self CheckQueriedMessages];
}

- (void)RetrieveCipher:(NSData *)nonce EncodeNonce:(NSString *)cnonce {
    NSMutableData *pktdata = [[NSMutableData alloc] init];
    //E1: Version (4bytes)
    int version = htonl(VersionNum);
    [pktdata appendBytes: &version length: 4];
    //E2: ID_length (4bytes)
    int len = htonl([nonce length]);
    [pktdata appendBytes: &len length: 4];
    //E3: ID (random nonce)
    [pktdata appendData:nonce];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, GETMSG]];
    // Default timeout
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MESSAGE_TIMEOUT];
    [request setURL: url];
	[request setHTTPMethod: @"POST"];
	[request setHTTPBody: pktdata];
    
    NSInteger index = [[_MsgNonces objectForKey:cnonce]integerValue];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
         if(error) {
             MsgFinish[index] = NetworkFail; // service is unavaible
             [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"ERROR: Internet Connection failed. Error - %@ %@",
                                       [error localizedDescription],
                                       [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]]];
             
             if(error.code==NSURLErrorTimedOut) {
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [self PrintToastMessage: NSLocalizedString(@"error_ServerNotResponding", @"No response from server.")];
                 });
             } else {
                 // general errors
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [self PrintToastMessage: [NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]];
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
                     DEBUGMSG(@"Send Message Code: %d", ntohl(*(int *)(msgchar+4)));
                     DEBUGMSG(@"Send Message Response: %s", msgchar+8);
                     // Received Encrypted Message
                     int msglen = ntohl(*(int *)(msgchar+8));
                     if(msglen<=0) {
                         MsgFinish[index] = NetworkFail;
                         // display error
                         dispatch_async(dispatch_get_main_queue(), ^(void) {
                             [self PrintToastMessage: NSLocalizedString(@"error_InvalidIncomingMessage", @"Bad incoming message format.")];
                         });
                     } else {
                         MsgFinish[index] = Downloaded;
                         NSData* cipher = [NSData dataWithBytes:(msgchar+12) length:msglen];
                         NSArray* EncryptPkt = [NSArray arrayWithObjects: nonce, cipher, nil];
                         dispatch_async(dispatch_get_main_queue(), ^(void) {
                             [self SaveSecureMessage:EncryptPkt];
                         });
                     }
                 } else if(ntohl(*(int *)msgchar) == 0) {
                     // Error Message
                     NSString* error_msg = [NSString TranlsateErrorMessage:[NSString stringWithUTF8String: msgchar+4]];
                     DEBUGMSG(@"ERROR: error_msg = %@", error_msg);
                     if([[NSString stringWithUTF8String: msgchar+4] hasSuffix:@"MessageNotFound"]) {
                         // expired one
                         MsgFinish[index] = Expired;
                     } else {
                         MsgFinish[index] = NetworkFail;
                     }
					 
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         [self PrintToastMessage: error_msg];
                     });
                 }
             }
             
             dispatch_async(dispatch_get_main_queue(), ^(void) {
                 [self CheckQueriedMessages];
             });
         }
     }];
}

- (void)CheckQueriedMessages {
    DEBUGMSG(@"CheckQueriedMessages...");
    
    // chekc all messages are processed
    BOOL all_processed = YES;
	for(int i=0;i<MsgCount;i++) {
		if(MsgFinish[i]==InitFetch) {
			all_processed = NO;
		}
	}
	
    if(all_processed) {
        //[delegate.activityView DisableProgress];
        [ThreadLock unlock];
        
        DEBUGMSG(@"IconBadgeNumber = %ld", (long)[[UIApplication sharedApplication]applicationIconBadgeNumber]);
        
        int _NumExpiredMsg = 0, _NumBadMsg = 0, _NumSafeMsg = 0;
        
        for(int i = 0; i < MsgCount; i++) {
            switch (MsgFinish[i]) {
                case Expired:
                    _NumExpiredMsg++;
                    break;
                case NonceError:
                case NetworkFail:
                    _NumBadMsg++;
                    break;
                case Downloaded:
                    _NumSafeMsg++;
                    break;
                default:
                    break;
            }
        }
        
        DEBUGMSG(@"Fetch results: %d %d %d", _NumExpiredMsg, _NumBadMsg, _NumSafeMsg);
        
        if(_NumExpiredMsg==MsgCount) {
            // all messages expired
            [self PrintToastMessage: NSLocalizedString(@"error_PushMsgMessageNotFound", @"Message expired.")];
        } else if(_NumExpiredMsg==MsgCount) {
            [self PrintToastMessage: NSLocalizedString(@"error_InvalidIncomingMessage", @"Bad incoming message format.")];
        } else if(_NumSafeMsg>0) {
			if(_notificationDelegate) {
				[_notificationDelegate messageReceived];
			} else {
				AudioServicesPlaySystemSound(1003);
			}
			
			[[NSNotificationCenter defaultCenter] postNotificationName:NSNotificationMessageReceived object:nil userInfo:nil];
        }
        
        [[UAPush shared] setBadgeNumber:0];
        
        NumNewMsg = MsgCount = 0;
    }
}

- (void)SaveSecureMessage:(NSArray *)EncryptPkt {
    NSData* nonce = [EncryptPkt objectAtIndex:0];
    NSData* cipher = [EncryptPkt objectAtIndex:1];
    
    if(![[sha3 Keccak256Digest:cipher] isEqualToData:nonce]) {
        [ErrorLogger ERRORDEBUG:@"ERROR: Received Message Digest Error."];
        // display error
        [self PrintToastMessage: NSLocalizedString(@"error_InvalidIncomingMessage", @"Bad incoming message format.")];
    } else {
        if(![UDbInstance UpdateEntryWithCipher:nonce Cipher:cipher]) {
            [self PrintToastMessage: NSLocalizedString(@"error_UnableToSaveMessageInDB", @"Unable to save to the message database.")];
        }
    }
}

- (void)PrintToastMessage:(NSString *)error {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [[[[iToast makeText: error]
       setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
}

@end
