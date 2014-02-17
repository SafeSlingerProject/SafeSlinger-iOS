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

#import "ContactViewController.h"
#import "ExchangeViewController.h"
#import "ActivityWindow.h"
#import "Passphase.h"
#import "MessageListViewController.h"
#import "SetupPanelViewController.h"
#import "SecureIntroduce.h"
#import "SystemSetting.h"
#import "MainPanel.h"
#import "MessageComposer.h"
#import "MessageEntryViewViewController.h"

#import "Base64.h"
#import "BackupCloud.h"
#import "KSDIdlingWindow.h"
#import "SafeSlingerDB.h"
#import "iToast.h"

@interface KeySlingerAppDelegate : NSObject <UIApplicationDelegate>
{
    KSDIdlingWindow *window;
    
	NSString *documentsPath, *vCardString;
    
    // UI Interfaces
    MainPanel *mainView;
    SetupPanelViewController *setupView;
	ContactViewController *contactView;
	ExchangeViewController *exchangeView;
	ActivityWindow *activityView;
    Passphase *passView;
    MessageListViewController *msgList;
    MessageEntryViewViewController *msgDetail;
    // SecureIntroduce *secureIntroducer;
    SystemSetting *systemView;
	UINavigationController *navController;
    
    NSString *myName, *tempralPINCode;
    int myID;
    NSData *SelfPhotoCache;
    
    // For access control
    BOOL hasAccess, hasContactPrivacy, firstSetup;
    
    // iCloud backup
    BackupCloudUtility *backtool;
    
    // background tasks
    UIBackgroundTaskIdentifier bgTask;
    NSTimer *icloud_timer;
    
    // database object
    SafeSlingerDB *DbInstance;
}

@property (nonatomic, retain) IBOutlet KSDIdlingWindow *window;
@property (nonatomic, retain) IBOutlet UINavigationController *navController;
@property (nonatomic, retain) MainPanel *mainView;
@property (nonatomic, retain) SetupPanelViewController *setupView;
@property (nonatomic, retain) ContactViewController *contactView;
@property (nonatomic, retain) ExchangeViewController *exchangeView;
@property (nonatomic, retain) ActivityWindow *activityView;
@property (nonatomic, retain) Passphase *passView;
@property (nonatomic, retain) MessageListViewController *msgList;
@property (nonatomic, retain) MessageEntryViewViewController *msgDetail;
@property (nonatomic, retain) SystemSetting *systemView;
@property (nonatomic, retain) BackupCloudUtility *backtool;
@property (nonatomic, retain) SafeSlingerDB *DbInstance;
@property (nonatomic, readwrite) BOOL hasAccess, hasContactPrivacy, firstSetup;
@property (weak) NSTimer *icloud_timer;
@property (nonatomic, retain) Reachability *internetReach;

@property (nonatomic, retain) NSString *documentsPath, *vCardString;
@property (nonatomic, readwrite) int myID;
@property (nonatomic, retain) NSString *tempralPINCode;
@property (nonatomic, retain) NSString *myName;
@property (nonatomic, retain) NSData *SelfPhotoCache;


-(NSString*) getVersionNumber;
-(int)  getVersionNumberByInt;
-(void) GainAccess;
-(void) saveConactData;
-(void) Login;
-(void) Logout;
-(void) ResetIdentity;
-(BOOL) CheckIdentity;
@end

