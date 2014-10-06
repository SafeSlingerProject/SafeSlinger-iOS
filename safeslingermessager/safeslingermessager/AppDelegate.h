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

#import <UIKit/UIKit.h>
#import <UAPush.h>

@class SafeSlingerDB;
@class BackupCloudUtility;
@class ContactEntry;
@class MessageReceiver;
@class UniversalDB;

@interface AppDelegate : UIResponder <UIApplicationDelegate, UARegistrationDelegate>
{
    // Management Path
    NSString *RootPath;
    
    // database object
    SafeSlingerDB *DbInstance;
    UniversalDB *UDbInstance;
    
    // Message Reciver Object
    MessageReceiver *MessageInBox;
    
    NSString *tempralPINCode;
    
    // Identifity Information
    int IdentityNum;
    NSString *IdentityName;
    NSData *IdentityImage;
    
    // Backup
    BackupCloudUtility *BackupSys;
    
    // Temp use
    ContactEntry *SelectContact;
}

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, retain) SafeSlingerDB *DbInstance;
@property (nonatomic, retain) UniversalDB *UDbInstance;
@property (nonatomic, retain) MessageReceiver *MessageInBox;
@property (nonatomic, retain) ContactEntry *SelectContact;
@property (nonatomic, retain) BackupCloudUtility *BackupSys;
@property (nonatomic, retain) NSString *tempralPINCode, *IdentityName, *RootPath;
@property (nonatomic, readwrite) int IdentityNum;
@property (nonatomic, retain) NSData *IdentityImage;
@property (nonatomic, readwrite) UIBackgroundTaskIdentifier bgTask;

-(NSString*) getVersionNumber;
-(int) getVersionNumberByInt;
-(void) registerPushToken;
-(void) saveConactDataWithoutChaningName: (int)ContactID;
-(void) removeContactLink;
-(BOOL) checkIdentity;
-(void) saveConactData: (int)ContactID Firstname:(NSString*)FN Lastname:(NSString*)LN;

@end
