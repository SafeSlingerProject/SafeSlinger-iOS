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

#import <Foundation/Foundation.h>

#define NSNotificationMessageReceived @"MessageReceivedNotification"

typedef enum MessageStatus {
    Expired = -3,
    NetworkFail = -2,
    NonceError = -1,
    InitFetch = 0,
    AlreadyExist = 1,
    Downloaded = 2
} MessageStatus;


@protocol MessageReceiverNotificationDelegate

- (void)messageReceived;

@end


@class SafeSlingerDB;
@class UniversalDB;

@interface MessageReceiver : NSObject {
    int *MsgFinish;
    SafeSlingerDB *DbInstance;
    UniversalDB *UDbInstance;
}

@property (nonatomic, retain) SafeSlingerDB *DbInstance;
@property (nonatomic, retain) UniversalDB *UDbInstance;
@property (nonatomic, retain) NSLock *ThreadLock;

@property (nonatomic, strong) NSMutableDictionary *MsgNonces;
@property (nonatomic, readwrite) int NumNewMsg, VersionNum, MsgCount;

@property (nonatomic, weak) id notificationDelegate;

- (id)init:(SafeSlingerDB *)GivenDB UniveralTable:(UniversalDB *)UniDB Version:(int)Version;
- (void)FetchMessageNonces:(int)NumOfMostRecents;
- (BOOL)IsBusy;

@end
