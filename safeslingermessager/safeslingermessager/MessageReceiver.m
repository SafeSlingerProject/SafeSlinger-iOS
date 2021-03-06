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

#import "MessageReceiver.h"
#import "ErrorLogger.h"
#import "SafeSlingerDB.h"
#import "Utility.h"
#import "SSEngine.h"
#import "UniversalDB.h"
#import "RegistrationHandler.h"
#import "MessageDecryptor.h"

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

- (BOOL)IsBusy {
    if([ThreadLock tryLock]) {
        [ThreadLock unlock];
        return NO;
    } else {
        return YES;
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
        NSString* hex_token = [[NSUserDefaults standardUserDefaults] stringForKey: kPUSH_TOKEN];
        //E2: Token_len (4bytes)
        int len = htonl([hex_token length]);
        [pktdata appendBytes: &len length: 4];
        //E3: Token
        [pktdata appendBytes:[hex_token cStringUsingEncoding: NSUTF8StringEncoding] length: [hex_token lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
        //E4: count of query
        len = htonl(NumOfMostRecents);
        [pktdata appendBytes: &len length: 4];
        
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, GETNONCESBYTOKEN]];
        // Default timeout
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MESSAGE_TIMEOUT];
        [request setURL: url];
        [request setHTTPMethod: @"POST"];
        [request setHTTPBody: pktdata];
        
        NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
        defaultConfigObject.TLSMinimumSupportedProtocol = kTLSProtocol12;
        NSURLSession *HttpsSession = [NSURLSession sessionWithConfiguration:defaultConfigObject delegate:nil delegateQueue:[NSOperationQueue mainQueue]];
        
        [[HttpsSession dataTaskWithRequest: request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
            if(error) {
                [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"Internet Connection failed. Error - %@ %@",
                                          [error localizedDescription],
                                          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]]];
                
                if(error.code==NSURLErrorTimedOut) {
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        [self PrintToastMessage: [NSString stringWithFormat:NSLocalizedString(@"error_ServerNotResponding", @"No response from server."), [error localizedDescription]]];
                        [ThreadLock unlock];
                    });
                } else {
                    // general errors
                    [self PrintToastMessage: [NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessage", @"Server Message: '%@'"), [error localizedDescription]]];
                    [ThreadLock unlock];
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
                            
                            for(int i = 0; i < noncecnt; i++) {
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
                            // noncecnt == 0
                            [ErrorLogger ERRORDEBUG: @"No available messages."];
                            dispatch_async(dispatch_get_main_queue(), ^(void) {
                                //[delegate.activityView DisableProgress];
                                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                                [ThreadLock unlock];
                                [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
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
        }] resume];
    }
}

- (void)DownloadMessages {
    for(NSString* nonce in [_MsgNonces allKeys]) {
        NSData* decodenonce = [[NSData alloc]initWithBase64EncodedString:nonce options:0];
        //[Base64 decode:[nonce cStringUsingEncoding:NSUTF8StringEncoding] length:[nonce lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
        if([decodenonce length]==NONCELEN) {
            if(![UDbInstance CheckMessage:decodenonce]) {
                // Get message
                DEBUGMSG(@"nonce = %@", nonce);
				
				MsgEntry *msg = [MsgEntry new];
				msg.msgid = decodenonce;
				msg.cTime = [NSString GetGMTString:DATABASE_TIMESTR];
				msg.dir = FromMsg;
				
                [UDbInstance createNewEntry:msg];
                [self RetrieveCipherForMessage:msg withNonceString:nonce];
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

- (void)RetrieveCipherForMessage:(MsgEntry *)msg withNonceString:(NSString *)nonceString {
	NSData *nonce = msg.msgid;
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
    
    NSInteger index = [[_MsgNonces objectForKey:nonceString] integerValue];
    
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    defaultConfigObject.TLSMinimumSupportedProtocol = kTLSProtocol12;
    NSURLSession *HttpsSession = [NSURLSession sessionWithConfiguration:defaultConfigObject delegate:nil delegateQueue:[NSOperationQueue mainQueue]];
    
    [[HttpsSession dataTaskWithRequest: request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        if(error) {
            MsgFinish[index] = NetworkFail; // service is unavaible
            [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"Internet Connection failed. Error - %@ %@",
                                      [error localizedDescription],
                                      [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]]];
            
            if(error.code==NSURLErrorTimedOut) {
                [self PrintToastMessage: NSLocalizedString(@"error_ServerNotResponding", @"No response from server.")];
            } else {
                // general errors
                [self PrintToastMessage: [NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessage", @"Server Message: '%@'"), [error localizedDescription]]];
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
                        [self PrintToastMessage: NSLocalizedString(@"error_InvalidIncomingMessage", @"Bad incoming message format.")];
                    } else {
                        MsgFinish[index] = Downloaded;
                        NSData* cipher = [NSData dataWithBytes:(msgchar+12) length:msglen];
                        msg.keyid = [SSEngine ExtractKeyID:cipher];
                        msg.msgbody = [NSData dataWithBytes:[cipher bytes] + LENGTH_KEYID length:[cipher length] - LENGTH_KEYID];
                        [self handleNewCipherMessage:msg withCipher:(NSData *)cipher];
                    }
                } else if(ntohl(*(int *)msgchar) == 0) {
                    // Error Message
                    NSString* error_msg = [NSString TranlsateErrorMessage:[NSString stringWithUTF8String: msgchar+4]];
                    [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"error_msg = %@", error_msg]];
                    if([[NSString stringWithUTF8String: msgchar+4] hasSuffix:@"MessageNotFound"]) {
                        // expired one
                        MsgFinish[index] = Expired;
                    } else {
                        MsgFinish[index] = NetworkFail;
                    }
                    [self PrintToastMessage: error_msg];
                }
            }
            [self CheckQueriedMessages];
        }
    }] resume];
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
        [ThreadLock unlock];
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
        
        if(_NumSafeMsg>0 || MsgCount == 0) {
			NSLog(@"NumSafeMsg = %d, MsgCount = %d", _NumSafeMsg, MsgCount);
			
			if(_notificationDelegate) {
				[_notificationDelegate messageReceived];
			} else {
                // move toast message back..
                NSString *msg = nil;
				
				if(_NumSafeMsg < 2) {
                    msg = NSLocalizedString(@"title_NotifyFileAvailable", @"SafeSlinger Message Available");
				} else {
                    msg = [NSString stringWithFormat: NSLocalizedString(@"title_NotifyMulFileAvailable", @"%d SafeSlinger Messages Available"),_NumSafeMsg];
				}
				
                [[[[iToast makeText: msg]
                  setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
				[UtilityFunc playSoundAlert];
			}
			
			[[NSNotificationCenter defaultCenter] postNotificationName:NSNotificationMessageReceived object:nil userInfo:nil];
		} else if(_NumExpiredMsg==MsgCount) {
			// all messages expired
			[self PrintToastMessage: NSLocalizedString(@"error_PushMsgMessageNotFound", @"Message expired.")];
		} else if(_NumExpiredMsg==MsgCount) {
			[self PrintToastMessage: NSLocalizedString(@"error_InvalidIncomingMessage", @"Bad incoming message format.")];
		}
		
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        long badge_num = [[UIApplication sharedApplication]applicationIconBadgeNumber];
        badge_num = badge_num - _NumSafeMsg - _NumExpiredMsg;
        DEBUGMSG(@"new badge_num = %ld", badge_num);
        if (badge_num<0) badge_num = 0;
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:badge_num];
        NumNewMsg = MsgCount = 0;
    }
}

- (void)handleNewCipherMessage:(MsgEntry *)msg withCipher:(NSData *)cipher {
	if([[NSUserDefaults standardUserDefaults] integerForKey:kAutoDecryptOpt] == TurnOn
	   && [MessageDecryptor decryptCipherMessage:msg]) {
		 //auto-decrypt enabled and message was decrypted
		return;
	} else {
		//auto-decrypt disabled or unable to decrypt message
		//save to DB encrypted
		if(![[sha3 Keccak256Digest:cipher] isEqualToData:msg.msgid]) {
			[ErrorLogger ERRORDEBUG:@"Received Message Digest Error."];
			// display error
			[self PrintToastMessage: NSLocalizedString(@"error_InvalidIncomingMessage", @"Bad incoming message format.")];
		} else {
			if(![UDbInstance updateMessageEntry:msg]) {
				[self PrintToastMessage: NSLocalizedString(@"error_UnableToSaveMessageInDB", @"Unable to save to the message database.")];
			}
		}
	}
}

- (void)PrintToastMessage:(NSString *)error {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [[[[iToast makeText: error]
       setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
}

@end
